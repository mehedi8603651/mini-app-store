import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/flashlight_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{'flashlight_home': buildFlashlightHome},
);
