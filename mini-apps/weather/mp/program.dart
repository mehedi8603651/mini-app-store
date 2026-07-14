import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/weather_home.dart';
import 'screens/weather_search.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'weather_home': buildWeatherHome,
    'weather_search': buildWeatherSearch,
  },
);
