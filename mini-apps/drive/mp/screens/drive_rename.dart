import 'package:mini_program_ui/mini_program_ui.dart';

import '../drive_actions.dart';
import '../drive_theme.dart';

MpNode buildDriveRename() {
  return Mp.stateScope(
    prefix: 'drive.rename',
    clearOnDispose: true,
    child: Mp.initialize(
      actions: initializeDriveRename(),
      loading: driveLoading('Opening file'),
      error: driveErrorPanel(
        title: 'File could not be opened',
        message: '{{state.drive.rename_error.message}}',
      ),
      statusState: 'drive.rename_status',
      errorState: 'drive.rename_error',
      child: Mp.container(
        backgroundColor: driveBackground,
        child: Mp.safeArea(
          child: Mp.scrollView(
            paddingHorizontal: 16,
            paddingBottom: 28,
            child: Mp.center(
              child: Mp.container(
                width: 520,
                child: Mp.column(
                  children: <MpNode>[
                    _renameAppBar(),
                    Mp.sizedBox(height: 24),
                    Mp.container(
                      paddingHorizontal: 18,
                      paddingVertical: 22,
                      backgroundColor: driveSurface,
                      borderColor: driveBorder,
                      borderWidth: 1,
                      borderRadius: 8,
                      child: Mp.column(
                        children: <MpNode>[
                          Mp.text(
                            'Rename file',
                            color: driveText,
                            size: 20,
                            weight: 'semibold',
                          ),
                          Mp.sizedBox(height: 16),
                          Mp.stateTextField(
                            stateKey: 'drive.rename.file_name',
                            label: 'File name',
                            maxLength: 160,
                            autofocus: true,
                            textColor: driveText,
                            hintColor: driveMuted,
                            cursorColor: driveBlue,
                            backgroundColor: driveSurfaceStrong,
                            borderColor: driveBorder,
                            focusedBorderColor: driveBlue,
                            borderWidth: 1,
                            borderRadius: 6,
                            fontSize: 17,
                            paddingHorizontal: 12,
                            paddingVertical: 13,
                            onSubmitted: saveDriveRename(),
                          ),
                          Mp.sizedBox(height: 18),
                          Mp.button(
                            label: 'SAVE NAME',
                            action: saveDriveRename(),
                            height: 50,
                            backgroundColor: driveBlue,
                            foregroundColor: driveBackground,
                            borderColor: driveBlue,
                            borderRadius: 6,
                            fontSize: 15,
                            fontWeight: 'semibold',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

MpNode _renameAppBar() {
  return Mp.container(
    height: 70,
    paddingHorizontal: 10,
    backgroundColor: driveAppBar,
    child: Mp.row(
      children: <MpNode>[
        Mp.iconButton(
          'arrowBack',
          semanticLabel: 'Back to Drive',
          action: Mp.router.pop(requestId: 'drive-cancel-rename'),
          size: 48,
          iconSize: 27,
          color: driveText,
          backgroundColor: driveAppBar,
          borderRadius: 24,
        ),
        Mp.sizedBox(width: 8),
        Mp.expanded(
          child: Mp.text('Drive', color: driveText, size: 24, weight: 'bold'),
        ),
        Mp.button(
          label: 'SAVE',
          action: saveDriveRename(),
          height: 42,
          backgroundColor: driveAppBar,
          foregroundColor: driveBlue,
          borderColor: driveAppBar,
          borderRadius: 4,
          fontSize: 14,
          fontWeight: 'semibold',
        ),
      ],
    ),
  );
}
