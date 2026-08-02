# Mini App Store Android host

Flutter host application for mini-programs in this repository.

## Mini-program integration

- Production artifacts resolve from GitHub Pages.
- `MINI_PROGRAM_CALCULATOR_URL` can override delivery for local development.
- `MiniProgramCacheBundle.fileBacked(...)` persists accepted cache buckets.
- `lib/mini_program/mini_program_policies.json` is the host-owned policy source.
- The calculator receives a 1 MiB, 30-day `state` cache allowance.
- Drive receives only its accepted Publisher API and file upload/download
  permissions, including the 3 MiB host file limit.
- Friends receives accepted Publisher API and QR scanner permissions; QR torch
  control is scoped to the scanner and does not grant flashlight permission.
- Media Lab receives accepted Publisher API, foreground audio/video playback,
  and bounded temporary media-cache permissions.
- Android file transfers use the generated native MethodChannel adapter and
  the system document picker; the host never stores Publisher API credentials.
- The mini-program launches without host app chrome for its full-screen UI.
- `MINI_PROGRAM_FRIENDS_URL` can override only Friends artifact delivery during
  local development without changing its accepted policies.
- `MINI_PROGRAM_MEDIA_URL` can override only Media Lab artifact delivery during
  local development without changing its accepted policies.
- Android media playback uses the generated Media3 adapter for MP4, HLS/M3U8,
  MP3, audio focus, fullscreen video, and app lifecycle cleanup.

## Run on Android emulator

```powershell
& "$env:ANDROID_HOME\platform-tools\adb.exe" -s emulator-5554 reverse tcp:8080 tcp:8080

flutter run -d emulator-5554 `
  --dart-define=MINI_PROGRAM_CALCULATOR_URL=http://127.0.0.1:8080
```

The local package overrides expect `D:/flutter-mini-program-platform` to exist
beside `D:/mini-app-store`.
