import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/notepad_editor.dart';
import 'screens/notepad_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'notepad_home': buildNotepadHome,
    'notepad_editor': buildNotepadEditor,
  },
);
