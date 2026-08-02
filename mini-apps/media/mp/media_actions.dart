import 'package:mini_program_ui/mini_program_ui.dart';

const mp4PlayerId = 'sample_mp4';
const hlsPlayerId = 'sample_hls';
const audioPlayerId = 'sample_audio';

const mp4StatusState = 'media.mp4.status';
const mp4ErrorState = 'media.mp4.error';
const hlsStatusState = 'media.hls.status';
const hlsErrorState = 'media.hls.error';
const audioStatusState = 'media.audio.status';
const audioErrorState = 'media.audio.error';
const audioLabelState = 'media.audio.label';

MpVideoSource mp4Source() =>
    MpVideoSource.publisher(endpoint: 'media/sample.mp4');

MpVideoSource hlsSource() =>
    MpVideoSource.publisher(endpoint: 'media/sample.m3u8');

MpAudioSource audioSource() =>
    MpAudioSource.publisher(endpoint: 'media/sample.mp3');

List<MpAction> initializeMediaState() => <MpAction>[
  Mp.state.setDefault(mp4StatusState, 'loading'),
  Mp.state.setDefault(hlsStatusState, 'loading'),
  Mp.state.setDefault(audioStatusState, 'idle'),
  Mp.state.setDefault(audioLabelState, 'READY'),
];

MpAction replayMp4() => Mp.action.sequence(<MpAction>[
  Mp.video.seek(playerId: mp4PlayerId, position: Duration.zero),
  Mp.video.play(playerId: mp4PlayerId),
]);

MpAction replayHls() => Mp.action.sequence(<MpAction>[
  Mp.video.seek(playerId: hlsPlayerId, position: Duration.zero),
  Mp.video.play(playerId: hlsPlayerId),
]);

MpAction playAudio() => Mp.action.sequence(<MpAction>[
  Mp.audio.play(
    audioId: audioPlayerId,
    source: audioSource(),
    cacheMode: 'temporary',
    statusState: audioStatusState,
    errorState: audioErrorState,
    requestId: 'audio-play',
  ),
  Mp.state.patch(<String, Object?>{audioLabelState: 'PLAYING'}),
]);

MpAction pauseAudio() => Mp.action.sequence(<MpAction>[
  Mp.audio.pause(audioId: audioPlayerId, requestId: 'audio-pause'),
  Mp.state.patch(<String, Object?>{audioLabelState: 'PAUSED'}),
]);

MpAction stopAudio() => Mp.action.sequence(<MpAction>[
  Mp.audio.stop(audioId: audioPlayerId, requestId: 'audio-stop'),
  Mp.state.patch(<String, Object?>{audioLabelState: 'STOPPED'}),
]);

MpAction setAudioVolume(double volume, String label) =>
    Mp.action.sequence(<MpAction>[
      Mp.audio.setVolume(
        audioId: audioPlayerId,
        volume: volume,
        requestId: 'audio-volume',
      ),
      Mp.toast(message: 'Volume $label'),
    ]);

MpAction setAudioSpeed(double speed) => Mp.action.sequence(<MpAction>[
  Mp.audio.setSpeed(
    audioId: audioPlayerId,
    speed: speed,
    requestId: 'audio-speed',
  ),
  Mp.toast(message: 'Speed ${speed}x'),
]);

MpAction videoReady(String kind) =>
    Mp.toast(message: '$kind ready', durationMs: 1200);

MpAction videoEnded(String kind) => Mp.toast(message: '$kind playback ended');

MpAction videoError(String errorState) =>
    Mp.toast(message: '{{state.$errorState.message}}', durationMs: 3200);
