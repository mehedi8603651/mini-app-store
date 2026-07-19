import 'package:mini_program_ui/mini_program_ui.dart';

import '../notepad_actions.dart';
import '../notepad_theme.dart';

MpNode buildNotepadHome() {
  return Mp.initialize(
    actions: initializeNotepad(),
    loading: notepadLoading('Loading notes'),
    error: notepadLoading('Notes could not be loaded'),
    statusState: 'notepad.status',
    errorState: 'notepad.startup_error',
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
                  _homeHeader(),
                  Mp.sizedBox(height: 10),
                  Mp.stateBuilder(
                    keys: const <String>['notepad.notes'],
                    child: Mp.repeat(
                      source: '{{state.notepad.notes}}',
                      limit: 50,
                      spacing: 6,
                      empty: _emptyNotes(),
                      itemTemplate: _noteCard(),
                    ),
                  ),
                  Mp.sizedBox(height: 28),
                  Mp.align(
                    alignment: 'centerRight',
                    child: Mp.iconButton(
                      'add',
                      semanticLabel: 'Create a new note',
                      action: createNote(),
                      size: 68,
                      iconSize: 34,
                      color: notepadText,
                      backgroundColor: notepadAccent,
                      borderColor: notepadAccent,
                      borderRadius: 34,
                    ),
                  ),
                  Mp.sizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

MpNode _homeHeader() {
  return Mp.container(
    height: 72,
    paddingHorizontal: 18,
    backgroundColor: notepadAppBar,
    child: Mp.row(
      children: <MpNode>[
        Mp.icon('note', semanticLabel: 'Notepad', size: 28, color: notepadText),
        Mp.sizedBox(width: 14),
        Mp.expanded(
          child: Mp.text(
            'Notepad',
            color: notepadText,
            size: 27,
            weight: 'medium',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
        ),
        Mp.iconButton(
          'add',
          semanticLabel: 'Create note',
          action: createNote(),
          size: 46,
          iconSize: 26,
          color: notepadText,
          backgroundColor: notepadAppBar,
          borderRadius: 23,
        ),
      ],
    ),
  );
}

MpNode _noteCard() {
  return Mp.tap(
    semanticLabel: 'Open {{item.title}}',
    action: openNote(),
    child: Mp.container(
      paddingHorizontal: 18,
      paddingVertical: 15,
      backgroundColor: notepadSurface,
      borderColor: notepadBorder,
      borderWidth: 1,
      borderRadius: 6,
      child: Mp.column(
        children: <MpNode>[
          Mp.text(
            '{{item.title}}',
            color: notepadText,
            size: 20,
            weight: 'medium',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
          Mp.sizedBox(height: 7),
          Mp.text(
            '{{item.body}}',
            color: notepadMuted,
            size: 14,
            maxLines: 2,
            overflow: 'ellipsis',
          ),
          Mp.sizedBox(height: 9),
          Mp.text(
            'Saved on this device',
            color: notepadMuted,
            size: 12,
            align: 'end',
          ),
        ],
      ),
    ),
  );
}

MpNode _emptyNotes() {
  return Mp.container(
    paddingHorizontal: 28,
    paddingTop: 110,
    paddingBottom: 90,
    backgroundColor: notepadBackground,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon(
          'note',
          semanticLabel: 'No notes',
          size: 44,
          color: notepadMuted,
        ),
        Mp.sizedBox(height: 18),
        Mp.text(
          'No notes yet',
          color: notepadText,
          size: 24,
          weight: 'medium',
          align: 'center',
        ),
        Mp.sizedBox(height: 10),
        Mp.text(
          'Tap the plus button to create your first note.',
          color: notepadMuted,
          size: 16,
          align: 'center',
          maxLines: 2,
        ),
      ],
    ),
  );
}
