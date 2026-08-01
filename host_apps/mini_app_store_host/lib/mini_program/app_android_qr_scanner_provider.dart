import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for one-time QR-only scanning.
///
/// Created once by `miniprogram host capability init qr`; tooling never
/// overwrites host edits. Scanned values remain inert data.
class AppAndroidQrScannerProvider implements MiniProgramQrScannerProvider {
  const AppAndroidQrScannerProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/qr_scanner';

  final MethodChannel _channel;

  @override
  Future<MiniProgramQrScanResult> scan(MiniProgramQrScanRequest request) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'scan',
        <String, Object?>{
          'scanId': request.scanId,
          'miniProgramId': request.miniProgramId,
          'allowTorch': request.allowTorch,
          'timeoutMs': request.timeout.inMilliseconds,
        },
      );
      if (response == null) {
        throw const MiniProgramQrException(
          errorCode: MiniProgramErrorCodes.qrInvalidResult,
          message: 'Android returned an empty QR scan result.',
        );
      }
      try {
        return MiniProgramQrScanResult.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramQrException(
          errorCode: MiniProgramErrorCodes.qrInvalidResult,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      throw _qrException(error);
    } on MissingPluginException {
      throw const MiniProgramQrException(
        errorCode: MiniProgramErrorCodes.qrUnavailable,
        message: 'Android QR scanner support is unavailable.',
      );
    }
  }

  @override
  Future<bool> cancel(String scanId) async {
    try {
      return await _channel.invokeMethod<bool>(
            'cancel',
            <String, Object?>{'scanId': scanId},
          ) ??
          false;
    } on PlatformException catch (error) {
      throw _qrException(error);
    } on MissingPluginException {
      return false;
    }
  }

  static MiniProgramQrException _qrException(PlatformException error) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.qrNotAccepted,
      MiniProgramErrorCodes.qrUnavailable,
      MiniProgramErrorCodes.qrPermissionDenied,
      MiniProgramErrorCodes.qrPermissionDeniedPermanently,
      MiniProgramErrorCodes.qrRequestInProgress,
      MiniProgramErrorCodes.qrCameraInUse,
      MiniProgramErrorCodes.qrScanCancelled,
      MiniProgramErrorCodes.qrTimeout,
      MiniProgramErrorCodes.qrInvalidResult,
      MiniProgramErrorCodes.qrOperationFailed,
    };
    return MiniProgramQrException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.qrOperationFailed,
      message: error.message ?? 'Android QR scanning failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
