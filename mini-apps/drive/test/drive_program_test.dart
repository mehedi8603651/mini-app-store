import 'dart:convert';

import 'package:test/test.dart';

import '../mp/program.dart';

void main() {
  test('builds authenticated Drive screens with file transfers', () {
    final screens = miniProgram.buildScreensJson();
    final home = jsonEncode(screens['drive_home']);
    final rename = jsonEncode(screens['drive_rename']);

    expect(screens.keys, <String>['drive_home', 'drive_rename']);
    expect(home, contains('authBuilder'));
    expect(home, contains('file.upload'));
    expect(home, contains('file.download'));
    expect(home, contains('file.cancel'));
    expect(home, contains('backendBuilder'));
    expect(home, contains('files/delete'));
    expect(rename, contains('files/rename'));
    expect(rename, contains('stateTextField'));
  });
}
