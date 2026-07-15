import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_app_store_host/mini_program/mini_program_runtime_setup.dart';
import 'package:mini_app_store_host/mini_program/app_android_location_provider.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('only Weather has accepted Publisher API permission', () {
    final endpoints = buildMiniProgramEndpoints();

    expect(
      endpoints[MiniPrograms.calculator.appId]!.publisherApiPolicy.enabled,
      isFalse,
    );
    expect(
      endpoints[MiniPrograms.brainTest.appId]!.publisherApiPolicy.enabled,
      isFalse,
    );
    expect(
      endpoints[MiniPrograms.weather.appId]!.publisherApiPolicy.enabled,
      isTrue,
    );
  });

  test('only Weather accepts location and capability needs a provider', () {
    final endpoints = buildMiniProgramEndpoints();

    expect(
      endpoints[MiniPrograms.calculator.appId]!.locationPolicy.enabled,
      isFalse,
    );
    expect(
      endpoints[MiniPrograms.brainTest.appId]!.locationPolicy.enabled,
      isFalse,
    );
    expect(
      endpoints[MiniPrograms.weather.appId]!.locationPolicy.enabled,
      isTrue,
    );

    final withoutProvider = buildMiniProgramConfig(endpoints: endpoints);
    final withProvider = buildMiniProgramConfig(
      endpoints: endpoints,
      locationProvider: const AppAndroidLocationProvider(),
    );
    expect(
      withoutProvider.capabilityRegistry.supports(
        CapabilityIds.locationCurrent,
      ),
      isFalse,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.locationCurrent),
      isTrue,
    );
  });

  test('Weather 1.0.4 artifact owns its Publisher API declaration', () async {
    final contractFile = _weatherArtifactFile('publisher_backend.json');
    final releaseFile = _weatherArtifactFile('release.json');

    expect(await contractFile.exists(), isTrue);
    final contract = MiniProgramPublisherBackendContract.fromJson(
      jsonDecode(await contractFile.readAsString()),
    );
    final release =
        jsonDecode(await releaseFile.readAsString()) as Map<String, dynamic>;

    expect(contract.appId, MiniPrograms.weather.appId);
    expect(contract.backendBaseUri.scheme, 'https');
    expect(
      contract.permissionReason,
      'Load current forecasts and global fallback locations.',
    );
    expect(release['publisherBackend'], 'publisher_backend.json');
  });

  test(
    'artifact-declared URL reaches the live Weather Publisher API',
    () async {
      final contract = MiniProgramPublisherBackendContract.fromJson(
        jsonDecode(
          await _weatherArtifactFile('publisher_backend.json').readAsString(),
        ),
      );
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          contract.appId: MiniProgramBackendEndpoint(
            baseUri: contract.backendBaseUri,
          ),
        },
        deliveryContext: const MiniProgramDeliveryContext(
          hostApp: 'mini-app-store-host-test',
          hostVersion: 'test',
          sdkVersion: 'test',
          capabilities: <String>{},
        ),
      );
      try {
        final result = await connector.call(
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
        connector.dispose();
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_WEATHER_TESTS'),
  );
}

File _weatherArtifactFile(String name) {
  return File('../../mini-apps/weather/artifacts/weather/1.0.4/$name');
}
