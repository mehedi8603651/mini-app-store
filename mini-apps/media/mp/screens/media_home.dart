import 'package:mini_program_ui/mini_program_ui.dart';

import '../media_actions.dart';
import '../media_theme.dart';

MpNode buildMediaHome() {
  return Mp.initialize(
    actions: initializeMediaState(),
    child: Mp.container(
      backgroundColor: mediaBackground,
      child: Mp.safeArea(
        child: Mp.scrollView(
          paddingHorizontal: 18,
          paddingTop: 18,
          paddingBottom: 36,
          child: Mp.center(
            child: Mp.container(
              width: 680,
              child: Mp.column(
                children: <MpNode>[
                  _header(),
                  Mp.sizedBox(height: 26),
                  _videoSection(
                    eyebrow: 'MP4 SAMPLE',
                    detail: 'SHORT VIDEO',
                    accent: mediaCoral,
                    statusState: mp4StatusState,
                    errorState: mp4ErrorState,
                    replay: replayMp4(),
                    fullscreen: Mp.video.enterFullscreen(playerId: mp4PlayerId),
                    player: Mp.videoView(
                      playerId: mp4PlayerId,
                      source: mp4Source(),
                      cacheMode: 'temporary',
                      statusState: mp4StatusState,
                      errorState: mp4ErrorState,
                      onReady: videoReady('MP4'),
                      onEnded: videoEnded('MP4'),
                      onError: videoError(mp4ErrorState),
                      semanticLabel: 'MP4 sample video',
                    ),
                  ),
                  Mp.sizedBox(height: 18),
                  _videoSection(
                    eyebrow: 'HLS STREAM',
                    detail: 'ADAPTIVE VIDEO',
                    accent: mediaTeal,
                    statusState: hlsStatusState,
                    errorState: hlsErrorState,
                    replay: replayHls(),
                    fullscreen: Mp.video.enterFullscreen(playerId: hlsPlayerId),
                    player: Mp.videoView(
                      playerId: hlsPlayerId,
                      source: hlsSource(),
                      cacheMode: 'streaming',
                      statusState: hlsStatusState,
                      errorState: hlsErrorState,
                      onReady: videoReady('HLS'),
                      onEnded: videoEnded('HLS'),
                      onError: videoError(hlsErrorState),
                      semanticLabel: 'HLS adaptive sample video',
                    ),
                  ),
                  Mp.sizedBox(height: 18),
                  _audioSection(),
                  Mp.sizedBox(height: 20),
                  _sourceNotice(),
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
        width: 48,
        height: 48,
        backgroundColor: mediaTeal,
        borderRadius: 8,
        child: Mp.center(
          child: Mp.text(
            'M',
            color: mediaBackground,
            size: 24,
            weight: 'bold',
            align: 'center',
          ),
        ),
      ),
      Mp.sizedBox(width: 13),
      Mp.expanded(
        child: Mp.column(
          children: <MpNode>[
            Mp.text('MEDIA LAB', color: mediaText, size: 22, weight: 'bold'),
            Mp.sizedBox(height: 3),
            Mp.text(
              'MP4  /  HLS  /  AUDIO',
              color: mediaMuted,
              size: 11,
              weight: 'medium',
            ),
          ],
        ),
      ),
      Mp.container(
        paddingHorizontal: 10,
        paddingVertical: 7,
        backgroundColor: mediaSurfaceStrong,
        borderColor: mediaBorder,
        borderWidth: 1,
        borderRadius: 6,
        child: Mp.text('ONLINE', color: mediaYellow, size: 10, weight: 'bold'),
      ),
    ],
  );
}

MpNode _videoSection({
  required String eyebrow,
  required String detail,
  required String accent,
  required String statusState,
  required String errorState,
  required MpAction replay,
  required MpAction fullscreen,
  required MpNode player,
}) {
  return Mp.container(
    backgroundColor: mediaSurface,
    borderColor: mediaBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.container(
          paddingHorizontal: 14,
          paddingVertical: 13,
          child: Mp.row(
            children: <MpNode>[
              Mp.expanded(
                child: Mp.text(
                  eyebrow,
                  color: mediaText,
                  size: 14,
                  weight: 'bold',
                ),
              ),
              Mp.text(detail, color: accent, size: 10, weight: 'bold'),
            ],
          ),
        ),
        player,
        Mp.container(
          paddingHorizontal: 14,
          paddingVertical: 12,
          child: Mp.column(
            children: <MpNode>[
              Mp.stateBuilder(
                keys: <String>[statusState, errorState],
                child: Mp.row(
                  children: <MpNode>[
                    Mp.container(
                      width: 8,
                      height: 8,
                      backgroundColor: accent,
                      borderRadius: 4,
                      child: Mp.sizedBox(width: 8, height: 8),
                    ),
                    Mp.sizedBox(width: 8),
                    Mp.expanded(
                      child: Mp.text(
                        'STATUS  {{state.$statusState}}',
                        color: mediaMuted,
                        size: 11,
                        weight: 'medium',
                      ),
                    ),
                  ],
                ),
              ),
              Mp.sizedBox(height: 11),
              Mp.row(
                children: <MpNode>[
                  Mp.expanded(
                    child: _controlButton(
                      label: 'REPLAY',
                      action: replay,
                      accent: accent,
                    ),
                  ),
                  Mp.sizedBox(width: 10),
                  Mp.expanded(
                    child: _controlButton(
                      label: 'FULLSCREEN',
                      action: fullscreen,
                      accent: mediaText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

MpNode _audioSection() {
  return Mp.container(
    paddingHorizontal: 16,
    paddingVertical: 16,
    backgroundColor: mediaSurface,
    borderColor: mediaBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.row(
          children: <MpNode>[
            Mp.container(
              width: 42,
              height: 42,
              backgroundColor: mediaYellow,
              borderRadius: 8,
              child: Mp.center(
                child: Mp.text(
                  'A',
                  color: mediaBackground,
                  size: 19,
                  weight: 'bold',
                  align: 'center',
                ),
              ),
            ),
            Mp.sizedBox(width: 12),
            Mp.expanded(
              child: Mp.column(
                children: <MpNode>[
                  Mp.text(
                    'SOUNDHELIX SAMPLE',
                    color: mediaText,
                    size: 14,
                    weight: 'bold',
                  ),
                  Mp.sizedBox(height: 3),
                  Mp.text(
                    'HEADLESS AUDIO  /  TEMP CACHE',
                    color: mediaMuted,
                    size: 10,
                    weight: 'medium',
                  ),
                ],
              ),
            ),
            Mp.stateBuilder(
              keys: const <String>[audioLabelState, audioStatusState],
              child: Mp.text(
                '{{state.media.audio.label}}',
                color: mediaYellow,
                size: 11,
                weight: 'bold',
              ),
            ),
          ],
        ),
        Mp.sizedBox(height: 18),
        Mp.row(
          children: <MpNode>[
            Mp.expanded(
              child: _controlButton(
                label: 'PLAY',
                action: playAudio(),
                accent: mediaYellow,
              ),
            ),
            Mp.sizedBox(width: 8),
            Mp.expanded(
              child: _controlButton(
                label: 'PAUSE',
                action: pauseAudio(),
                accent: mediaText,
              ),
            ),
            Mp.sizedBox(width: 8),
            Mp.expanded(
              child: _controlButton(
                label: 'STOP',
                action: stopAudio(),
                accent: mediaCoral,
              ),
            ),
          ],
        ),
        Mp.sizedBox(height: 12),
        Mp.divider(color: mediaBorder),
        Mp.sizedBox(height: 12),
        Mp.text('VOLUME', color: mediaMuted, size: 10, weight: 'bold'),
        Mp.sizedBox(height: 8),
        Mp.row(
          children: <MpNode>[
            Mp.expanded(
              child: _controlButton(
                label: '50%',
                action: setAudioVolume(0.5, '50%'),
                accent: mediaBlue,
              ),
            ),
            Mp.sizedBox(width: 8),
            Mp.expanded(
              child: _controlButton(
                label: '100%',
                action: setAudioVolume(1, '100%'),
                accent: mediaBlue,
              ),
            ),
            Mp.sizedBox(width: 14),
            Mp.expanded(
              child: _controlButton(
                label: '1.0x',
                action: setAudioSpeed(1),
                accent: mediaTeal,
              ),
            ),
            Mp.sizedBox(width: 8),
            Mp.expanded(
              child: _controlButton(
                label: '1.5x',
                action: setAudioSpeed(1.5),
                accent: mediaTeal,
              ),
            ),
          ],
        ),
        Mp.sizedBox(height: 12),
        Mp.stateBuilder(
          keys: const <String>[audioStatusState, audioErrorState],
          child: Mp.text(
            'STATUS  {{state.media.audio.status}}',
            color: mediaMuted,
            size: 11,
            weight: 'medium',
          ),
        ),
      ],
    ),
  );
}

MpNode _controlButton({
  required String label,
  required MpAction action,
  required String accent,
}) {
  return Mp.button(
    label: label,
    action: action,
    height: 46,
    backgroundColor: mediaSurfaceStrong,
    foregroundColor: accent,
    borderColor: mediaBorder,
    borderWidth: 1,
    borderRadius: 6,
    fontSize: 11,
    fontWeight: 'bold',
  );
}

MpNode _sourceNotice() {
  return Mp.container(
    paddingHorizontal: 14,
    paddingVertical: 13,
    backgroundColor: mediaSurfaceStrong,
    borderColor: mediaBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.row(
      children: <MpNode>[
        Mp.icon(
          'info',
          semanticLabel: 'Media source information',
          size: 20,
          color: mediaBlue,
        ),
        Mp.sizedBox(width: 10),
        Mp.expanded(
          child: Mp.text(
            'Samples stream through fixed Publisher API routes. Source URLs '
            'and playback bytes remain outside mini-program state.',
            color: mediaMuted,
            size: 11,
            maxLines: 4,
          ),
        ),
      ],
    ),
  );
}
