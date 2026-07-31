import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/drive_home.dart';
import 'screens/drive_rename.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'drive_home': buildDriveHome,
    'drive_rename': buildDriveRename,
  },
);
