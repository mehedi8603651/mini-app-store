import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'app_host_bridge.dart';

const String _hostAppId = 'mini_app_store_host';
const String _sdkVersion = '1.0.0';
const String _hostVersion = '1.0.0';
const String _configuredBackendBaseUrl = String.fromEnvironment(
  'MINI_PROGRAM_BACKEND_BASE_URL',
  defaultValue: '',
);
const String _configuredBackendHost = String.fromEnvironment(
  'MINI_PROGRAM_BACKEND_HOST',
  defaultValue: '',
);
const int _configuredBackendPort = int.fromEnvironment(
  'MINI_PROGRAM_BACKEND_PORT',
  defaultValue: LocalMiniProgramBackendDefaults.defaultPort,
);

MiniProgramConfig buildMiniProgramConfig({
  AppNativeRouteOpener? openNativeRoute,
  Map<String, MiniProgramEndpoint> endpoints =
      const <String, MiniProgramEndpoint>{},
  MiniProgramCacheBundle? cacheBundle,
}) {
  final locale =
      WidgetsFlutterBinding.ensureInitialized().platformDispatcher.locale;
  final supportedCapabilities = <CapabilityId>{
    CapabilityIds.analytics,
    if (openNativeRoute != null) CapabilityIds.nativeNavigation,
  };
  final deliveryContext = MiniProgramDeliveryContext(
    hostApp: _hostAppId,
    sdkVersion: _sdkVersion,
    hostVersion: _hostVersion,
    capabilities: supportedCapabilities,
    platform: _platformName(),
    locale: locale.toLanguageTag(),
  );
  final source = endpoints.isEmpty
      ? _buildDefaultHttpSource(deliveryContext)
      : _buildEndpointRoutingSource(endpoints, deliveryContext);
  return MiniProgramConfig(
    sdkVersion: _sdkVersion,
    source: source,
    hostBridge: AppHostBridge(openNativeRoute: openNativeRoute),
    capabilityRegistry: CapabilityRegistry(supportedCapabilities),
    authController: MiniProgramAuthController.secure(),
    disposeAuthController: true,
    cacheBundle: cacheBundle ?? MiniProgramCacheBundle.inMemory(),
  );
}

MiniProgramSource _buildDefaultHttpSource(
  MiniProgramDeliveryContext deliveryContext,
) {
  final artifactBaseUri = LocalMiniProgramBackendDefaults.resolveBaseUri(
    configuredBaseUrl: _configuredBackendBaseUrl,
    configuredHost: _configuredBackendHost,
    configuredPort: _configuredBackendPort,
  );
  _logResolvedArtifactBaseUri(artifactBaseUri);
  return HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: artifactBaseUri,
    deliveryContext: deliveryContext,
  );
}

MiniProgramSource _buildEndpointRoutingSource(
  Map<String, MiniProgramEndpoint> endpoints,
  MiniProgramDeliveryContext deliveryContext,
) {
  _logEndpointRouting(endpoints);
  return EndpointRoutingMiniProgramSource(
    endpoints: endpoints,
    deliveryContext: deliveryContext,
  );
}

void _logResolvedArtifactBaseUri(Uri artifactBaseUri) {
  debugPrint(
    '[mini_program][runtime] Static artifact base URL: $artifactBaseUri '
    '(source: ${_artifactResolutionSource()})',
  );
}

void _logEndpointRouting(Map<String, MiniProgramEndpoint> endpoints) {
  final appIds = endpoints.keys.toList()..sort();
  debugPrint(
    '[mini_program][runtime] Endpoint routing enabled for '
    '${appIds.length} mini-program endpoint(s): ${appIds.join(', ')}',
  );
}

String _artifactResolutionSource() {
  if (_configuredBackendBaseUrl.isNotEmpty) {
    return 'MINI_PROGRAM_BACKEND_BASE_URL';
  }
  if (_configuredBackendHost.isNotEmpty ||
      _configuredBackendPort != LocalMiniProgramBackendDefaults.defaultPort) {
    return 'MINI_PROGRAM_BACKEND_HOST/PORT';
  }
  if (kIsWeb) {
    return 'target_default:web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'target_default:android',
    TargetPlatform.iOS => 'target_default:ios',
    TargetPlatform.macOS => 'target_default:macos',
    TargetPlatform.windows => 'target_default:windows',
    TargetPlatform.linux => 'target_default:linux',
    TargetPlatform.fuchsia => 'target_default:fuchsia',
  };
}

String _platformName() {
  if (kIsWeb) {
    return 'web';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}
