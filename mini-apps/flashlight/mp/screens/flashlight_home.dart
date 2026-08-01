import 'package:mini_program_ui/mini_program_ui.dart';

import '../flashlight_actions.dart';
import '../flashlight_theme.dart';

MpNode buildFlashlightHome() {
  return Mp.initialize(
    actions: initializeFlashlight(),
    loading: _screenMessage(
      icon: 'bolt',
      title: 'Checking flashlight',
      color: flashlightYellow,
    ),
    error: _screenMessage(
      icon: 'warning',
      title: 'Flashlight unavailable',
      message: '{{state.flashlight.error.message}}',
      color: flashlightDanger,
    ),
    statusState: 'flashlight.initialization_status',
    errorState: flashlightErrorState,
    retry: 1,
    child: Mp.container(
      backgroundColor: flashlightBackground,
      child: Mp.safeArea(
        child: Mp.scrollView(
          paddingHorizontal: 22,
          paddingTop: 18,
          paddingBottom: 32,
          child: Mp.center(
            child: Mp.container(
              width: 480,
              child: Mp.column(
                children: <MpNode>[
                  _header(),
                  Mp.sizedBox(height: 46),
                  Mp.stateBuilder(
                    keys: const <String>[
                      flashlightDeviceState,
                      flashlightOperationStatus,
                      flashlightErrorState,
                    ],
                    child: Mp.condition(
                      condition: '{{state.flashlight.device.available}}',
                      whenTrue: Mp.condition(
                        condition: '{{state.flashlight.device.enabled}}',
                        whenTrue: _torchPanel(enabled: true),
                        whenFalse: _torchPanel(enabled: false),
                      ),
                      whenFalse: _unavailablePanel(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

MpNode _header() {
  return Mp.row(
    children: <MpNode>[
      Mp.container(
        width: 44,
        height: 44,
        backgroundColor: flashlightSurfaceStrong,
        borderColor: flashlightBorder,
        borderWidth: 1,
        borderRadius: 8,
        child: Mp.center(
          child: Mp.icon(
            'bolt',
            semanticLabel: 'Flashlight',
            size: 27,
            color: flashlightYellow,
          ),
        ),
      ),
      Mp.sizedBox(width: 12),
      Mp.expanded(
        child: Mp.column(
          children: <MpNode>[
            Mp.text(
              'FLASHLIGHT',
              color: flashlightText,
              size: 21,
              weight: 'bold',
            ),
            Mp.sizedBox(height: 2),
            Mp.text(
              'DEVICE TORCH',
              color: flashlightMuted,
              size: 11,
              weight: 'medium',
            ),
          ],
        ),
      ),
      Mp.iconButton(
        'refresh',
        semanticLabel: 'Refresh flashlight status',
        action: refreshFlashlightStatus(),
        size: 44,
        iconSize: 23,
        color: flashlightText,
        backgroundColor: flashlightSurfaceStrong,
        borderColor: flashlightBorder,
        borderWidth: 1,
        borderRadius: 8,
      ),
    ],
  );
}

MpNode _torchPanel({required bool enabled}) {
  final accent = enabled ? flashlightYellow : flashlightOff;
  final halo = enabled ? flashlightYellowSoft : flashlightSurfaceStrong;
  final status = enabled ? 'LIGHT IS ON' : 'LIGHT IS OFF';
  final command = enabled ? 'TURN OFF' : 'TURN ON';

  return Mp.column(
    children: <MpNode>[
      Mp.container(
        width: 230,
        height: 230,
        backgroundColor: halo,
        borderColor: accent,
        borderWidth: enabled ? 4 : 2,
        borderRadius: 115,
        child: Mp.center(
          child: Mp.icon(
            'bolt',
            semanticLabel: status,
            size: 112,
            color: enabled ? flashlightBackground : flashlightOff,
          ),
        ),
      ),
      Mp.sizedBox(height: 34),
      Mp.text(status, color: accent, size: 18, weight: 'bold', align: 'center'),
      Mp.sizedBox(height: 8),
      Mp.text(
        enabled ? 'ACTIVE' : 'READY',
        color: flashlightMuted,
        size: 12,
        weight: 'medium',
        align: 'center',
      ),
      Mp.sizedBox(height: 34),
      Mp.button(
        label: command,
        action: toggleFlashlight(),
        height: 62,
        backgroundColor: enabled ? flashlightSurfaceStrong : flashlightYellow,
        foregroundColor: enabled ? flashlightYellow : flashlightBackground,
        borderColor: flashlightYellow,
        borderWidth: enabled ? 2 : 0,
        borderRadius: 8,
        fontSize: 18,
        fontWeight: 'bold',
      ),
      Mp.sizedBox(height: 18),
      Mp.container(
        paddingHorizontal: 16,
        paddingVertical: 13,
        backgroundColor: flashlightSurface,
        borderColor: flashlightBorder,
        borderWidth: 1,
        borderRadius: 8,
        child: Mp.row(
          children: <MpNode>[
            Mp.icon(
              'info',
              semanticLabel: 'Operation status',
              size: 19,
              color: flashlightMuted,
            ),
            Mp.sizedBox(width: 10),
            Mp.expanded(
              child: Mp.text(
                '{{state.flashlight.error.message}}',
                color: flashlightDanger,
                size: 12,
                maxLines: 3,
                overflow: 'ellipsis',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

MpNode _unavailablePanel() {
  return Mp.container(
    paddingHorizontal: 24,
    paddingVertical: 42,
    backgroundColor: flashlightSurface,
    borderColor: flashlightBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon(
          'warning',
          semanticLabel: 'Flashlight unavailable',
          size: 56,
          color: flashlightDanger,
        ),
        Mp.sizedBox(height: 18),
        Mp.text(
          'NO FLASHLIGHT FOUND',
          color: flashlightText,
          size: 19,
          weight: 'bold',
          align: 'center',
        ),
        Mp.sizedBox(height: 10),
        Mp.text(
          '{{state.flashlight.error.message}}',
          color: flashlightMuted,
          size: 13,
          align: 'center',
          maxLines: 4,
        ),
        Mp.sizedBox(height: 22),
        Mp.button(
          label: 'CHECK AGAIN',
          action: refreshFlashlightStatus(),
          height: 52,
          backgroundColor: flashlightSurfaceStrong,
          foregroundColor: flashlightText,
          borderColor: flashlightBorder,
          borderWidth: 1,
          borderRadius: 8,
          fontSize: 14,
          fontWeight: 'semibold',
        ),
      ],
    ),
  );
}

MpNode _screenMessage({
  required String icon,
  required String title,
  required String color,
  String? message,
}) {
  return Mp.container(
    paddingHorizontal: 30,
    paddingVertical: 96,
    backgroundColor: flashlightBackground,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon(icon, semanticLabel: title, size: 50, color: color),
        Mp.sizedBox(height: 18),
        Mp.text(
          title,
          color: flashlightText,
          size: 21,
          weight: 'semibold',
          align: 'center',
        ),
        if (message != null) ...<MpNode>[
          Mp.sizedBox(height: 10),
          Mp.text(
            message,
            color: flashlightMuted,
            size: 13,
            align: 'center',
            maxLines: 4,
          ),
        ],
      ],
    ),
  );
}
