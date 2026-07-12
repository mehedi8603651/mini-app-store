# Mini App Store

Static mini-program artifacts and Android host applications built with the
Flutter Mini Program Platform.

## Repository layout

- `mini-apps/calculator`: Mp authoring source for the calculator.
- `host_apps/mini_app_store_host`: Android-focused Flutter host application.
- `docs`: public static artifacts for GitHub Pages.

The calculator supports offline expression evaluation, MC, M+, M-, MR,
backspace, sign and percent controls, bounded history, and host-managed
persistence. Only the accepted `state` cache bucket stores memory and history.

## Local packages

The source currently resolves SDK packages from the sibling checkout at
`D:/flutter-mini-program-platform`. This is intentional while the calculator
uses local `mini_program_ui 0.1.8` and `mini_program_sdk 0.5.6` changes.

## Rebuild static artifacts

```powershell
cd D:\flutter-mini-program-platform
dart run packages/mini_program_tooling/bin/miniprogram.dart publish calculator `
  --mini-program-root D:\mini-app-store\mini-apps\calculator `
  --target static `
  --output D:\mini-app-store\docs `
  --clean
```

## Android development

Serve the generated artifacts:

```powershell
python -m http.server 8080 --directory D:\mini-app-store\docs
```

For an emulator, reverse the port and run with a loopback override:

```powershell
& "$env:ANDROID_HOME\platform-tools\adb.exe" -s emulator-5554 reverse tcp:8080 tcp:8080

cd D:\mini-app-store\host_apps\mini_app_store_host
flutter run -d emulator-5554 `
  --dart-define=MINI_PROGRAM_CALCULATOR_URL=http://127.0.0.1:8080
```

Without the override, the host uses the production endpoint configured in
`mini_program_endpoints.dart`.

## GitHub Pages

After pushing the repository, configure Pages to deploy from the `main` branch
and `/docs` folder. The partner handoff expects:

`https://mehedi8603651.github.io/mini-app-store/`
