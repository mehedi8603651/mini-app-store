import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/brain_test_game.dart';
import 'screens/brain_test_history.dart';
import 'screens/brain_test_home.dart';
import 'screens/brain_test_result.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'brain_test_home': buildBrainTestHome,
    'brain_test_game': buildBrainTestGame,
    'brain_test_result': buildBrainTestResult,
    'brain_test_history': buildBrainTestHistory,
  },
);
