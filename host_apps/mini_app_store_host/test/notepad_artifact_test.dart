import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('Notepad 1.0.1 artifact parses with the host SDK', () async {
    final manifest = MiniProgramManifest.fromJson(
      jsonDecode(await _artifactFile('manifest.json').readAsString()),
    );

    expect(manifest.id, 'notepad');
    expect(manifest.version, '1.0.1');

    for (final screenId in <String>['notepad_home', 'notepad_editor']) {
      final screen = Map<String, dynamic>.from(
        jsonDecode(await _artifactFile('screens/$screenId.json').readAsString())
            as Map,
      );
      const MpScreenValidator().validate(screen, expectedScreenId: screenId);
    }
  });

  test(
    'GitHub Pages serves a loadable Notepad entry screen',
    () async {
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('https://mehedi8603651.github.io/mini-app-store'),
        enableLocalLoopbackFallback: false,
        requestTimeout: const Duration(seconds: 20),
      );
      try {
        final manifest = await source.loadManifest('notepad');
        expect(manifest.version, '1.0.1');
        final screen = await source.loadScreen(
          miniProgramId: 'notepad',
          version: manifest.version,
          screenId: manifest.entry,
        );
        const MpScreenValidator().validate(
          screen,
          expectedScreenId: 'notepad_home',
        );
      } finally {
        source.dispose();
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_NOTEPAD_TESTS'),
  );
}

File _artifactFile(String relativePath) {
  return File('../../mini-apps/notepad/artifacts/notepad/1.0.1/$relativePath');
}
