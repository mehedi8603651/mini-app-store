import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/app_android_media_playback_provider.dart';
import 'package:mini_app_store_host/mini_program/mini_program_endpoints.dart';
import 'package:mini_app_store_host/mini_program/mini_program_registry.dart';
import 'package:mini_app_store_host/mini_program/mini_program_runtime_setup.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

void main() {
  test('Media Lab accepts Publisher API, playback, and cache policy', () {
    final endpoint = buildMiniProgramEndpoints()[MiniPrograms.media.appId]!;

    expect(endpoint.publisherApiPolicy.enabled, isTrue);
    expect(endpoint.mediaPlaybackPolicy.audioEnabled, isTrue);
    expect(endpoint.mediaPlaybackPolicy.videoEnabled, isTrue);
    expect(endpoint.mediaPlaybackPolicy.audioTemporaryCacheEnabled, isTrue);
    expect(endpoint.mediaPlaybackPolicy.videoTemporaryCacheEnabled, isTrue);
    expect(endpoint.cachePolicy.maxAudioBytes, 20 * 1024 * 1024);
    expect(endpoint.cachePolicy.maxVideoBytes, 50 * 1024 * 1024);
    expect(endpoint.cachePolicy.audioTtl, const Duration(days: 1));
    expect(endpoint.cachePolicy.videoTtl, const Duration(days: 1));
  });

  test('media capabilities require the installed playback provider', () {
    final endpoints = buildMiniProgramEndpoints();
    final withoutProvider = buildMiniProgramConfig(endpoints: endpoints);
    final withProvider = buildMiniProgramConfig(
      endpoints: endpoints,
      mediaPlaybackProvider: const AppAndroidMediaPlaybackProvider(),
    );

    expect(
      withoutProvider.capabilityRegistry.supports(CapabilityIds.mediaAudio),
      isFalse,
    );
    expect(
      withoutProvider.capabilityRegistry.supports(CapabilityIds.mediaVideo),
      isFalse,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.mediaAudio),
      isTrue,
    );
    expect(
      withProvider.capabilityRegistry.supports(CapabilityIds.mediaVideo),
      isTrue,
    );
  });

  test('Media Lab artifact owns its Publisher API declaration', () async {
    final contract = MiniProgramPublisherBackendContract.fromJson(
      jsonDecode(
        await _mediaArtifactFile('publisher_backend.json').readAsString(),
      ),
    );
    final manifest =
        jsonDecode(await _mediaArtifactFile('manifest.json').readAsString())
            as Map<String, dynamic>;
    final release =
        jsonDecode(await _mediaArtifactFile('release.json').readAsString())
            as Map<String, dynamic>;

    expect(contract.appId, MiniPrograms.media.appId);
    expect(contract.backendBaseUri.scheme, 'https');
    expect(manifest['requiredCapabilities'], <String>[
      CapabilityIds.mediaAudio,
      CapabilityIds.mediaVideo,
    ]);
    expect(release['publisherBackend'], 'publisher_backend.json');
  });
}

File _mediaArtifactFile(String name) {
  return File('../../mini-apps/media/artifacts/media/1.0.0/$name');
}
