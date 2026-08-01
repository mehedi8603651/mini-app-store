import 'package:mini_program_ui/mini_program_ui.dart';

const friendsBackground = '#FF0E1118';
const friendsSurface = '#FF171C26';
const friendsSurfaceStrong = '#FF202735';
const friendsBorder = '#FF303A4D';
const friendsText = '#FFF6F8FC';
const friendsMuted = '#FF9BA6B8';
const friendsBlue = '#FF57A6FF';
const friendsMint = '#FF38D6A5';
const friendsYellow = '#FFFFD166';
const friendsDanger = '#FFFF647C';

MpNode friendsLoading(String message) => Mp.container(
  paddingHorizontal: 24,
  paddingVertical: 72,
  backgroundColor: friendsSurface,
  borderColor: friendsBorder,
  borderWidth: 1,
  borderRadius: 8,
  child: Mp.column(
    children: <MpNode>[
      Mp.icon(
        'refresh',
        semanticLabel: 'Loading',
        size: 34,
        color: friendsBlue,
      ),
      Mp.sizedBox(height: 16),
      Mp.text(message, color: friendsMuted, size: 14, align: 'center'),
    ],
  ),
);

MpNode friendsError(String title, String message) => Mp.container(
  paddingHorizontal: 24,
  paddingVertical: 44,
  backgroundColor: friendsSurface,
  borderColor: friendsDanger,
  borderWidth: 1,
  borderRadius: 8,
  child: Mp.column(
    children: <MpNode>[
      Mp.icon('warning', semanticLabel: title, size: 38, color: friendsDanger),
      Mp.sizedBox(height: 14),
      Mp.text(
        title,
        color: friendsText,
        size: 19,
        weight: 'semibold',
        align: 'center',
      ),
      Mp.sizedBox(height: 8),
      Mp.text(
        message,
        color: friendsMuted,
        size: 13,
        align: 'center',
        maxLines: 5,
      ),
    ],
  ),
);

MpNode friendsHeader({
  required String title,
  required String subtitle,
  MpAction? backAction,
}) => Mp.row(
  children: <MpNode>[
    if (backAction != null) ...<MpNode>[
      Mp.iconButton(
        'arrowBack',
        semanticLabel: 'Back',
        action: backAction,
        size: 44,
        iconSize: 24,
        color: friendsText,
        backgroundColor: friendsSurfaceStrong,
        borderColor: friendsBorder,
        borderWidth: 1,
        borderRadius: 8,
      ),
      Mp.sizedBox(width: 12),
    ],
    Mp.expanded(
      child: Mp.column(
        children: <MpNode>[
          Mp.text(title, color: friendsText, size: 22, weight: 'bold'),
          Mp.sizedBox(height: 2),
          Mp.text(subtitle, color: friendsMuted, size: 11, weight: 'medium'),
        ],
      ),
    ),
  ],
);
