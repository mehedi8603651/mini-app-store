import 'package:test/test.dart';

import '../mp/program.dart';

void main() {
  test('builds MP4, HLS, and audio playback controls', () {
    final screens = miniProgram.buildScreensJson();
    final home = screens['media_home'];

    expect(screens.keys, <String>['media_home']);
    expect(home, containsPair('screenId', 'media_home'));
    expect(_countType(home, 'videoView'), 2);
    expect(_containsType(home, 'audio.play'), isTrue);
    expect(_containsType(home, 'audio.pause'), isTrue);
    expect(_containsType(home, 'audio.stop'), isTrue);
    expect(_containsType(home, 'audio.setVolume'), isTrue);
    expect(_containsType(home, 'audio.setSpeed'), isTrue);
    expect(_containsType(home, 'video.enterFullscreen'), isTrue);
    expect(_containsPublisherEndpoint(home, 'media/sample.mp4'), isTrue);
    expect(_containsPublisherEndpoint(home, 'media/sample.m3u8'), isTrue);
    expect(_containsPublisherEndpoint(home, 'media/sample.mp3'), isTrue);
  });
}

bool _containsType(Object? value, String type) {
  if (value is Map) {
    if (value['type'] == type) return true;
    return value.values.any((entry) => _containsType(entry, type));
  }
  if (value is List) {
    return value.any((entry) => _containsType(entry, type));
  }
  return false;
}

int _countType(Object? value, String type) {
  if (value is Map) {
    return (value['type'] == type ? 1 : 0) +
        value.values.fold<int>(
          0,
          (count, entry) => count + _countType(entry, type),
        );
  }
  if (value is List) {
    return value.fold<int>(
      0,
      (count, entry) => count + _countType(entry, type),
    );
  }
  return 0;
}

bool _containsPublisherEndpoint(Object? value, String endpoint) {
  if (value is Map) {
    if (value['kind'] == 'publisher' && value['endpoint'] == endpoint) {
      return true;
    }
    return value.values.any(
      (entry) => _containsPublisherEndpoint(entry, endpoint),
    );
  }
  if (value is List) {
    return value.any((entry) => _containsPublisherEndpoint(entry, endpoint));
  }
  return false;
}
