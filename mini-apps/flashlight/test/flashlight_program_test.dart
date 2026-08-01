import 'package:test/test.dart';

import '../mp/program.dart';

void main() {
  test('builds the flashlight control screen', () {
    final screens = miniProgram.buildScreensJson();

    expect(screens.keys, <String>['flashlight_home']);
    final home = screens['flashlight_home'];
    expect(home, containsPair('screenId', 'flashlight_home'));
    expect(_containsType(home, 'flashlight.getStatus'), isTrue);
    expect(_containsType(home, 'flashlight.toggle'), isTrue);
    expect(_containsType(home, 'stateBuilder'), isTrue);
    expect(_containsType(home, 'condition'), isTrue);
  });
}

bool _containsType(Object? value, String type) {
  if (value is Map) {
    if (value['type'] == type) {
      return true;
    }
    return value.values.any((entry) => _containsType(entry, type));
  }
  if (value is List) {
    return value.any((entry) => _containsType(entry, type));
  }
  return false;
}
