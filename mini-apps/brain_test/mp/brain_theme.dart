import 'package:mini_program_ui/mini_program_ui.dart';

const brainBackground = '#FF10131A';
const brainSurface = '#FF1B202A';
const brainSurfaceStrong = '#FF242B36';
const brainText = '#FFF7F8FA';
const brainMuted = '#FFA8B0BE';
const brainYellow = '#FFFFD84A';
const brainYellowDark = '#FF3B3210';
const brainCyan = '#FF4CD7D0';
const brainCoral = '#FFFF6577';
const brainGreen = '#FF35C98A';
const brainRed = '#FFF05262';

MpNode brainScreenMessage(String message) {
  return Mp.container(
    backgroundColor: brainBackground,
    paddingAll: 24,
    child: Mp.center(
      child: Mp.text(message, color: brainMuted, size: 16, align: 'center'),
    ),
  );
}

MpNode brainHeader({
  required String title,
  required MpAction leadingAction,
  String leadingIcon = 'arrowBack',
  String leadingLabel = 'Go back',
  MpNode? trailing,
}) {
  return Mp.row(
    children: <MpNode>[
      Mp.iconButton(
        leadingIcon,
        semanticLabel: leadingLabel,
        action: leadingAction,
        size: 44,
        iconSize: 25,
        color: brainText,
        backgroundColor: brainSurface,
        borderColor: brainSurfaceStrong,
        borderWidth: 1,
        borderRadius: 8,
      ),
      Mp.sizedBox(width: 12),
      Mp.expanded(
        child: Mp.text(
          title,
          color: brainText,
          size: 22,
          weight: 'semibold',
          maxLines: 1,
          overflow: 'ellipsis',
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}
