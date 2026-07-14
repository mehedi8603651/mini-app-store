import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) async {
  await writeMpBuildOutput(miniProgram, arguments: arguments);
}
