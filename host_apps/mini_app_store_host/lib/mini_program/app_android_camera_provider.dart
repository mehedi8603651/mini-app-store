import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for delegated system-camera photo capture.
///
/// Native paths and content URIs remain private to the host. Tooling creates
/// this file once and never overwrites host edits.
class AppAndroidCameraProvider
    implements MiniProgramCameraProvider, MiniProgramMediaProvider {
  const AppAndroidCameraProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/camera';

  final MethodChannel _channel;

  @override
  Future<MiniProgramCameraPhotoResult> capturePhoto(
    MiniProgramCameraCaptureRequest request,
  ) async {
    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('capturePhoto', <String, Object?>{
            'captureId': request.captureId,
            'miniProgramId': request.miniProgramId,
            'quality': request.quality,
            'maxWidth': request.maxWidth,
            'maxHeight': request.maxHeight,
          });
      if (response == null) {
        throw const MiniProgramCameraException(
          errorCode: MiniProgramErrorCodes.cameraInvalidResult,
          message: 'Android returned an empty camera result.',
        );
      }
      try {
        return MiniProgramCameraPhotoResult.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramCameraException(
          errorCode: MiniProgramErrorCodes.cameraInvalidResult,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      throw _cameraException(error);
    } on MissingPluginException {
      throw const MiniProgramCameraException(
        errorCode: MiniProgramErrorCodes.cameraUnavailable,
        message: 'Android photo capture support is unavailable.',
      );
    }
  }

  @override
  Future<bool> cancel(String captureId) async {
    try {
      return await _channel.invokeMethod<bool>('cancel', <String, Object?>{
            'captureId': captureId,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw _cameraException(error);
    } on MissingPluginException {
      throw const MiniProgramCameraException(
        errorCode: MiniProgramErrorCodes.cameraUnavailable,
        message: 'Android photo capture support is unavailable.',
      );
    }
  }

  @override
  Future<void> release(String mediaRef) async {
    try {
      await _channel.invokeMethod<void>('release', <String, Object?>{
        'mediaRef': mediaRef,
      });
    } on PlatformException catch (error) {
      throw _cameraException(error);
    } on MissingPluginException {
      throw const MiniProgramCameraException(
        errorCode: MiniProgramErrorCodes.cameraUnavailable,
        message: 'Android photo capture support is unavailable.',
      );
    }
  }

  @override
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  ) async {
    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('loadPreview', <String, Object?>{
            'miniProgramId': request.miniProgramId,
            'mediaRef': request.mediaRef,
            'maxBytes': request.maxBytes,
          });
      final bytes = response?['bytes'];
      if (response == null || bytes is! Uint8List) {
        throw const MiniProgramMediaException(
          errorCode: MiniProgramErrorCodes.mediaInvalidResult,
          message: 'Android returned an invalid media preview.',
        );
      }
      return MiniProgramMediaPreviewResult(
        mediaRef: response['mediaRef']?.toString() ?? '',
        mimeType: response['mimeType']?.toString() ?? '',
        bytes: bytes,
      );
    } on PlatformException catch (error) {
      throw _mediaException(error);
    } on MissingPluginException {
      throw const MiniProgramMediaException(
        errorCode: MiniProgramErrorCodes.mediaUnavailable,
        message: 'Android temporary media support is unavailable.',
      );
    }
  }

  @override
  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request) async {
    try {
      return await _channel.invokeMethod<bool>(
            'releaseMedia',
            <String, Object?>{
              'miniProgramId': request.miniProgramId,
              'mediaRef': request.mediaRef,
            },
          ) ??
          false;
    } on PlatformException catch (error) {
      throw _mediaException(error);
    } on MissingPluginException {
      throw const MiniProgramMediaException(
        errorCode: MiniProgramErrorCodes.mediaUnavailable,
        message: 'Android temporary media support is unavailable.',
      );
    }
  }

  static MiniProgramCameraException _cameraException(PlatformException error) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.cameraUnavailable,
      MiniProgramErrorCodes.cameraPermissionDenied,
      MiniProgramErrorCodes.cameraPermissionDeniedPermanently,
      MiniProgramErrorCodes.cameraCaptureCancelled,
      MiniProgramErrorCodes.cameraRequestInProgress,
      MiniProgramErrorCodes.cameraInvalidResult,
      MiniProgramErrorCodes.cameraStorageUnavailable,
    };
    return MiniProgramCameraException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.cameraUnavailable,
      message: error.message ?? 'Android photo capture failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }

  static MiniProgramMediaException _mediaException(PlatformException error) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.mediaUnavailable,
      MiniProgramErrorCodes.mediaNotFound,
      MiniProgramErrorCodes.mediaNotOwned,
      MiniProgramErrorCodes.mediaPreviewTooLarge,
      MiniProgramErrorCodes.mediaInvalidResult,
    };
    return MiniProgramMediaException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.mediaUnavailable,
      message: error.message ?? 'Android temporary media access failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
