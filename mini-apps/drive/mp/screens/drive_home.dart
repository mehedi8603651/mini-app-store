import 'package:mini_program_ui/mini_program_ui.dart';

import '../drive_actions.dart';
import '../drive_theme.dart';

MpNode buildDriveHome() {
  return Mp.initialize(
    actions: initializeDrive(),
    loading: driveLoading('Opening Drive'),
    error: driveErrorPanel(
      title: 'Drive could not start',
      message: '{{state.drive.startup_error.message}}',
    ),
    statusState: 'drive.startup_status',
    errorState: 'drive.startup_error',
    child: Mp.container(
      backgroundColor: driveBackground,
      child: Mp.safeArea(
        child: Mp.authBuilder(
          loading: driveLoading('Restoring secure session'),
          signedOut: _signedOut(),
          error: _signedOut(error: true),
          signedIn: _signedIn(),
        ),
      ),
    ),
  );
}

MpNode _signedOut({bool error = false}) {
  return Mp.scrollView(
    paddingHorizontal: 20,
    paddingBottom: 28,
    child: Mp.center(
      child: Mp.container(
        width: 520,
        child: Mp.column(
          children: <MpNode>[
            _appBar(signedIn: false),
            Mp.sizedBox(height: 64),
            Mp.container(
              paddingHorizontal: 26,
              paddingVertical: 34,
              backgroundColor: driveSurface,
              borderColor: driveBorder,
              borderWidth: 1,
              borderRadius: 8,
              child: Mp.column(
                children: <MpNode>[
                  Mp.icon(
                    'lock',
                    semanticLabel: 'Secure Drive account',
                    size: 50,
                    color: driveBlue,
                  ),
                  Mp.sizedBox(height: 18),
                  Mp.text(
                    'Your Drive',
                    color: driveText,
                    size: 28,
                    weight: 'bold',
                    align: 'center',
                  ),
                  Mp.sizedBox(height: 10),
                  Mp.text(
                    error
                        ? '{{auth.message}}'
                        : 'Sign in to access files stored in your private test workspace.',
                    color: error ? driveDanger : driveMuted,
                    size: 15,
                    align: 'center',
                    maxLines: 4,
                  ),
                  Mp.sizedBox(height: 26),
                  Mp.button(
                    label: 'SIGN IN',
                    action: Mp.auth.showEmailAuth(mode: 'signIn'),
                    height: 50,
                    backgroundColor: driveBlue,
                    foregroundColor: driveBackground,
                    borderColor: driveBlue,
                    borderRadius: 6,
                    fontSize: 16,
                    fontWeight: 'semibold',
                  ),
                  Mp.sizedBox(height: 10),
                  Mp.button(
                    label: 'CREATE TEST ACCOUNT',
                    action: Mp.auth.showEmailAuth(mode: 'signUp'),
                    height: 50,
                    backgroundColor: driveSurface,
                    foregroundColor: driveText,
                    borderColor: driveBorder,
                    borderWidth: 1,
                    borderRadius: 6,
                    fontSize: 14,
                    fontWeight: 'medium',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

MpNode _signedIn() {
  return Mp.scrollView(
    paddingHorizontal: 14,
    paddingBottom: 28,
    child: Mp.center(
      child: Mp.container(
        width: 620,
        child: Mp.column(
          children: <MpNode>[
            _appBar(signedIn: true),
            Mp.sizedBox(height: 14),
            _accountBand(),
            Mp.sizedBox(height: 12),
            _cameraBand(),
            Mp.sizedBox(height: 12),
            _transferBand(),
            Mp.sizedBox(height: 12),
            _filesBuilder(),
          ],
        ),
      ),
    ),
  );
}

MpNode _cameraBand() {
  return Mp.stateBuilder(
    keys: const <String>[
      'drive.has_captured_photo',
      'drive.captured_photo',
      'drive.camera_status',
      'drive.camera_error',
    ],
    child: Mp.condition(
      condition: '{{state.drive.has_captured_photo}}',
      whenFalse: Mp.container(
        paddingHorizontal: 16,
        paddingVertical: 14,
        backgroundColor: driveSurface,
        borderColor: driveBorder,
        borderWidth: 1,
        borderRadius: 8,
        child: Mp.row(
          children: <MpNode>[
            Mp.icon(
              'note',
              semanticLabel: 'Camera upload',
              size: 28,
              color: driveGreen,
            ),
            Mp.sizedBox(width: 12),
            Mp.expanded(
              child: Mp.column(
                children: <MpNode>[
                  Mp.text(
                    'Upload a new photo',
                    color: driveText,
                    size: 15,
                    weight: 'semibold',
                  ),
                  Mp.sizedBox(height: 3),
                  Mp.text(
                    '{{state.drive.camera_error.message}}',
                    color: driveDanger,
                    size: 11,
                    maxLines: 2,
                    overflow: 'ellipsis',
                  ),
                ],
              ),
            ),
            Mp.button(
              label: 'TAKE PHOTO',
              action: captureDrivePhoto(),
              height: 44,
              backgroundColor: driveGreen,
              foregroundColor: driveBackground,
              borderColor: driveGreen,
              borderRadius: 6,
              fontSize: 12,
              fontWeight: 'semibold',
            ),
          ],
        ),
      ),
      whenTrue: Mp.container(
        paddingHorizontal: 14,
        paddingVertical: 14,
        backgroundColor: driveSurface,
        borderColor: driveGreen,
        borderWidth: 1,
        borderRadius: 8,
        child: Mp.column(
          children: <MpNode>[
            Mp.image(
              src: '{{state.drive.captured_photo.mediaRef}}',
              source: MpImageSource.hostMedia,
              height: 230,
              width: 590,
              fit: MpImageFit.contain,
              alt: 'Captured photo ready to upload',
              placeholder: driveLoading('Preparing photo preview'),
              error: driveErrorPanel(
                title: 'Preview unavailable',
                message: 'Discard this photo and capture it again.',
              ),
            ),
            Mp.sizedBox(height: 12),
            Mp.text(
              '{{state.drive.captured_photo.fileName}}',
              color: driveText,
              size: 14,
              weight: 'medium',
              maxLines: 1,
              overflow: 'ellipsis',
            ),
            Mp.sizedBox(height: 12),
            Mp.row(
              children: <MpNode>[
                Mp.expanded(
                  child: Mp.button(
                    label: 'DISCARD',
                    action: discardDrivePhoto(),
                    height: 42,
                    backgroundColor: driveSurfaceStrong,
                    foregroundColor: driveDanger,
                    borderColor: driveBorder,
                    borderWidth: 1,
                    borderRadius: 6,
                    fontSize: 11,
                  ),
                ),
                Mp.sizedBox(width: 8),
                Mp.expanded(
                  child: Mp.button(
                    label: 'RETAKE',
                    action: retakeDrivePhoto(),
                    height: 42,
                    backgroundColor: driveSurfaceStrong,
                    foregroundColor: driveText,
                    borderColor: driveBorder,
                    borderWidth: 1,
                    borderRadius: 6,
                    fontSize: 11,
                  ),
                ),
                Mp.sizedBox(width: 8),
                Mp.expanded(
                  child: Mp.button(
                    label: 'UPLOAD',
                    action: uploadDrivePhoto(),
                    height: 42,
                    backgroundColor: driveBlue,
                    foregroundColor: driveBackground,
                    borderColor: driveBlue,
                    borderRadius: 6,
                    fontSize: 11,
                    fontWeight: 'semibold',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

MpNode _appBar({required bool signedIn}) {
  return Mp.container(
    height: 70,
    paddingHorizontal: 16,
    backgroundColor: driveAppBar,
    child: Mp.row(
      children: <MpNode>[
        Mp.icon('note', semanticLabel: 'Drive', size: 28, color: driveBlue),
        Mp.sizedBox(width: 12),
        Mp.expanded(
          child: Mp.text(
            'Drive',
            color: driveText,
            size: 26,
            weight: 'bold',
            maxLines: 1,
          ),
        ),
        if (signedIn)
          Mp.iconButton(
            'refresh',
            semanticLabel: 'Refresh files',
            action: refreshDriveFiles(),
            size: 44,
            iconSize: 23,
            color: driveBlue,
            backgroundColor: driveAppBar,
            borderRadius: 22,
          ),
        if (signedIn) Mp.sizedBox(width: 6),
        if (signedIn)
          Mp.button(
            label: 'SIGN OUT',
            action: Mp.auth.signOut(),
            height: 42,
            backgroundColor: driveAppBar,
            foregroundColor: driveMuted,
            borderColor: driveBorder,
            borderWidth: 1,
            borderRadius: 6,
            fontSize: 12,
          ),
      ],
    ),
  );
}

MpNode _accountBand() {
  return Mp.container(
    paddingHorizontal: 16,
    paddingVertical: 14,
    backgroundColor: driveSurface,
    borderColor: driveBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.row(
      children: <MpNode>[
        Mp.icon(
          'person',
          semanticLabel: 'Signed in account',
          size: 26,
          color: driveGreen,
        ),
        Mp.sizedBox(width: 12),
        Mp.expanded(
          child: Mp.column(
            children: <MpNode>[
              Mp.text(
                '{{auth.user.email}}',
                color: driveText,
                size: 15,
                weight: 'medium',
                maxLines: 1,
                overflow: 'ellipsis',
              ),
              Mp.sizedBox(height: 3),
              Mp.text(
                'Private AWS test workspace',
                color: driveMuted,
                size: 12,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Mp.button(
          label: 'UPLOAD',
          action: uploadDriveFiles(),
          height: 44,
          backgroundColor: driveBlue,
          foregroundColor: driveBackground,
          borderColor: driveBlue,
          borderRadius: 6,
          fontSize: 13,
          fontWeight: 'semibold',
        ),
      ],
    ),
  );
}

MpNode _transferBand() {
  return Mp.stateBuilder(
    keys: const <String>[
      'drive.transfer_status',
      'drive.transfer_progress',
      'drive.transfer_error',
    ],
    child: Mp.container(
      paddingHorizontal: 16,
      paddingVertical: 12,
      backgroundColor: driveSurfaceStrong,
      borderColor: driveBorder,
      borderWidth: 1,
      borderRadius: 8,
      child: Mp.row(
        children: <MpNode>[
          Mp.expanded(
            child: Mp.column(
              children: <MpNode>[
                Mp.text(
                  'Transfer: {{state.drive.transfer_status}}',
                  color: driveText,
                  size: 13,
                  weight: 'medium',
                  maxLines: 1,
                ),
                Mp.sizedBox(height: 3),
                Mp.text(
                  '{{state.drive.transfer_progress.bytesTransferred}} bytes',
                  color: driveMuted,
                  size: 12,
                  maxLines: 1,
                ),
                Mp.text(
                  '{{state.drive.transfer_error.message}}',
                  color: driveDanger,
                  size: 11,
                  maxLines: 2,
                  overflow: 'ellipsis',
                ),
              ],
            ),
          ),
          Mp.button(
            label: 'CANCEL',
            action: cancelDriveTransfer(),
            height: 38,
            backgroundColor: driveSurfaceStrong,
            foregroundColor: driveWarning,
            borderColor: driveBorder,
            borderWidth: 1,
            borderRadius: 6,
            fontSize: 11,
          ),
        ],
      ),
    ),
  );
}

MpNode _filesBuilder() {
  return Mp.backendBuilder(
    requestId: driveFilesRequest,
    endpoint: 'files',
    loading: driveLoading('Loading files'),
    error: driveErrorPanel(
      title: 'Files unavailable',
      message: '{{backend.drive_files.message}}',
    ),
    empty: _emptyFiles(),
    child: Mp.column(
      children: <MpNode>[
        _usageBand(),
        Mp.sizedBox(height: 12),
        Mp.repeat(
          source: '{{backend.drive_files.data.items}}',
          spacing: 8,
          limit: 100,
          empty: _emptyFiles(),
          itemTemplate: _fileRow(),
        ),
      ],
    ),
  );
}

MpNode _usageBand() {
  return Mp.container(
    paddingHorizontal: 16,
    paddingVertical: 14,
    backgroundColor: driveSurface,
    borderColor: driveBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.row(
          children: <MpNode>[
            Mp.expanded(
              child: Mp.text(
                '{{backend.drive_files.data.count}} files',
                color: driveText,
                size: 14,
                weight: 'semibold',
              ),
            ),
            Mp.text(
              '{{backend.drive_files.data.usage.remainingBytes}} bytes free',
              color: driveMuted,
              size: 12,
              align: 'end',
            ),
          ],
        ),
      ],
    ),
  );
}

MpNode _fileRow() {
  return Mp.container(
    paddingHorizontal: 14,
    paddingVertical: 14,
    backgroundColor: driveSurface,
    borderColor: driveBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.row(
          children: <MpNode>[
            Mp.container(
              width: 46,
              height: 46,
              backgroundColor: driveSurfaceStrong,
              borderColor: driveBorder,
              borderWidth: 1,
              borderRadius: 7,
              child: Mp.center(
                child: Mp.icon(
                  'note',
                  semanticLabel: 'File',
                  size: 24,
                  color: driveBlue,
                ),
              ),
            ),
            Mp.sizedBox(width: 12),
            Mp.expanded(
              child: Mp.column(
                children: <MpNode>[
                  Mp.text(
                    '{{item.name}}',
                    color: driveText,
                    size: 16,
                    weight: 'medium',
                    maxLines: 1,
                    overflow: 'ellipsis',
                  ),
                  Mp.sizedBox(height: 4),
                  Mp.text(
                    '{{item.sizeLabel}}  |  {{item.mimeType}}',
                    color: driveMuted,
                    size: 11,
                    maxLines: 1,
                    overflow: 'ellipsis',
                  ),
                ],
              ),
            ),
            Mp.iconButton(
              'delete',
              semanticLabel: 'Delete {{item.name}}',
              action: deleteDriveFile(),
              size: 42,
              iconSize: 21,
              color: driveDanger,
              backgroundColor: driveSurface,
              borderRadius: 21,
            ),
          ],
        ),
        Mp.sizedBox(height: 10),
        Mp.row(
          children: <MpNode>[
            Mp.expanded(
              child: Mp.button(
                label: 'DOWNLOAD',
                action: downloadDriveFile(),
                height: 40,
                backgroundColor: driveSurfaceStrong,
                foregroundColor: driveBlue,
                borderColor: driveBorder,
                borderWidth: 1,
                borderRadius: 6,
                fontSize: 12,
              ),
            ),
            Mp.sizedBox(width: 8),
            Mp.expanded(
              child: Mp.button(
                label: 'RENAME',
                action: openDriveRename(),
                height: 40,
                backgroundColor: driveSurfaceStrong,
                foregroundColor: driveText,
                borderColor: driveBorder,
                borderWidth: 1,
                borderRadius: 6,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

MpNode _emptyFiles() {
  return Mp.container(
    paddingHorizontal: 28,
    paddingVertical: 72,
    backgroundColor: driveSurface,
    borderColor: driveBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon('note', semanticLabel: 'No files', size: 48, color: driveMuted),
        Mp.sizedBox(height: 16),
        Mp.text(
          'No files yet',
          color: driveText,
          size: 22,
          weight: 'semibold',
          align: 'center',
        ),
        Mp.sizedBox(height: 8),
        Mp.text(
          'Upload a file to this account.',
          color: driveMuted,
          size: 14,
          align: 'center',
        ),
        Mp.sizedBox(height: 20),
        Mp.button(
          label: 'UPLOAD FILE',
          action: uploadDriveFiles(),
          height: 48,
          backgroundColor: driveBlue,
          foregroundColor: driveBackground,
          borderColor: driveBlue,
          borderRadius: 6,
          fontSize: 14,
          fontWeight: 'semibold',
        ),
      ],
    ),
  );
}
