import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_app_store_host/mini_program/weather_open_meteo_connector.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test(
    'live Open-Meteo smoke check',
    () async {
      final connector = WeatherOpenMeteoConnector(
        fallback: _RecordingFallback(),
      );

      final forecast = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          requestId: 'live-forecast',
          endpoint: 'forecast',
          method: 'POST',
          body: <String, dynamic>{
            'latitude': 23.8103,
            'longitude': 90.4125,
            'locationName': 'Dhaka',
          },
          forceRefresh: true,
        ),
      );
      final geocoding = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          requestId: 'live-geocoding',
          endpoint: 'geocoding',
          method: 'POST',
          body: <String, dynamic>{'query': 'London', 'count': 2},
          forceRefresh: true,
        ),
      );

      expect(
        forecast.isSuccess,
        isTrue,
        reason: '${forecast.errorCode}: ${forecast.message}',
      );
      expect(forecast.data['hourly'], isNotEmpty);
      expect(forecast.data['daily'], hasLength(7));
      expect(
        geocoding.isSuccess,
        isTrue,
        reason: '${geocoding.errorCode}: ${geocoding.message}',
      );
      expect(geocoding.data['results'], isNotEmpty);
      connector.dispose();
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_WEATHER_TESTS'),
  );

  test('normalizes forecast data and honors cache and force refresh', () async {
    var requestCount = 0;
    final fallback = _RecordingFallback();
    final connector = WeatherOpenMeteoConnector(
      fallback: fallback,
      client: MockClient((request) async {
        requestCount++;
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.queryParameters['forecast_days'], '7');
        return http.Response(
          jsonEncode(<String, Object?>{
            'latitude': 23.81,
            'longitude': 90.41,
            'timezone': 'Asia/Dhaka',
            'current': <String, Object?>{
              'time': '2026-07-14T16:00',
              'temperature_2m': 31.4,
              'relative_humidity_2m': 72,
              'apparent_temperature': 36.1,
              'is_day': 1,
              'precipitation': 0.2,
              'weather_code': 2,
              'wind_speed_10m': 8.4,
            },
            'hourly': <String, Object?>{
              'time': <String>[
                '2026-07-14T15:00',
                '2026-07-14T16:00',
                '2026-07-14T17:00',
              ],
              'temperature_2m': <num>[30, 31.4, 30.8],
              'precipitation_probability': <num>[10, 20, 30],
              'weather_code': <num>[1, 2, 61],
              'relative_humidity_2m': <num>[70, 72, 75],
              'wind_speed_10m': <num>[7, 8.4, 9],
            },
            'daily': <String, Object?>{
              'time': <String>['2026-07-14'],
              'weather_code': <num>[2],
              'temperature_2m_max': <num>[33.2],
              'temperature_2m_min': <num>[27.1],
              'precipitation_probability_max': <num>[40],
              'sunrise': <String>['2026-07-14T05:20'],
              'sunset': <String>['2026-07-14T18:50'],
              'wind_speed_10m_max': <num>[12.5],
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    const request = MiniProgramBackendRequest(
      miniProgramId: 'weather',
      requestId: 'forecast',
      endpoint: 'forecast',
      method: 'POST',
      body: <String, dynamic>{
        'latitude': 23.81,
        'longitude': 90.41,
        'locationName': 'Dhaka',
      },
      cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 10)),
    );

    final first = await connector.call(request);
    final second = await connector.call(request);
    final refreshed = await connector.call(
      const MiniProgramBackendRequest(
        miniProgramId: 'weather',
        requestId: 'forecast',
        endpoint: 'forecast',
        method: 'POST',
        body: <String, dynamic>{
          'latitude': 23.81,
          'longitude': 90.41,
          'locationName': 'Dhaka',
        },
        cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 10)),
        forceRefresh: true,
      ),
    );

    expect(first.isSuccess, isTrue);
    expect(first.data['locationName'], 'Dhaka');
    expect((first.data['current'] as Map)['condition'], 'Partly cloudy');
    expect((first.data['hourly'] as List), hasLength(2));
    expect(
      (first.data['daily'] as List).single,
      containsPair('dayLabel', 'Tue'),
    );
    expect(second.fromCache, isTrue);
    expect(refreshed.fromCache, isFalse);
    expect(requestCount, 2);
    expect(fallback.calls, isEmpty);

    connector.dispose();
  });

  test('normalizes global geocoding results', () async {
    final connector = WeatherOpenMeteoConnector(
      fallback: _RecordingFallback(),
      client: MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        expect(request.url.queryParameters['name'], 'London');
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                'name': 'London',
                'latitude': 51.5085,
                'longitude': -0.1257,
                'country': 'United Kingdom',
                'admin1': 'England',
                'timezone': 'Europe/London',
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await connector.call(
      const MiniProgramBackendRequest(
        miniProgramId: 'weather',
        endpoint: 'geocoding',
        method: 'POST',
        body: <String, dynamic>{'query': 'London', 'count': 10},
      ),
    );

    expect(result.isSuccess, isTrue);
    final item = (result.data['results'] as List).single as Map;
    expect(item['subtitle'], 'England, United Kingdom');
    expect(item['source'], 'Open-Meteo / GeoNames');

    connector.dispose();
  });

  test('short geocoding queries resolve empty without an HTTP call', () async {
    var requests = 0;
    final connector = WeatherOpenMeteoConnector(
      fallback: _RecordingFallback(),
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    final result = await connector.call(
      const MiniProgramBackendRequest(
        miniProgramId: 'weather',
        endpoint: 'geocoding',
        body: <String, dynamic>{'query': ''},
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data['results'], isEmpty);
    expect(requests, 0);
    connector.dispose();
  });

  test('delegates every non-weather mini-program unchanged', () async {
    final fallback = _RecordingFallback();
    final connector = WeatherOpenMeteoConnector(
      fallback: fallback,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    const request = MiniProgramBackendRequest(
      miniProgramId: 'calculator',
      endpoint: 'ignored',
    );

    final result = await connector.call(request);

    expect(result.isSuccess, isTrue);
    expect(fallback.calls, <MiniProgramBackendRequest>[request]);
    connector.dispose();
    expect(fallback.disposed, isTrue);
  });
}

class _RecordingFallback implements DisposableMiniProgramBackendConnector {
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];
  bool disposed = false;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    calls.add(request);
    return MiniProgramBackendResult.success(data: const <String, dynamic>{});
  }

  @override
  void dispose() {
    disposed = true;
  }
}
