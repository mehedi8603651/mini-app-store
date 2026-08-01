import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/app_android_flashlight_provider.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_app_store_host/mini_program/mini_program_runtime_setup.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

void main() {
  test('Flashlight is accepted only for its endpoint', () {
    final endpoints = buildMiniProgramEndpoints();

    expect(
      endpoints[MiniPrograms.flashlight.appId]!.flashlightPolicy.enabled,
      isTrue,
    );
    expect(
      endpoints[MiniPrograms.calculator.appId]!.flashlightPolicy.enabled,
      isFalse,
    );
  });

  test('flashlight capability requires an installed host provider', () {
    final endpoints = buildMiniProgramEndpoints();
    final withoutProvider = buildMiniProgramConfig(endpoints: endpoints);
    final withProvider = buildMiniProgramConfig(
      endpoints: endpoints,
      flashlightProvider: const AppAndroidFlashlightProvider(),
    );

    expect(
      withoutProvider.capabilityRegistry.supports(
        CapabilityIds.flashlightControl,
      ),
      isFalse,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.flashlightControl),
      isTrue,
    );
  });

  test('Flashlight 1.0.0 artifact declares only flashlight control', () async {
    final manifest =
        jsonDecode(
              await _flashlightArtifactFile('manifest.json').readAsString(),
            )
            as Map<String, dynamic>;

    expect(manifest['id'], MiniPrograms.flashlight.appId);
    expect(manifest['version'], '1.0.0');
    expect(manifest['requiredCapabilities'], <String>[
      CapabilityIds.flashlightControl,
    ]);
  });
}

File _flashlightArtifactFile(String name) {
  return File('../../mini-apps/flashlight/artifacts/flashlight/1.0.0/$name');
}
