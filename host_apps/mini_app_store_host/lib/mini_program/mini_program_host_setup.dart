import 'dart:io';

import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:path_provider/path_provider.dart';

import 'app_host_bridge.dart';
import 'app_android_location_provider.dart';
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
}) async {
  final resolvedCacheBundle = cacheBundle ?? await _buildPersistentCache();
  final resolvedLocationProvider =
      locationProvider ??
      (Platform.isAndroid ? const AppAndroidLocationProvider() : null);
  return buildMiniProgramConfig(
    openNativeRoute: openNativeRoute,
    endpoints: endpoints ?? _buildConfiguredEndpoints(),
    cacheBundle: resolvedCacheBundle,
    locationProvider: resolvedLocationProvider,
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
  );
}
