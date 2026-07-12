import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

typedef AppNativeRouteOpener =
    Future<Object?> Function(String routeName, Map<String, dynamic> arguments);

class AppHostBridge implements HostBridge {
  const AppHostBridge({this.openNativeRoute});

  final AppNativeRouteOpener? openNativeRoute;

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    debugPrint(
      '[mini_app_store_host][analytics] ${payload.name} ${payload.properties}',
    );
    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
      message: 'Tracked event "${payload.name}".',
      data: payload.properties,
    );
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    final routeOpener = openNativeRoute;
    if (routeOpener == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Host native navigation is not configured.',
      );
    }

    try {
      final routeName = payload.route;
      final result = await routeOpener(routeName, payload.args);

      if (payload.expectResult && result == null) {
        return HostActionResult.cancelled(
          actionName: ActionNames.openNativeScreen,
          message: 'Native screen closed without returning a result.',
        );
      }

      return HostActionResult.success(
        actionName: ActionNames.openNativeScreen,
        message: 'Opened native screen "$routeName".',
        data: result is Map<String, dynamic>
            ? result
            : <String, dynamic>{'route': routeName},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[mini_app_store_host][ERROR] Failed to open native route "${payload.route}". '
        'error=$error\n$stackTrace',
      );
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Failed to open native screen "${payload.route}".',
      );
    }
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      message: 'secure_api is not enabled in this lean embedding setup.',
    );
  }
}
