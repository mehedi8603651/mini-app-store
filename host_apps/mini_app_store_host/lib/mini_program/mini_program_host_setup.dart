import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:path_provider/path_provider.dart';

import 'app_android_file_transfer_provider.dart';
import 'app_android_location_provider.dart';
import 'app_android_camera_provider.dart';
import 'app_android_flashlight_provider.dart';
import 'app_android_qr_scanner_provider.dart';
import 'app_host_bridge.dart';
import 'mini_program_endpoints.dart';
import 'mini_program_registry.dart';
import 'mini_program_runtime_setup.dart';

const _artifactEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_ARTIFACT_URL',
  defaultValue: '',
);
const _calculatorEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_CALCULATOR_URL',
  defaultValue: '',
);
const _brainTestEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_BRAIN_TEST_URL',
  defaultValue: '',
);
const _weatherEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_WEATHER_URL',
  defaultValue: '',
);
const _notepadEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_NOTEPAD_URL',
  defaultValue: '',
);
const _driveEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_DRIVE_URL',
  defaultValue: '',
);
const _flashlightEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_FLASHLIGHT_URL',
  defaultValue: '',
);
const _friendsEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_FRIENDS_URL',
  defaultValue: '',
);

/// Host-owned composition point for mini-program runtime configuration.
///
/// This file is created once and is never overwritten by tooling. Add the
/// host's persistent cache, environment selection, and native capabilities
/// here while keeping generated endpoint and policy files untouched.
Future<MiniProgramConfig> buildHostMiniProgramConfig({
  AppNativeRouteOpener? openNativeRoute,
  Map<String, MiniProgramEndpoint>? endpoints,
  MiniProgramCacheBundle? cacheBundle,
  MiniProgramLocationProvider? locationProvider,
  MiniProgramFileTransferProvider? fileTransferProvider,
  MiniProgramCameraProvider? cameraProvider,
  MiniProgramMediaProvider? mediaProvider,
  MiniProgramFlashlightProvider? flashlightProvider,
  MiniProgramQrScannerProvider? qrScannerProvider,
}) async {
  final resolvedCacheBundle = cacheBundle ?? await _buildPersistentCache();
  final resolvedLocationProvider =
      locationProvider ??
      (Platform.isAndroid ? const AppAndroidLocationProvider() : null);
  final resolvedFileTransferProvider =
      fileTransferProvider ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AppAndroidFileTransferProvider()
          : null);

  final resolvedCameraProvider =
      cameraProvider ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const AppAndroidCameraProvider()
          : null);

  final MiniProgramMediaProvider? resolvedMediaProvider =
      mediaProvider ??
      (resolvedCameraProvider is MiniProgramMediaProvider
          ? resolvedCameraProvider as MiniProgramMediaProvider
          : null);

  final resolvedFlashlightProvider =
      flashlightProvider ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const AppAndroidFlashlightProvider()
          : null);

  final resolvedQrScannerProvider =
      qrScannerProvider ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? const AppAndroidQrScannerProvider()
          : null);

  return buildMiniProgramConfig(
    openNativeRoute: openNativeRoute,
    endpoints: endpoints ?? _buildConfiguredEndpoints(),
    cacheBundle: resolvedCacheBundle,
    locationProvider: resolvedLocationProvider,
    fileTransferProvider: resolvedFileTransferProvider,
    cameraProvider: resolvedCameraProvider,
    mediaProvider: resolvedMediaProvider,
    flashlightProvider: resolvedFlashlightProvider,
    qrScannerProvider: resolvedQrScannerProvider,
  );
}

Future<MiniProgramCacheBundle> _buildPersistentCache() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return MiniProgramCacheBundle.fileBacked(
    rootDirectory: Directory(
      '${supportDirectory.path}${Platform.pathSeparator}mini_program_cache',
    ),
  );
}

Map<String, MiniProgramEndpoint> _buildConfiguredEndpoints() {
  final endpoints = buildMiniProgramEndpoints();
  final sharedOverride = _artifactEndpointOverride.trim();
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.calculator.appId,
    _calculatorEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _calculatorEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.brainTest.appId,
    _brainTestEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _brainTestEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.weather.appId,
    _weatherEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _weatherEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.notepad.appId,
    _notepadEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _notepadEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.drive.appId,
    _driveEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _driveEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.flashlight.appId,
    _flashlightEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _flashlightEndpointOverride.trim(),
  );
  _applyEndpointOverride(
    endpoints,
    MiniPrograms.friends.appId,
    _friendsEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _friendsEndpointOverride.trim(),
  );
  return endpoints;
}

void _applyEndpointOverride(
  Map<String, MiniProgramEndpoint> endpoints,
  String appId,
  String override,
) {
  if (override.isEmpty) {
    return;
  }

  final current = endpoints[appId];
  if (current == null) {
    return;
  }
  endpoints[appId] = MiniProgramEndpoint.public(
    apiBaseUri: Uri.parse(override),
    headers: current.headers,
    requestTimeout: current.requestTimeout,
    enableLocalLoopbackFallback: current.enableLocalLoopbackFallback,
    cachePolicy: current.cachePolicy,
    liveStatePolicy: current.liveStatePolicy,
    publisherApiPolicy: current.publisherApiPolicy,
    locationPolicy: current.locationPolicy,
    filePolicy: current.filePolicy,
    cameraPolicy: current.cameraPolicy,
    flashlightPolicy: current.flashlightPolicy,
    qrPolicy: current.qrPolicy,
  );
}
