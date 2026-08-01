import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for document picking and streaming Publisher API
/// file transfers.
///
/// Created by `miniprogram host capability init file`. Tooling will not
/// overwrite this file after installation.
class AppAndroidFileTransferProvider
    implements MiniProgramFileTransferProvider {
  AppAndroidFileTransferProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/files';

  final MethodChannel _channel;
  final Map<String, MiniProgramFileProgressCallback> _progress =
      <String, MiniProgramFileProgressCallback>{};
  bool _initialized = false;

  @override
  Future<MiniProgramFileTransferResult> upload(
    MiniProgramFileUploadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) {
    return _run(
      transferId: request.transferId,
      direction: MiniProgramFileTransferDirection.upload,
      onProgress: onProgress,
      method: 'upload',
      arguments: <String, Object?>{
        'miniProgramId': request.miniProgramId,
        'transferId': request.transferId,
        'candidateUrls': request.backend.candidateUris
            .map((uri) => uri.toString())
            .toList(growable: false),
        'method': request.backend.method,
        'headers': request.backend.headers,
        'timeoutMs': request.backend.timeout.inMilliseconds,
        'mimeTypes': request.mimeTypes,
        'multiple': request.multiple,
        'maxFiles': request.maxFiles,
        'fieldName': request.fieldName,
        'metadata': request.metadata,
        'maxFileBytes': request.maxFileBytes,
        'mediaRefs': request.mediaRefs,
      },
    );
  }

  @override
  Future<MiniProgramFileTransferResult> download(
    MiniProgramFileDownloadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) {
    return _run(
      transferId: request.transferId,
      direction: MiniProgramFileTransferDirection.download,
      onProgress: onProgress,
      method: 'download',
      arguments: <String, Object?>{
        'transferId': request.transferId,
        'candidateUrls': request.backend.candidateUris
            .map((uri) => uri.toString())
            .toList(growable: false),
        'method': request.backend.method,
        'headers': request.backend.headers,
        'timeoutMs': request.backend.timeout.inMilliseconds,
        'request': request.request,
        'destination': request.destination.name,
        'suggestedName': request.suggestedName,
        'expectedMimeType': request.expectedMimeType,
        'maxFileBytes': request.maxFileBytes,
        'minimumFreeBytes': request.minimumFreeBytes,
      },
    );
  }

  @override
  Future<bool> cancel(String transferId) async {
    _initialize();
    try {
      return await _channel.invokeMethod<bool>('cancel', <String, Object?>{
            'transferId': transferId,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw _fileException(
        error,
        MiniProgramErrorCodes.fileTransferUnavailable,
      );
    } on MissingPluginException {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTransferUnavailable,
        message: 'Android file transfer support is unavailable.',
      );
    }
  }

  Future<MiniProgramFileTransferResult> _run({
    required String transferId,
    required MiniProgramFileTransferDirection direction,
    required MiniProgramFileProgressCallback onProgress,
    required String method,
    required Map<String, Object?> arguments,
  }) async {
    _initialize();
    _progress[transferId] = onProgress;
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (response == null) {
        throw const MiniProgramFileException(
          errorCode: MiniProgramErrorCodes.fileInvalidResult,
          message: 'Android returned an empty file transfer result.',
        );
      }
      return _parseResult(response, transferId, direction);
    } on PlatformException catch (error) {
      throw _fileException(
        error,
        direction == MiniProgramFileTransferDirection.upload
            ? MiniProgramErrorCodes.fileUploadFailed
            : MiniProgramErrorCodes.fileDownloadFailed,
      );
    } on MissingPluginException {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTransferUnavailable,
        message: 'Android file transfer support is unavailable.',
      );
    } finally {
      _progress.remove(transferId);
    }
  }

  void _initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress' || call.arguments is! Map) {
        return;
      }
      final value = Map<String, dynamic>.from(call.arguments as Map);
      final transferId = value['transferId']?.toString() ?? '';
      final callback = _progress[transferId];
      if (callback == null) {
        return;
      }
      callback(
        MiniProgramFileTransferProgress(
          transferId: transferId,
          direction: _direction(value['direction']),
          status: MiniProgramFileTransferStatus.running,
          bytesTransferred: _requiredInt(value['bytesTransferred']),
          totalBytes: _optionalInt(value['totalBytes']),
          fileName: value['fileName']?.toString(),
        ),
      );
    });
  }

  static MiniProgramFileTransferResult _parseResult(
    Map<String, dynamic> value,
    String transferId,
    MiniProgramFileTransferDirection direction,
  ) {
    final data = value['data'] is Map
        ? Map<String, dynamic>.from(value['data'] as Map)
        : const <String, dynamic>{};
    return MiniProgramFileTransferResult(
      transferId: value['transferId']?.toString() ?? transferId,
      direction: _direction(value['direction'] ?? direction.wireValue),
      statusCode: _requiredInt(value['statusCode']),
      bytesTransferred: _requiredInt(value['bytesTransferred']),
      fileName: value['fileName']?.toString(),
      mimeType: value['mimeType']?.toString(),
      destination: value['destination']?.toString(),
      data: data,
    );
  }

  static MiniProgramFileTransferDirection _direction(Object? value) {
    return switch (value?.toString()) {
      'upload' => MiniProgramFileTransferDirection.upload,
      'download' => MiniProgramFileTransferDirection.download,
      _ => throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileInvalidResult,
        message: 'Android returned an invalid transfer direction.',
      ),
    };
  }

  static int _requiredInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.toInt();
    }
    throw const MiniProgramFileException(
      errorCode: MiniProgramErrorCodes.fileInvalidResult,
      message: 'Android returned an invalid file transfer number.',
    );
  }

  static int? _optionalInt(Object? value) =>
      value == null ? null : _requiredInt(value);

  static MiniProgramFileException _fileException(
    PlatformException error,
    String fallback,
  ) {
    const stable = <String>{
      MiniProgramErrorCodes.fileTransferUnavailable,
      MiniProgramErrorCodes.filePickerCancelled,
      MiniProgramErrorCodes.fileTypeNotAccepted,
      MiniProgramErrorCodes.fileTooLarge,
      MiniProgramErrorCodes.fileInsufficientStorage,
      MiniProgramErrorCodes.fileUploadFailed,
      MiniProgramErrorCodes.fileDownloadFailed,
      MiniProgramErrorCodes.fileTransferCancelled,
      MiniProgramErrorCodes.fileTransferLimitExceeded,
      MiniProgramErrorCodes.fileInvalidResult,
      MiniProgramErrorCodes.mediaNotFound,
      MiniProgramErrorCodes.mediaNotOwned,
    };
    final code = stable.contains(error.code) ? error.code : fallback;
    return MiniProgramFileException(
      errorCode: code,
      message: error.message ?? 'Android file transfer failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
