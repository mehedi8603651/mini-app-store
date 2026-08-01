import 'package:mini_program_ui/mini_program_ui.dart';

const driveFilesRequest = 'drive_files';

List<MpAction> initializeDrive() => <MpAction>[
  Mp.auth.restore(),
  Mp.state.setDefault('drive.transfer_status', 'idle'),
  Mp.state.setDefault('drive.transfer_progress', const <String, Object?>{
    'transferId': '',
    'bytesTransferred': 0,
    'status': 'idle',
  }),
  Mp.state.setDefault('drive.has_captured_photo', false),
  Mp.state.setDefault('drive.camera_status', 'idle'),
];

MpAction refreshDriveFiles() => Mp.backend.query(
  requestId: driveFilesRequest,
  endpoint: 'files',
  forceRefresh: true,
);

MpAction uploadDriveFiles() => Mp.action.sequence(<MpAction>[
  Mp.file.upload(
    endpoint: 'files/upload',
    mimeTypes: const <String>['*/*'],
    multiple: true,
    progressState: 'drive.transfer_progress',
    targetState: 'drive.upload_result',
    statusState: 'drive.transfer_status',
    errorState: 'drive.transfer_error',
    requestId: 'drive-upload',
  ),
  refreshDriveFiles(),
  Mp.toast(message: 'Upload complete'),
]);

MpAction captureDrivePhoto() => Mp.action.sequence(<MpAction>[
  Mp.camera.capturePhoto(
    maxWidth: 1600,
    maxHeight: 1600,
    quality: 85,
    targetState: 'drive.captured_photo',
    statusState: 'drive.camera_status',
    errorState: 'drive.camera_error',
    requestId: 'drive-capture-photo',
  ),
  Mp.state.set('drive.has_captured_photo', true),
]);

MpAction discardDrivePhoto() => Mp.action.sequence(<MpAction>[
  Mp.media.release(
    mediaRef: '{{state.drive.captured_photo.mediaRef}}',
    statusState: 'drive.camera_status',
    errorState: 'drive.camera_error',
    requestId: 'drive-discard-photo',
  ),
  Mp.state.patch(
    const <String, Object?>{'drive.has_captured_photo': false},
    remove: const <String>['drive.captured_photo'],
  ),
]);

MpAction retakeDrivePhoto() =>
    Mp.action.sequence(<MpAction>[discardDrivePhoto(), captureDrivePhoto()]);

MpAction uploadDrivePhoto() => Mp.action.sequence(<MpAction>[
  Mp.file.upload(
    endpoint: 'files/upload',
    mimeTypes: const <String>['image/jpeg'],
    mediaRefs: const <String>['{{state.drive.captured_photo.mediaRef}}'],
    progressState: 'drive.transfer_progress',
    targetState: 'drive.upload_result',
    statusState: 'drive.transfer_status',
    errorState: 'drive.transfer_error',
    requestId: 'drive-upload-photo',
  ),
  Mp.media.release(
    mediaRef: '{{state.drive.captured_photo.mediaRef}}',
    requestId: 'drive-release-uploaded-photo',
  ),
  Mp.state.patch(
    const <String, Object?>{'drive.has_captured_photo': false},
    remove: const <String>['drive.captured_photo', 'drive.camera_error'],
  ),
  refreshDriveFiles(),
  Mp.toast(message: 'Photo uploaded'),
]);

MpAction cancelDriveTransfer() => Mp.file.cancel(
  transferId: '{{state.drive.transfer_progress.transferId}}',
  statusState: 'drive.transfer_status',
  errorState: 'drive.transfer_error',
  requestId: 'drive-cancel-transfer',
);

MpAction downloadDriveFile() => Mp.action.sequence(<MpAction>[
  Mp.file.download(
    endpoint: 'files/download',
    request: const <String, Object?>{'fileId': '{{item.id}}'},
    destination: 'downloads',
    suggestedName: '{{item.name}}',
    progressState: 'drive.transfer_progress',
    targetState: 'drive.download_result',
    statusState: 'drive.transfer_status',
    errorState: 'drive.transfer_error',
    requestId: 'drive-download',
  ),
  Mp.toast(message: 'Saved to Downloads'),
]);

MpAction deleteDriveFile() => Mp.action.sequence(<MpAction>[
  Mp.backend.call(
    endpoint: 'files/delete',
    method: 'POST',
    body: const <String, Object?>{'fileId': '{{item.id}}'},
    requestId: 'drive-delete',
  ),
  refreshDriveFiles(),
  Mp.toast(message: 'File deleted'),
]);

MpAction openDriveRename() => Mp.router.push(
  'drive_rename',
  params: const <String, Object?>{
    'fileId': '{{item.id}}',
    'fileName': '{{item.name}}',
  },
  requestId: 'drive-open-rename',
);

List<MpAction> initializeDriveRename() => <MpAction>[
  Mp.state.patch(<String, Object?>{
    'drive.rename.file_id': '{{route.fileId}}',
    'drive.rename.file_name': '{{route.fileName}}',
  }),
];

MpAction saveDriveRename() => Mp.action.sequence(<MpAction>[
  Mp.backend.call(
    endpoint: 'files/rename',
    method: 'POST',
    body: const <String, Object?>{
      'fileId': '{{state.drive.rename.file_id}}',
      'fileName': '{{state.drive.rename.file_name}}',
    },
    requestId: 'drive-rename',
  ),
  refreshDriveFiles(),
  Mp.toast(message: 'File renamed'),
  Mp.router.pop(requestId: 'drive-close-rename'),
]);
