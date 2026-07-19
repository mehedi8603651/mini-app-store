import 'package:test/test.dart';

import '../mp/program.dart';

void main() {
  test('builds deterministic home and editor screens', () {
    final screens = miniProgram.buildScreensJson();

    expect(screens.keys, <String>['notepad_home', 'notepad_editor']);
    expect(screens['notepad_home'], containsPair('screenId', 'notepad_home'));
    expect(
      screens['notepad_editor'],
      containsPair('screenId', 'notepad_editor'),
    );
    expect(_containsType(screens['notepad_home'], 'cache.get'), isTrue);
    expect(_containsType(screens['notepad_home'], 'repeat'), isTrue);
    expect(_containsType(screens['notepad_home'], 'tap'), isTrue);
    expect(_containsType(screens['notepad_editor'], 'stateTextField'), isTrue);
    expect(_containsType(screens['notepad_editor'], 'cache.set'), isTrue);
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
