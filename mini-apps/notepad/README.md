# Notepad mini-program

A focused, offline Notepad mini-program for the Flutter Mini Program Platform.

## Included

- Dark note list inspired by the supplied Android reference.
- Create, open, edit, save, and delete notes.
- Bounded multiline note editing through `Mp.stateTextField`.
- Up to 50 notes with 120-character titles and 4 KiB bodies.
- Host-approved persistence through `Mp.cache.state` only.

Categories, sorting, backup, file import/export, trash, and settings are
intentionally outside this first release.

## Build and validate

From `D:/flutter-mini-program-platform`:

```powershell
dart run packages/mini_program_tooling/bin/miniprogram.dart build notepad `
  --mini-program-root D:\mini-app-store\mini-apps\notepad
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact build notepad `
  --mini-program-root D:\mini-app-store\mini-apps\notepad
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact verify notepad `
  --mini-program-root D:\mini-app-store\mini-apps\notepad
```

The current source uses local UI `0.2.1` while the new controlled editor is
being device-tested. The host uses local SDK `0.6.1` through its existing path
override.
