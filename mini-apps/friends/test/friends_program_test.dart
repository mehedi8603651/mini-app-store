import 'package:test/test.dart';

import '../mp/program.dart';

void main() {
  test('builds accepted QR friendship screens', () {
    final screens = miniProgram.buildScreensJson();

    expect(screens.keys, <String>[
      'friends_home',
      'friends_invite',
      'friends_scan',
      'friends_requests',
      'friends_list',
    ]);
    expect(_containsType(screens['friends_invite'], 'qrCode'), isTrue);
    expect(_containsType(screens['friends_scan'], 'qr.scan'), isTrue);
    expect(
      _containsEndpoint(screens['friends_requests'], 'friend-requests/accept'),
      isTrue,
    );
    expect(
      _containsEndpoint(screens['friends_requests'], 'friend-requests/decline'),
      isTrue,
    );
  });
}

bool _containsType(Object? value, String type) {
  if (value is Map) {
    if (value['type'] == type) return true;
    return value.values.any((entry) => _containsType(entry, type));
  }
  if (value is List) return value.any((entry) => _containsType(entry, type));
  return false;
}

bool _containsEndpoint(Object? value, String endpoint) {
  if (value is Map) {
    if (value['endpoint'] == endpoint) return true;
    return value.values.any((entry) => _containsEndpoint(entry, endpoint));
  }
  if (value is List)
    return value.any((entry) => _containsEndpoint(entry, endpoint));
  return false;
}
