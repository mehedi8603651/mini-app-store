import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android CameraManager adapter for foreground torch control.
///
/// Tooling creates this file once and never overwrites host edits.
class AppAndroidFlashlightProvider implements MiniProgramFlashlightProvider {
  const AppAndroidFlashlightProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/flashlight';

  final MethodChannel _channel;

  @override
  Future<MiniProgramFlashlightStatus> setEnabled(bool enabled) {
    return _invoke('setEnabled', <String, Object?>{'enabled': enabled});
  }

  @override
  Future<MiniProgramFlashlightStatus> getStatus() => _invoke('getStatus');

  Future<MiniProgramFlashlightStatus> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (response == null) {
        throw const MiniProgramFlashlightException(
          errorCode: MiniProgramErrorCodes.flashlightOperationFailed,
          message: 'Android returned an empty flashlight result.',
        );
      }
      try {
        return MiniProgramFlashlightStatus.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramFlashlightException(
          errorCode: MiniProgramErrorCodes.flashlightOperationFailed,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      throw _flashlightException(error);
    } on MissingPluginException {
      throw const MiniProgramFlashlightException(
        errorCode: MiniProgramErrorCodes.flashlightUnavailable,
        message: 'Android flashlight support is unavailable.',
      );
    }
  }

  static MiniProgramFlashlightException _flashlightException(
    PlatformException error,
  ) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.flashlightUnavailable,
      MiniProgramErrorCodes.flashlightPermissionDenied,
      MiniProgramErrorCodes.flashlightPermissionDeniedPermanently,
      MiniProgramErrorCodes.flashlightInUse,
      MiniProgramErrorCodes.flashlightOperationFailed,
    };
    return MiniProgramFlashlightException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.flashlightOperationFailed,
      message: error.message ?? 'Android flashlight operation failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
