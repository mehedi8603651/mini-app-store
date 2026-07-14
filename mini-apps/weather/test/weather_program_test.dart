import 'dart:convert';

import 'package:test/test.dart';

import '../mp/screens/weather_home.dart';
import '../mp/screens/weather_search.dart';
import '../mp/weather_actions.dart';

void main() {
  test('home includes refresh chart and horizontal forecast collections', () {
    final encoded = jsonEncode(buildWeatherHome().toJson());

    expect(encoded, contains('refreshIndicator'));
    expect(encoded, contains('lineChart'));
    expect(encoded, contains('"direction":"horizontal"'));
    expect(encoded, contains(weatherForecastRequest));
    expect(encoded, contains('data/bangladesh_thana_area.json'));
    expect(encoded, contains('data/bangladesh_upzila_area.json'));
  });

  test('search combines two local resources before global fallback', () {
    final encoded = jsonEncode(buildWeatherSearch().toJson());

    expect(encoded, contains('data.search'));
    expect(encoded, contains('bd_thana_area'));
    expect(encoded, contains('bd_upazila_area'));
    expect(encoded, contains(weatherGeocodingRequest));
    expect(encoded, contains('action.ifElse'));
  });

  test('selected location is persisted before forecast refresh', () {
    final encoded = jsonEncode(selectWeatherLocation(local: true).toJson());

    expect(encoded, contains('weather_selected_location'));
    expect(encoded, contains(weatherForecastRequest));
    expect(encoded, contains('router.pop'));
  });
}
