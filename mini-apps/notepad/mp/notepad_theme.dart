import 'package:mini_program_ui/mini_program_ui.dart';

const notepadBackground = '#FF000000';
const notepadAppBar = '#FF303030';
const notepadSurface = '#FF121212';
const notepadBorder = '#FF4A4A4A';
const notepadText = '#FFF0F0F0';
const notepadMuted = '#FFAAAAAA';
const notepadAccent = '#FF8EAD7C';
const notepadDanger = '#FFE57373';

MpNode notepadLoading(String message) {
  return Mp.container(
    backgroundColor: notepadBackground,
    paddingAll: 28,
    child: Mp.center(
      child: Mp.text(message, color: notepadMuted, size: 16, align: 'center'),
    ),
  );
}
