import 'package:mini_program_ui/mini_program_ui.dart';

const weatherForecastRequest = 'weather_forecast';
const weatherGeocodingRequest = 'weather_geocoding';

const Map<String, Object?> defaultWeatherLocation = <String, Object?>{
  'name': 'Dhaka',
  'subtitle': 'Dhaka, Bangladesh',
  'country': 'Bangladesh',
  'latitude': 23.8103,
  'longitude': 90.4125,
  'source': 'Default location',
};

List<MpAction> initializeWeather() => <MpAction>[
  Mp.cache.state.get(
    'weather_selected_location',
    targetState: 'weather.location',
    skipMissing: true,
    requestId: 'weather-load-location',
  ),
  Mp.state.setDefault('weather.location', defaultWeatherLocation),
  Mp.data.loadJsonAsset(
    id: 'bd_thana_area',
    asset: 'data/bangladesh_thana_area.json',
    ttl: const Duration(days: 30),
    statusState: 'weather.data.thana_status',
    errorState: 'weather.data.thana_error',
    requestId: 'weather-load-thana-area',
  ),
  Mp.data.loadJsonAsset(
    id: 'bd_upazila_area',
    asset: 'data/bangladesh_upzila_area.json',
    ttl: const Duration(days: 30),
    statusState: 'weather.data.upazila_status',
    errorState: 'weather.data.upazila_error',
    requestId: 'weather-load-upazila-area',
  ),
];

List<MpAction> initializeWeatherSearch() => <MpAction>[
  Mp.data.loadJsonAsset(
    id: 'bd_thana_area',
    asset: 'data/bangladesh_thana_area.json',
    ttl: const Duration(days: 30),
    statusState: 'weather.search.thana_resource_status',
    errorState: 'weather.search.thana_resource_error',
    requestId: 'weather-search-load-thana-area',
  ),
  Mp.data.loadJsonAsset(
    id: 'bd_upazila_area',
    asset: 'data/bangladesh_upzila_area.json',
    ttl: const Duration(days: 30),
    statusState: 'weather.search.upazila_resource_status',
    errorState: 'weather.search.upazila_resource_error',
    requestId: 'weather-search-load-upazila-area',
  ),
  Mp.state.setDefault('weather.search.query', ''),
  Mp.state.setDefault('weather.search.local_count', 0),
  Mp.state.setDefault('weather.search.use_remote', false),
];

MpAction refreshWeather({bool forceRefresh = false}) {
  return Mp.backend.query(
    requestId: weatherForecastRequest,
    endpoint: 'forecast',
    method: 'POST',
    body: const <String, Object?>{
      'latitude': '{{state.weather.location.latitude}}',
      'longitude': '{{state.weather.location.longitude}}',
      'locationName': '{{state.weather.location.name}}',
    },
    cacheTtlSeconds: 600,
    forceRefresh: forceRefresh,
  );
}

MpAction searchWeatherLocations() {
  return Mp.action.sequence(<MpAction>[
    Mp.data.search(
      resourceId: 'bd_thana_area',
      query: '{{state.weather.search.query}}',
      fields: const <String>['name', 'kind', 'parent', 'district', 'division'],
      itemsPath: 'locations',
      minQueryLength: 2,
      limit: 8,
      targetState: 'weather.search.thana',
      statusState: 'weather.search.thana_status',
      errorState: 'weather.search.thana_error',
    ),
    Mp.data.search(
      resourceId: 'bd_upazila_area',
      query: '{{state.weather.search.query}}',
      fields: const <String>['name', 'kind', 'parent', 'district', 'division'],
      itemsPath: 'locations',
      minQueryLength: 2,
      limit: 8,
      targetState: 'weather.search.upazila',
      statusState: 'weather.search.upazila_status',
      errorState: 'weather.search.upazila_error',
    ),
    Mp.math.evaluate(
      expression:
          '{{state.weather.search.thana.matchCount}} + '
          '{{state.weather.search.upazila.matchCount}}',
      targetState: 'weather.search.local_count',
      errorState: 'weather.search.count_error',
    ),
    Mp.math.compare(
      left: '{{state.weather.search.local_count}}',
      right: 0,
      comparison: 'equal',
      targetState: 'weather.search.use_remote',
      errorState: 'weather.search.compare_error',
    ),
    Mp.action.ifElse(
      condition: '{{state.weather.search.use_remote}}',
      thenAction: Mp.backend.query(
        requestId: weatherGeocodingRequest,
        endpoint: 'geocoding',
        method: 'POST',
        body: const <String, Object?>{
          'query': '{{state.weather.search.query}}',
          'count': 10,
        },
        cacheTtlSeconds: 86400,
      ),
      elseAction: Mp.state.set('weather.search.remote_skipped', true),
    ),
  ]);
}

MpAction selectWeatherLocation({required bool local}) {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('weather.location', <String, Object?>{
      'name': '{{item.name}}',
      'subtitle': '{{item.subtitle}}',
      'country': local ? 'Bangladesh' : '{{item.country}}',
      'latitude': '{{item.latitude}}',
      'longitude': '{{item.longitude}}',
      'source': local ? 'Bangladesh local index' : '{{item.source}}',
    }),
    Mp.cache.state.set(
      'weather_selected_location',
      '{{state.weather.location}}',
      requestId: 'weather-save-location',
    ),
    Mp.toast(message: 'Loading forecast for {{item.name}}'),
    refreshWeather(forceRefresh: true),
    Mp.router.pop(),
  ]);
}
