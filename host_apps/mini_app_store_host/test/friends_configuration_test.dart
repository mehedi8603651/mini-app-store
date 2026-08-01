import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/app_android_qr_scanner_provider.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_app_store_host/mini_program/mini_program_runtime_setup.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

void main() {
  test('Friends accepts Publisher API and QR scanner policy', () {
    final endpoint = buildMiniProgramEndpoints()[MiniPrograms.friends.appId]!;

    expect(endpoint.publisherApiPolicy.enabled, isTrue);
    expect(endpoint.qrPolicy.enabled, isTrue);
    expect(endpoint.qrPolicy.allowTorch, isTrue);
    expect(endpoint.cameraPolicy.enabled, isFalse);
    expect(endpoint.flashlightPolicy.enabled, isFalse);
  });

  test('QR capability is advertised only with a host provider', () {
    final endpoints = buildMiniProgramEndpoints();
    final withoutProvider = buildMiniProgramConfig(endpoints: endpoints);
    final withProvider = buildMiniProgramConfig(
      endpoints: endpoints,
      qrScannerProvider: const AppAndroidQrScannerProvider(),
    );

    expect(
      withoutProvider.capabilityRegistry.supports(CapabilityIds.qrScanner),
      isFalse,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.qrScanner),
      isTrue,
    );
  });

  test('Friends artifact owns its Publisher API declaration', () async {
    final contract = MiniProgramPublisherBackendContract.fromJson(
      jsonDecode(
        await _friendsArtifactFile('publisher_backend.json').readAsString(),
      ),
    );
    final manifest =
        jsonDecode(await _friendsArtifactFile('manifest.json').readAsString())
            as Map<String, dynamic>;
    final release =
        jsonDecode(await _friendsArtifactFile('release.json').readAsString())
            as Map<String, dynamic>;

    expect(contract.appId, MiniPrograms.friends.appId);
    expect(contract.backendBaseUri.scheme, 'https');
    expect(manifest['requiredCapabilities'], <String>[CapabilityIds.qrScanner]);
    expect(release['publisherBackend'], 'publisher_backend.json');
  });
}

File _friendsArtifactFile(String name) {
  return File('../../mini-apps/friends/artifacts/friends/1.0.0/$name');
}
