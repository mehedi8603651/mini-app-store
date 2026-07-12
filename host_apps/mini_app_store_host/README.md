# Mini App Store Android host

Flutter host application for mini-programs in this repository.

## Calculator integration

- Production artifacts resolve from GitHub Pages.
- `MINI_PROGRAM_CALCULATOR_URL` can override delivery for local development.
- `MiniProgramCacheBundle.fileBacked(...)` persists accepted cache buckets.
- `lib/mini_program/mini_program_policies.json` is the host-owned policy source.
- The calculator receives a 1 MiB, 30-day `state` cache allowance.
- The mini-program launches without host app chrome for its full-screen UI.

## Run on Android emulator

```powershell
& "$env:ANDROID_HOME\platform-tools\adb.exe" -s emulator-5554 reverse tcp:8080 tcp:8080

flutter run -d emulator-5554 `
  --dart-define=MINI_PROGRAM_CALCULATOR_URL=http://127.0.0.1:8080
```

The local package overrides expect `D:/flutter-mini-program-platform` to exist
beside `D:/mini-app-store`.
