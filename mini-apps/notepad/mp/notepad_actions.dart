import 'package:mini_program_ui/mini_program_ui.dart';

const _notesCacheKey = 'notepad_notes';

List<MpAction> initializeNotepad() {
  return <MpAction>[
    Mp.cache.state.get(
      _notesCacheKey,
      targetState: 'notepad.notes',
      skipMissing: true,
      requestId: 'notepad-load-notes',
    ),
    Mp.state.setDefault('notepad.notes', const <Object?>[]),
  ];
}

MpAction createNote() {
  return Mp.router.push(
    'notepad_editor',
    params: const <String, Object?>{
      'index': -1,
      'existing': false,
      'title': 'Untitled',
      'body': '',
    },
    requestId: 'notepad-create-note',
  );
}

MpAction openNote() {
  return Mp.router.push(
    'notepad_editor',
    params: const <String, Object?>{
      'index': '{{index}}',
      'existing': true,
      'title': '{{item.title}}',
      'body': '{{item.body}}',
    },
    requestId: 'notepad-open-note',
  );
}

List<MpAction> initializeNoteEditor() {
  return <MpAction>[
    Mp.state.patch(<String, Object?>{
      'notepad.editor.index': '{{route.index}}',
      'notepad.editor.existing': '{{route.existing}}',
      'notepad.editor.title': '{{route.title}}',
      'notepad.editor.body': '{{route.body}}',
    }),
  ];
}

MpAction saveNote() {
  final note = <String, Object?>{
    'title': '{{state.notepad.editor.title}}',
    'body': '{{state.notepad.editor.body}}',
  };
  return Mp.action.ifElse(
    condition: '{{state.notepad.editor.existing}}',
    thenAction: Mp.action.sequence(<MpAction>[
      Mp.state.listRemoveAt('notepad.notes', '{{state.notepad.editor.index}}'),
      Mp.state.listInsert(
        'notepad.notes',
        '{{state.notepad.editor.index}}',
        note,
      ),
      _persistNotes('notepad-save-existing'),
      Mp.toast(message: 'Saved'),
      Mp.router.pop(requestId: 'notepad-close-saved-note'),
    ]),
    elseAction: Mp.action.sequence(<MpAction>[
      Mp.state.listPrepend('notepad.notes', note, maxItems: 50),
      _persistNotes('notepad-save-new'),
      Mp.toast(message: 'Saved'),
      Mp.router.pop(requestId: 'notepad-close-new-note'),
    ]),
  );
}

MpAction deleteNote() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.listRemoveAt('notepad.notes', '{{state.notepad.editor.index}}'),
    _persistNotes('notepad-delete-note'),
    Mp.toast(message: 'Note deleted'),
    Mp.router.pop(requestId: 'notepad-close-deleted-note'),
  ]);
}

MpAction _persistNotes(String requestId) {
  return Mp.cache.state.set(
    _notesCacheKey,
    '{{state.notepad.notes}}',
    requestId: requestId,
  );
}
