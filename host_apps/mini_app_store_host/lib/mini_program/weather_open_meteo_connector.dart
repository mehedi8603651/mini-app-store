import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_sdk/mini_program_sdk.dart';

const String _weatherAppId = 'weather';
const Duration _requestTimeout = Duration(seconds: 12);

/// Demo adapter for the public, keyless Open-Meteo APIs used by Weather.
///
/// Production publishers can expose the same `forecast` and `geocoding`
/// response shapes from their own middle-server without changing the artifact.
class WeatherOpenMeteoConnector
    implements DisposableMiniProgramBackendConnector {
  WeatherOpenMeteoConnector({
    required MiniProgramBackendConnector fallback,
    http.Client? client,
  }) : _fallback = fallback,
       _client = client ?? http.Client();

  final MiniProgramBackendConnector _fallback;
  final http.Client _client;
  final Map<String, _CachedWeatherResponse> _cache =
      <String, _CachedWeatherResponse>{};
  bool _disposed = false;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    if (request.miniProgramId != _weatherAppId) {
      return _fallback.call(request);
    }
    if (_disposed) {
      return _failure(
        request,
        code: 'open_meteo_connector_disposed',
        message: 'The Weather API connector has been disposed.',
      );
    }

    final endpoint = request.endpoint.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (endpoint != 'forecast' && endpoint != 'geocoding') {
      return _failure(
        request,
        code: 'weather_endpoint_not_allowed',
        message: 'Weather supports only forecast and geocoding endpoints.',
      );
    }

    final cacheKey = '$endpoint:${_canonicalJson(request.body)}';
    final cached = _cache[cacheKey];
    if (!request.forceRefresh &&
        request.cachePolicy.isEnabled &&
        cached != null &&
        !cached.isExpired) {
      return _success(request, cached.data, fromCache: true);
    }

    try {
      final data = endpoint == 'forecast'
          ? await _loadForecast(request.body)
          : await _searchLocations(request.body);
      final ttl = request.cachePolicy.ttl;
      if (ttl != null && ttl > Duration.zero) {
        _cache[cacheKey] = _CachedWeatherResponse(
          data: data,
          expiresAt: DateTime.now().add(ttl),
        );
      }
      _cache.removeWhere((_, value) => value.isExpired);
      return _success(request, data);
    } on _WeatherRequestException catch (error) {
      return _failure(
        request,
        code: error.code,
        message: error.message,
        statusCode: error.statusCode,
      );
    } on TimeoutException {
      return _failure(
        request,
        code: 'open_meteo_timeout',
        message: 'Open-Meteo did not respond in time.',
      );
    } on FormatException {
      return _failure(
        request,
        code: 'open_meteo_invalid_response',
        message: 'Open-Meteo returned an invalid response.',
      );
    } catch (error) {
      return _failure(
        request,
        code: 'open_meteo_unreachable',
        message: 'Open-Meteo could not be reached.',
        data: <String, dynamic>{'transportError': error.toString()},
      );
    }
  }

  Future<Map<String, dynamic>> _loadForecast(Map<String, dynamic> body) async {
    final latitude = _boundedNumber(
      body['latitude'],
      name: 'latitude',
      min: -90,
      max: 90,
    );
    final longitude = _boundedNumber(
      body['longitude'],
      name: 'longitude',
      min: -180,
      max: 180,
    );
    final locationName = _boundedText(
      body['locationName'],
      name: 'locationName',
      maxLength: 160,
      fallback: 'Selected location',
    );

    final uri =
        Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,'
              'is_day,precipitation,weather_code,wind_speed_10m',
          'hourly':
              'temperature_2m,precipitation_probability,weather_code,'
              'relative_humidity_2m,wind_speed_10m',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,'
              'precipitation_probability_max,sunrise,sunset,wind_speed_10m_max',
          'timezone': 'auto',
          'forecast_days': '7',
        });
    final decoded = await _getJson(uri);
    final current = _map(decoded['current']);
    final hourly = _map(decoded['hourly']);
    final daily = _map(decoded['daily']);
    if (current.isEmpty || hourly.isEmpty || daily.isEmpty) {
      throw const _WeatherRequestException(
        code: 'open_meteo_invalid_response',
        message: 'The forecast response is missing required weather data.',
      );
    }

    final currentTime = _text(current['time']);
    final currentCode = _integer(current['weather_code']);
    final currentFlags = _weatherFlags(currentCode);
    return <String, dynamic>{
      'locationName': locationName,
      'latitude': _number(decoded['latitude'], fallback: latitude),
      'longitude': _number(decoded['longitude'], fallback: longitude),
      'timezone': _text(decoded['timezone'], fallback: 'auto'),
      'current': <String, dynamic>{
        'time': currentTime,
        'dateLabel': _dateTimeLabel(currentTime),
        'temperature': _number(current['temperature_2m']),
        'temperatureRounded': _number(current['temperature_2m']).round(),
        'apparentTemperature': _number(current['apparent_temperature']),
        'apparentTemperatureRounded': _number(
          current['apparent_temperature'],
        ).round(),
        'humidity': _number(current['relative_humidity_2m']).round(),
        'precipitation': _oneDecimal(_number(current['precipitation'])),
        'windSpeed': _oneDecimal(_number(current['wind_speed_10m'])),
        'weatherCode': currentCode,
        'condition': _weatherLabel(currentCode),
        'isDay': _integer(current['is_day']) == 1,
        ...currentFlags,
      },
      'hourly': _normalizeHourly(hourly, currentTime),
      'daily': _normalizeDaily(daily),
      'attribution': 'Weather data by Open-Meteo',
    };
  }

  Future<Map<String, dynamic>> _searchLocations(
    Map<String, dynamic> body,
  ) async {
    final query = _text(body['query']);
    if (query.length < 2) {
      return <String, dynamic>{
        'query': query,
        'results': <Object?>[],
        'matchCount': 0,
      };
    }
    if (query.length > 256) {
      throw const _WeatherRequestException(
        code: 'open_meteo_invalid_request',
        message: 'query must contain 2 to 256 characters.',
      );
    }
    final requestedCount = _integer(body['count'], fallback: 10);
    if (requestedCount < 1 || requestedCount > 20) {
      throw const _WeatherRequestException(
        code: 'open_meteo_invalid_request',
        message: 'Geocoding count must be between 1 and 20.',
      );
    }
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      <String, String>{
        'name': query,
        'count': requestedCount.toString(),
        'language': 'en',
        'format': 'json',
      },
    );
    final decoded = await _getJson(uri);
    final rawResults = decoded['results'];
    final results = <Map<String, dynamic>>[];
    if (rawResults is List) {
      for (final raw in rawResults.take(requestedCount)) {
        final item = _map(raw);
        final latitude = _nullableNumber(item['latitude']);
        final longitude = _nullableNumber(item['longitude']);
        final name = _text(item['name']);
        if (name.isEmpty || latitude == null || longitude == null) {
          continue;
        }
        final country = _text(item['country']);
        final subtitleParts = <String>[
          _text(item['admin1']),
          _text(item['admin2']),
          country,
        ].where((value) => value.isNotEmpty && value != name).toSet().toList();
        results.add(<String, dynamic>{
          'name': name,
          'subtitle': subtitleParts.join(', '),
          'country': country,
          'latitude': latitude,
          'longitude': longitude,
          'timezone': _text(item['timezone']),
          'source': 'Open-Meteo / GeoNames',
        });
      }
    }
    return <String, dynamic>{
      'query': query,
      'results': results,
      'matchCount': results.length,
    };
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: const <String, String>{'accept': 'application/json'})
        .timeout(_requestTimeout);
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const _WeatherRequestException(
        code: 'open_meteo_invalid_response',
        message: 'Open-Meteo returned malformed JSON.',
      );
    }
    final data = _map(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _WeatherRequestException(
        code: 'open_meteo_http_error',
        message: _text(
          data['reason'],
          fallback: 'Open-Meteo returned HTTP ${response.statusCode}.',
        ),
        statusCode: response.statusCode,
      );
    }
    if (data['error'] == true) {
      throw _WeatherRequestException(
        code: 'open_meteo_api_error',
        message: _text(
          data['reason'],
          fallback: 'Open-Meteo rejected the request.',
        ),
      );
    }
    return data;
  }

  List<Map<String, dynamic>> _normalizeHourly(
    Map<String, dynamic> hourly,
    String currentTime,
  ) {
    final times = _list(hourly['time']);
    var start = 0;
    if (currentTime.isNotEmpty) {
      final index = times.indexWhere(
        (value) => _text(value).compareTo(currentTime) >= 0,
      );
      if (index >= 0) {
        start = index;
      }
    }
    final end = (start + 24).clamp(0, times.length);
    final result = <Map<String, dynamic>>[];
    for (var index = start; index < end; index++) {
      final code = _integerAt(hourly, 'weather_code', index);
      result.add(<String, dynamic>{
        'time': _text(times[index]),
        'timeLabel': _timeLabel(_text(times[index])),
        'temperature': _numberAt(hourly, 'temperature_2m', index),
        'temperatureRounded': _numberAt(
          hourly,
          'temperature_2m',
          index,
        ).round(),
        'precipitationProbability': _numberAt(
          hourly,
          'precipitation_probability',
          index,
        ).round(),
        'humidity': _numberAt(hourly, 'relative_humidity_2m', index).round(),
        'windSpeed': _oneDecimal(_numberAt(hourly, 'wind_speed_10m', index)),
        'weatherCode': code,
        'condition': _weatherLabel(code),
        ..._weatherFlags(code),
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _normalizeDaily(Map<String, dynamic> daily) {
    final dates = _list(daily['time']);
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < dates.length && index < 7; index++) {
      final date = _text(dates[index]);
      final code = _integerAt(daily, 'weather_code', index);
      result.add(<String, dynamic>{
        'date': date,
        'dayLabel': _dayLabel(date),
        'temperatureMax': _numberAt(daily, 'temperature_2m_max', index),
        'temperatureMaxRounded': _numberAt(
          daily,
          'temperature_2m_max',
          index,
        ).round(),
        'temperatureMin': _numberAt(daily, 'temperature_2m_min', index),
        'temperatureMinRounded': _numberAt(
          daily,
          'temperature_2m_min',
          index,
        ).round(),
        'precipitationProbability': _numberAt(
          daily,
          'precipitation_probability_max',
          index,
        ).round(),
        'windSpeedMax': _oneDecimal(
          _numberAt(daily, 'wind_speed_10m_max', index),
        ),
        'sunrise': _textAt(daily, 'sunrise', index),
        'sunset': _textAt(daily, 'sunset', index),
        'weatherCode': code,
        'condition': _weatherLabel(code),
        ..._weatherFlags(code),
      });
    }
    return result;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cache.clear();
    _client.close();
    final fallback = _fallback;
    if (fallback is DisposableMiniProgramBackendConnector) {
      fallback.dispose();
    }
  }
}

MiniProgramBackendResult _success(
  MiniProgramBackendRequest request,
  Map<String, dynamic> data, {
  bool fromCache = false,
}) {
  return MiniProgramBackendResult.success(
    requestId: request.requestId,
    endpoint: request.endpoint,
    method: request.method.toUpperCase(),
    statusCode: 200,
    data: data,
    fromCache: fromCache,
  );
}

MiniProgramBackendResult _failure(
  MiniProgramBackendRequest request, {
  required String code,
  required String message,
  int? statusCode,
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return MiniProgramBackendResult.failed(
    requestId: request.requestId,
    endpoint: request.endpoint,
    method: request.method.toUpperCase(),
    statusCode: statusCode,
    errorCode: code,
    message: message,
    data: data,
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _boundedText(
  Object? value, {
  required String name,
  int minLength = 1,
  required int maxLength,
  String? fallback,
}) {
  final text = _text(value, fallback: fallback ?? '');
  if (text.length < minLength || text.length > maxLength) {
    throw _WeatherRequestException(
      code: 'open_meteo_invalid_request',
      message: '$name must contain $minLength to $maxLength characters.',
    );
  }
  return text;
}

num _boundedNumber(
  Object? value, {
  required String name,
  required num min,
  required num max,
}) {
  final parsed = _nullableNumber(value);
  if (parsed == null || parsed < min || parsed > max) {
    throw _WeatherRequestException(
      code: 'open_meteo_invalid_request',
      message: '$name must be a finite number from $min to $max.',
    );
  }
  return parsed;
}

num? _nullableNumber(Object? value) {
  final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

num _number(Object? value, {num fallback = 0}) =>
    _nullableNumber(value) ?? fallback;

int _integer(Object? value, {int fallback = 0}) =>
    _nullableNumber(value)?.round() ?? fallback;

num _numberAt(Map<String, dynamic> data, String key, int index) {
  final values = _list(data[key]);
  return index >= 0 && index < values.length ? _number(values[index]) : 0;
}

int _integerAt(Map<String, dynamic> data, String key, int index) =>
    _numberAt(data, key, index).round();

String _textAt(Map<String, dynamic> data, String key, int index) {
  final values = _list(data[key]);
  return index >= 0 && index < values.length ? _text(values[index]) : '';
}

num _oneDecimal(num value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
}

String _dateTimeLabel(String value) =>
    value.isEmpty ? 'Local time unavailable' : value.replaceFirst('T', ' ');

String _timeLabel(String value) {
  final separator = value.indexOf('T');
  return separator >= 0 && separator + 1 < value.length
      ? value.substring(separator + 1)
      : value;
}

String _dayLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }
  return const <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][date.weekday - 1];
}

Map<String, bool> _weatherFlags(int code) {
  final isStorm = code >= 95;
  final isSnow = (code >= 71 && code <= 77) || code == 85 || code == 86;
  final isRain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
  final isFog = code == 45 || code == 48;
  final isCloudy = code >= 1 && code <= 3;
  return <String, bool>{
    'isStorm': isStorm,
    'isSnow': isSnow,
    'isRain': isRain,
    'isFog': isFog,
    'isCloudy': isCloudy,
    'isClear': !isStorm && !isSnow && !isRain && !isFog && !isCloudy,
  };
}

String _weatherLabel(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code == 85 || code == 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Weather code $code';
}

String _canonicalJson(Map<String, dynamic> value) {
  Object? normalize(Object? input) {
    if (input is Map) {
      final keys = input.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: normalize(input[key]),
      };
    }
    if (input is List) {
      return input.map(normalize).toList(growable: false);
    }
    return input;
  }

  return jsonEncode(normalize(value));
}

class _CachedWeatherResponse {
  const _CachedWeatherResponse({required this.data, required this.expiresAt});

  final Map<String, dynamic> data;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _WeatherRequestException implements Exception {
  const _WeatherRequestException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;
}
