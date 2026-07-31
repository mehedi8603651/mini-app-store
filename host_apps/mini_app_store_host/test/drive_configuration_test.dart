import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/app_android_file_transfer_provider.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_app_store_host/mini_program/mini_program_runtime_setup.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

void main() {
  test('Drive accepts bounded Publisher API and file transfer policy', () {
    final endpoint = buildMiniProgramEndpoints()[MiniPrograms.drive.appId]!;

    expect(endpoint.publisherApiPolicy.enabled, isTrue);
    expect(endpoint.filePolicy.enabled, isTrue);
    expect(endpoint.filePolicy.allowUpload, isTrue);
    expect(endpoint.filePolicy.allowDownload, isTrue);
    expect(endpoint.filePolicy.maxFileBytes, 3 * 1024 * 1024);
    expect(endpoint.filePolicy.maxFilesPerUpload, 3);
    expect(endpoint.filePolicy.maxConcurrentTransfers, 2);
  });

  test('file capabilities are advertised only with a host provider', () {
    final endpoints = buildMiniProgramEndpoints();
    final withoutProvider = buildMiniProgramConfig(endpoints: endpoints);
    final withProvider = buildMiniProgramConfig(
      endpoints: endpoints,
      fileTransferProvider: AppAndroidFileTransferProvider(),
    );

    expect(
      withoutProvider.capabilityRegistry.supports(CapabilityIds.fileUpload),
      isFalse,
    );
    expect(
      withoutProvider.capabilityRegistry.supports(CapabilityIds.fileDownload),
      isFalse,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.fileUpload),
      isTrue,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.fileDownload),
      isTrue,
    );
  });

  test('Drive 1.0.0 artifact owns its Publisher API declaration', () async {
    final contract = MiniProgramPublisherBackendContract.fromJson(
      jsonDecode(
        await _driveArtifactFile('publisher_backend.json').readAsString(),
      ),
    );
    final manifest =
        jsonDecode(await _driveArtifactFile('manifest.json').readAsString())
            as Map<String, dynamic>;
    final release =
        jsonDecode(await _driveArtifactFile('release.json').readAsString())
            as Map<String, dynamic>;

    expect(contract.appId, MiniPrograms.drive.appId);
    expect(contract.backendBaseUri.scheme, 'https');
    expect(manifest['requiredCapabilities'], <String>[
      CapabilityIds.fileUpload,
      CapabilityIds.fileDownload,
    ]);
    expect(release['publisherBackend'], 'publisher_backend.json');
  });
}

File _driveArtifactFile(String name) {
  return File('../../mini-apps/drive/artifacts/drive/1.0.0/$name');
}
