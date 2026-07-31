import 'package:mini_program_ui/mini_program_ui.dart';

const driveBackground = '#FF0B1017';
const driveAppBar = '#FF121A24';
const driveSurface = '#FF172230';
const driveSurfaceStrong = '#FF203044';
const driveBorder = '#FF2B3C50';
const driveText = '#FFF5F7FA';
const driveMuted = '#FFA9B5C4';
const driveBlue = '#FF4EA1FF';
const driveGreen = '#FF43C59E';
const driveDanger = '#FFFF647C';
const driveWarning = '#FFFFC857';

MpNode driveLoading(String label) => Mp.container(
  paddingHorizontal: 28,
  paddingVertical: 80,
  backgroundColor: driveBackground,
  child: Mp.column(
    children: <MpNode>[
      Mp.progress(value: 0.5, tone: 'info'),
      Mp.sizedBox(height: 18),
      Mp.text(label, color: driveMuted, size: 15, align: 'center'),
    ],
  ),
);

MpNode driveErrorPanel({required String title, required String message}) {
  return Mp.container(
    paddingHorizontal: 22,
    paddingVertical: 28,
    backgroundColor: driveSurface,
    borderColor: driveBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon('warning', semanticLabel: title, color: driveDanger, size: 38),
        Mp.sizedBox(height: 14),
        Mp.text(
          title,
          color: driveText,
          size: 20,
          weight: 'semibold',
          align: 'center',
        ),
        Mp.sizedBox(height: 8),
        Mp.text(
          message,
          color: driveMuted,
          size: 14,
          align: 'center',
          maxLines: 4,
          overflow: 'ellipsis',
        ),
      ],
    ),
  );
}
