import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Android MethodChannel adapter for one-time approximate foreground location.
class AppAndroidLocationProvider implements MiniProgramLocationProvider {
  const AppAndroidLocationProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/location';

  final MethodChannel _channel;

  @override
  Future<MiniProgramLocationResult> getCurrentLocation({
    required MiniProgramLocationAccuracy accuracy,
    required Duration timeout,
  }) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
        <String, Object?>{
          'accuracy': accuracy.wireValue,
          'timeoutMs': timeout.inMilliseconds,
        },
      );
      if (response == null) {
        throw const MiniProgramLocationException(
          errorCode: MiniProgramErrorCodes.locationInvalidResult,
          message: 'Android returned an empty current-location result.',
        );
      }
      try {
        return MiniProgramLocationResult.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramLocationException(
          errorCode: MiniProgramErrorCodes.locationInvalidResult,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      final code = _stableErrorCode(error.code);
      throw MiniProgramLocationException(
        errorCode: code,
        message: error.message ?? _defaultMessage(code),
        details: <String, Object?>{
          if (error.details != null) 'platformDetails': '${error.details}',
        },
      );
    } on MissingPluginException {
      throw const MiniProgramLocationException(
        errorCode: MiniProgramErrorCodes.locationUnavailable,
        message: 'Android current-location support is unavailable.',
      );
    }
  }

  static String _stableErrorCode(String code) {
    return switch (code) {
      MiniProgramErrorCodes.locationPermissionDenied => code,
      MiniProgramErrorCodes.locationPermissionDeniedPermanently => code,
      MiniProgramErrorCodes.locationServiceDisabled => code,
      MiniProgramErrorCodes.locationTimeout => code,
      MiniProgramErrorCodes.locationRequestInProgress => code,
      MiniProgramErrorCodes.locationInvalidResult => code,
      _ => MiniProgramErrorCodes.locationUnavailable,
    };
  }

  static String _defaultMessage(String code) {
    return switch (code) {
      MiniProgramErrorCodes.locationPermissionDenied =>
        'Approximate location permission was denied.',
      MiniProgramErrorCodes.locationPermissionDeniedPermanently =>
        'Approximate location permission is permanently denied.',
      MiniProgramErrorCodes.locationServiceDisabled =>
        'Android location services are disabled.',
      MiniProgramErrorCodes.locationTimeout =>
        'The current-location request timed out.',
      MiniProgramErrorCodes.locationRequestInProgress =>
        'A current-location request is already in progress.',
      MiniProgramErrorCodes.locationInvalidResult =>
        'Android returned an invalid current-location result.',
      _ => 'Android current location is unavailable.',
    };
  }
}
