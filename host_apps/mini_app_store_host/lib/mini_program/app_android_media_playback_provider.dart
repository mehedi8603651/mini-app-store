import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android Media3 adapter for streamed audio and inline video.
///
/// The SDK resolves trusted artifact or Publisher API sources before this
/// provider receives them. Resolved URLs, headers, and native cache paths
/// remain inside this trusted adapter.
class AppAndroidMediaPlaybackProvider
    implements MiniProgramMediaPlaybackProvider {
  const AppAndroidMediaPlaybackProvider();

  @override
  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  ) => _AndroidMediaPlaybackBridge.instance.createSession(request);
}

class _AndroidMediaPlaybackBridge {
  _AndroidMediaPlaybackBridge._();

  static final _AndroidMediaPlaybackBridge instance =
      _AndroidMediaPlaybackBridge._();
  static const MethodChannel _channel = MethodChannel(
    'mini_program/media_playback',
  );
  static const String viewType = 'mini_program/media_playback_view';

  final Map<String, _AppMedia3PlaybackSession> _sessions =
      <String, _AppMedia3PlaybackSession>{};
  int _nextSession = 0;
  bool _handlerInstalled = false;

  void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'playbackEvent' || call.arguments is! Map) return;
      final event = Map<String, dynamic>.from(call.arguments as Map);
      final sessionId = event['sessionId'];
      final snapshot = event['snapshot'];
      if (sessionId is String && snapshot is Map) {
        _sessions[sessionId]?.updateSnapshot(
          MiniProgramMediaPlaybackSnapshot.fromJson(
            Map<String, dynamic>.from(snapshot),
          ),
        );
      }
    });
  }

  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  ) async {
    _installHandler();
    Object? lastError;
    for (final uri in request.source.candidateUris) {
      final sessionId =
          '${request.miniProgramId}:${request.playerId}:${++_nextSession}';
      try {
        final raw = await _channel
            .invokeMapMethod<String, dynamic>('create', <String, Object?>{
              'sessionId': sessionId,
              'miniProgramId': request.miniProgramId,
              'playerId': request.playerId,
              'kind': request.kind.wireName,
              'uri': uri.toString(),
              'headers': request.source.headers,
              'sourceKey': request.sourceKey,
              'cacheMode': request.cacheMode.name,
              'maxCacheBytes': request.maxCacheBytes,
              'cacheTtlMs': request.cacheTtl?.inMilliseconds,
              'autoplay': request.autoplay,
              'loop': request.loop,
              'volume': request.volume,
              'speed': request.speed,
              'muted': request.muted,
              'timeoutMs': request.source.timeout.inMilliseconds,
            })
            .timeout(request.source.timeout + const Duration(seconds: 1));
        if (raw == null) {
          throw const FormatException('Android returned no media snapshot.');
        }
        final session = _AppMedia3PlaybackSession(
          bridge: this,
          request: request,
          sessionId: sessionId,
          initialSnapshot: MiniProgramMediaPlaybackSnapshot.fromJson(raw),
        );
        _sessions[sessionId] = session;
        return session;
      } on PlatformException catch (error) {
        lastError = error;
        await _bestEffortRelease(sessionId);
        if (!_isRetryable(error.code)) rethrow;
      } on TimeoutException catch (error) {
        lastError = error;
        await _bestEffortRelease(sessionId);
      } catch (error) {
        lastError = error;
        await _bestEffortRelease(sessionId);
      }
    }
    if (lastError is PlatformException) {
      final error = lastError;
      throw MiniProgramMediaPlaybackException(
        errorCode: _stableErrorCode(error.code),
        message: error.message ?? 'Android could not load the media stream.',
      );
    }
    throw MiniProgramMediaPlaybackException(
      errorCode: lastError is TimeoutException
          ? MiniProgramErrorCodes.mediaTimeout
          : MiniProgramErrorCodes.mediaLoadFailed,
      message: 'Android could not load the media stream.',
      details: lastError == null
          ? const <String, Object?>{}
          : <String, Object?>{'cause': lastError.runtimeType.toString()},
    );
  }

  Future<void> invoke(String method, String sessionId, [Object? value]) async {
    try {
      await _channel.invokeMethod<void>(method, <String, Object?>{
        'sessionId': sessionId,
        'value': ?value,
      });
    } on PlatformException catch (error) {
      throw MiniProgramMediaPlaybackException(
        errorCode: _stableErrorCode(error.code),
        message: error.message ?? 'Android media playback failed.',
      );
    }
  }

  Future<void> release(String sessionId) async {
    _sessions.remove(sessionId);
    await _bestEffortRelease(sessionId);
  }

  Future<void> _bestEffortRelease(String sessionId) async {
    try {
      await _channel.invokeMethod<void>('release', <String, Object?>{
        'sessionId': sessionId,
      });
    } on PlatformException {
      // A failed or already detached native session has no remaining owner.
    }
  }

  bool _isRetryable(String code) =>
      code == MiniProgramErrorCodes.mediaNetworkError ||
      code == MiniProgramErrorCodes.mediaTimeout ||
      code == MiniProgramErrorCodes.mediaLoadFailed;

  String _stableErrorCode(String code) => switch (code) {
    MiniProgramErrorCodes.mediaNotAccepted ||
    MiniProgramErrorCodes.mediaProviderUnavailable ||
    MiniProgramErrorCodes.mediaInvalidSource ||
    MiniProgramErrorCodes.mediaLoadFailed ||
    MiniProgramErrorCodes.mediaNetworkError ||
    MiniProgramErrorCodes.mediaTimeout ||
    MiniProgramErrorCodes.mediaUnsupportedFormat ||
    MiniProgramErrorCodes.mediaRequestInProgress ||
    MiniProgramErrorCodes.mediaPlayerNotFound ||
    MiniProgramErrorCodes.mediaSourceExpired ||
    MiniProgramErrorCodes.mediaCacheUnavailable ||
    MiniProgramErrorCodes.mediaCacheFailed ||
    MiniProgramErrorCodes.mediaFullscreenUnavailable ||
    MiniProgramErrorCodes.mediaInterrupted ||
    MiniProgramErrorCodes.mediaPlaybackFailed => code,
    _ => MiniProgramErrorCodes.mediaPlaybackFailed,
  };
}

class _AppMedia3PlaybackSession extends ChangeNotifier
    implements
        MiniProgramMediaPlaybackSession,
        MiniProgramFullscreenMediaPlaybackSession {
  _AppMedia3PlaybackSession({
    required this.bridge,
    required this.request,
    required this.sessionId,
    required MiniProgramMediaPlaybackSnapshot initialSnapshot,
  }) : _snapshot = initialSnapshot;

  final _AndroidMediaPlaybackBridge bridge;
  final MiniProgramMediaPlaybackRequest request;
  final String sessionId;
  MiniProgramMediaPlaybackSnapshot _snapshot;
  bool _disposed = false;

  @override
  String get sourceKey => request.sourceKey;

  @override
  MiniProgramMediaPlaybackSnapshot get snapshot => _snapshot;

  void updateSnapshot(MiniProgramMediaPlaybackSnapshot value) {
    if (_disposed || value.playerId != request.playerId) return;
    _snapshot = value;
    notifyListeners();
  }

  @override
  Widget buildVideoView({
    required BoxFit fit,
    required bool controls,
    required String semanticLabel,
  }) {
    if (request.kind != MiniProgramMediaPlaybackKind.video) {
      return const SizedBox.shrink();
    }
    return _AppMedia3VideoView(
      session: this,
      fit: fit,
      controls: controls,
      semanticLabel: semanticLabel,
    );
  }

  @override
  Future<void> play() => bridge.invoke('play', sessionId);

  @override
  Future<void> pause() => bridge.invoke('pause', sessionId);

  @override
  Future<void> seek(Duration position) =>
      bridge.invoke('seek', sessionId, position.inMilliseconds);

  @override
  Future<void> stop() => bridge.invoke('stop', sessionId);

  @override
  Future<void> setMuted(bool muted) =>
      bridge.invoke('setMuted', sessionId, muted);

  @override
  Future<void> setVolume(double volume) =>
      bridge.invoke('setVolume', sessionId, volume);

  @override
  Future<void> setSpeed(double speed) =>
      bridge.invoke('setSpeed', sessionId, speed);

  @override
  Future<void> enterFullscreen() => bridge.invoke('enterFullscreen', sessionId);

  @override
  Future<void> exitFullscreen() => bridge.invoke('exitFullscreen', sessionId);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await bridge.release(sessionId);
    super.dispose();
  }
}

class _AppMedia3VideoView extends StatelessWidget {
  const _AppMedia3VideoView({
    required this.session,
    required this.fit,
    required this.controls,
    required this.semanticLabel,
  });

  final _AppMedia3PlaybackSession session;
  final BoxFit fit;
  final bool controls;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AndroidView(
            viewType: _AndroidMediaPlaybackBridge.viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: <String, Object?>{
              'sessionId': session.sessionId,
              'fit': _fitName(fit),
            },
          ),
          if (controls)
            Align(
              alignment: Alignment.bottomCenter,
              child: _AppMedia3Controls(session: session),
            ),
        ],
      ),
    );
  }

  String _fitName(BoxFit fit) => switch (fit) {
    BoxFit.cover => 'cover',
    BoxFit.fill => 'fill',
    _ => 'contain',
  };
}

class _AppMedia3Controls extends StatelessWidget {
  const _AppMedia3Controls({required this.session});

  final _AppMedia3PlaybackSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final value = session.snapshot;
        final durationMs = value.duration?.inMilliseconds ?? 0;
        final positionMs = value.position.inMilliseconds.clamp(0, durationMs);
        return ColoredBox(
          color: Colors.black54,
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: value.status == MiniProgramMediaPlaybackStatus.playing
                    ? 'Pause'
                    : 'Play',
                color: Colors.white,
                onPressed:
                    value.status == MiniProgramMediaPlaybackStatus.playing
                    ? () => unawaited(session.pause())
                    : () => unawaited(session.play()),
                icon: Icon(
                  value.status == MiniProgramMediaPlaybackStatus.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              Text(
                _durationLabel(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                  value: durationMs <= 0 ? 0 : positionMs.toDouble(),
                  onChanged: durationMs <= 0
                      ? null
                      : (position) => unawaited(
                          session.seek(
                            Duration(milliseconds: position.round()),
                          ),
                        ),
                ),
              ),
              Text(
                _durationLabel(value.duration ?? Duration.zero),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              IconButton(
                tooltip: value.muted ? 'Unmute' : 'Mute',
                color: Colors.white,
                onPressed: () => unawaited(session.setMuted(!value.muted)),
                icon: Icon(value.muted ? Icons.volume_off : Icons.volume_up),
              ),
              IconButton(
                tooltip: 'Fullscreen',
                color: Colors.white,
                onPressed: () => unawaited(session.enterFullscreen()),
                icon: const Icon(Icons.fullscreen),
              ),
            ],
          ),
        );
      },
    );
  }

  String _durationLabel(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
