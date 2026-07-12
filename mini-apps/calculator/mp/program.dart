import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/calculator_home.dart';
import 'screens/calculator_history.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'calculator_home': buildCalculatorHome,
    'calculator_history': buildCalculatorHistory,
  },
);
