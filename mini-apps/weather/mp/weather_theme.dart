import 'package:mini_program_ui/mini_program_ui.dart';

const weatherBackground = '#FF0B1020';
const weatherSurface = '#FF171D2D';
const weatherSurfaceStrong = '#FF222A3C';
const weatherText = '#FFF7F9FC';
const weatherMuted = '#FFAAB3C5';
const weatherYellow = '#FFFFD34E';
const weatherCyan = '#FF44D5D1';
const weatherBlue = '#FF548BFF';
const weatherCoral = '#FFFF6B72';
const weatherGreen = '#FF4BD39A';

MpNode weatherMessage(String message, {String color = weatherMuted}) {
  return Mp.container(
    backgroundColor: weatherBackground,
    paddingAll: 24,
    child: Mp.center(
      child: Mp.text(message, color: color, size: 16, align: 'center'),
    ),
  );
}

MpNode weatherSectionTitle(String title, {String? trailing}) {
  return Mp.row(
    children: <MpNode>[
      Mp.expanded(
        child: Mp.text(title, color: weatherText, size: 18, weight: 'semibold'),
      ),
      if (trailing != null) Mp.text(trailing, color: weatherMuted, size: 12),
    ],
  );
}
