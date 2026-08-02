import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/media_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{'media_home': buildMediaHome},
);
