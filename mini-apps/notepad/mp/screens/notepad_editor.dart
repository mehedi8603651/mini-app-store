import 'package:mini_program_ui/mini_program_ui.dart';

import '../notepad_actions.dart';
import '../notepad_theme.dart';

MpNode buildNotepadEditor() {
  return Mp.stateScope(
    prefix: 'notepad.editor',
    clearOnDispose: true,
    child: Mp.initialize(
      actions: initializeNoteEditor(),
      loading: notepadLoading('Opening note'),
      error: notepadLoading('Note could not be opened'),
      statusState: 'notepad.editor.status',
      errorState: 'notepad.editor.error',
      child: Mp.container(
        backgroundColor: notepadBackground,
        child: Mp.safeArea(
          child: Mp.scrollView(
            paddingBottom: 24,
            child: Mp.center(
              child: Mp.container(
                width: 520,
                child: Mp.column(
                  children: <MpNode>[
                    _editorHeader(),
                    Mp.sizedBox(height: 8),
                    _editorFields(),
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

MpNode _editorHeader() {
  return Mp.container(
    height: 72,
    paddingHorizontal: 10,
    backgroundColor: notepadAppBar,
    child: Mp.row(
      children: <MpNode>[
        Mp.iconButton(
          'arrowBack',
          semanticLabel: 'Back to notes',
          action: Mp.router.pop(requestId: 'notepad-cancel-editor'),
          size: 48,
          iconSize: 29,
          color: notepadText,
          backgroundColor: notepadAppBar,
          borderRadius: 24,
        ),
        Mp.sizedBox(width: 6),
        Mp.expanded(
          child: Mp.text(
            'Notepad',
            color: notepadText,
            size: 25,
            weight: 'medium',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
        ),
        Mp.stateBuilder(
          keys: const <String>['notepad.editor.existing'],
          child: Mp.condition(
            condition: '{{state.notepad.editor.existing}}',
            whenTrue: Mp.iconButton(
              'close',
              semanticLabel: 'Delete note',
              action: deleteNote(),
              size: 46,
              iconSize: 24,
              color: notepadDanger,
              backgroundColor: notepadAppBar,
              borderRadius: 23,
            ),
            whenFalse: Mp.sizedBox(width: 1, height: 1),
          ),
        ),
        Mp.sizedBox(width: 6),
        Mp.button(
          label: 'SAVE',
          action: saveNote(),
          height: 44,
          backgroundColor: notepadAppBar,
          foregroundColor: notepadText,
          borderColor: notepadAppBar,
          borderRadius: 4,
          fontSize: 16,
          fontWeight: 'medium',
        ),
      ],
    ),
  );
}

MpNode _editorFields() {
  return Mp.container(
    paddingHorizontal: 8,
    paddingVertical: 8,
    backgroundColor: notepadBackground,
    child: Mp.column(
      children: <MpNode>[
        Mp.stateTextField(
          stateKey: 'notepad.editor.title',
          hint: 'Enter title...',
          maxLength: 120,
          minLines: 1,
          maxLines: 1,
          textInputAction: 'next',
          autofocus: true,
          textColor: notepadText,
          hintColor: notepadMuted,
          cursorColor: notepadAccent,
          backgroundColor: notepadSurface,
          borderColor: notepadBorder,
          focusedBorderColor: notepadAccent,
          borderWidth: 1,
          borderRadius: 5,
          fontSize: 22,
          paddingHorizontal: 12,
          paddingVertical: 12,
        ),
        Mp.stateTextField(
          stateKey: 'notepad.editor.body',
          hint: 'Enter text...',
          maxLength: 4096,
          minLines: 14,
          maxLines: 30,
          keyboardType: 'multiline',
          textInputAction: 'newline',
          textColor: notepadText,
          hintColor: notepadMuted,
          cursorColor: notepadAccent,
          backgroundColor: notepadSurface,
          borderColor: notepadBorder,
          focusedBorderColor: notepadAccent,
          borderWidth: 1,
          borderRadius: 5,
          fontSize: 18,
          paddingHorizontal: 12,
          paddingVertical: 14,
        ),
      ],
    ),
  );
}
