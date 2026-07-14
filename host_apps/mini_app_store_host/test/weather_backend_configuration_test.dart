import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('only Weather has a configured Publisher API endpoint', () {
    final endpoints = buildMiniProgramEndpoints();

    expect(endpoints[MiniPrograms.calculator.appId]!.backend, isNull);
    expect(endpoints[MiniPrograms.brainTest.appId]!.backend, isNull);
    expect(
      endpoints[MiniPrograms.weather.appId]!.backend!.baseUri,
      Uri.parse('https://5ibchf95dc.execute-api.ap-south-1.amazonaws.com'),
    );
  });

  test(
    'live SDK connector reaches the Weather Publisher API',
    () async {
      final connector = buildEndpointRoutingBackendConnector(
        endpoints: buildMiniProgramEndpoints(),
        deliveryContext: const MiniProgramDeliveryContext(
          hostApp: 'mini-app-store-host-test',
          hostVersion: 'test',
          sdkVersion: 'test',
          capabilities: <String>{},
        ),
      );
      expect(connector, isNotNull);

      try {
        final result = await connector!.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'weather',
            requestId: 'live-weather-forecast',
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

        expect(
          result.isSuccess,
          isTrue,
          reason: '${result.errorCode}: ${result.message}',
        );
        expect(result.data['hourly'], isNotEmpty);
        expect(result.data['daily'], hasLength(7));
      } finally {
        if (connector is DisposableMiniProgramBackendConnector) {
          connector.dispose();
        }
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_WEATHER_TESTS'),
  );
}
