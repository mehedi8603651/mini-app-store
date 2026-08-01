import 'package:mini_program_ui/mini_program_ui.dart';

const flashlightDeviceState = 'flashlight.device';
const flashlightOperationStatus = 'flashlight.operation_status';
const flashlightErrorState = 'flashlight.error';

List<MpAction> initializeFlashlight() => <MpAction>[
  Mp.flashlight.getStatus(
    targetState: flashlightDeviceState,
    statusState: flashlightOperationStatus,
    errorState: flashlightErrorState,
    requestId: 'flashlight-initial-status',
  ),
];

MpAction toggleFlashlight() => Mp.flashlight.toggle(
  targetState: flashlightDeviceState,
  statusState: flashlightOperationStatus,
  errorState: flashlightErrorState,
  requestId: 'flashlight-toggle',
);

MpAction refreshFlashlightStatus() => Mp.flashlight.getStatus(
  targetState: flashlightDeviceState,
  statusState: flashlightOperationStatus,
  errorState: flashlightErrorState,
  requestId: 'flashlight-refresh-status',
);
