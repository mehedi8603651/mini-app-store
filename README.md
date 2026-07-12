# Mini App Store

Static mini-program artifacts and Android host applications built with the
Flutter Mini Program Platform.

## Repository layout

- `mini-apps/calculator`: Mp authoring source for the calculator.
- `host_apps/mini_app_store_host`: Android-focused Flutter host application.
- `.github/workflows/deploy-pages.yml`: validates, merges, and deploys all
  mini-program artifacts to GitHub Pages.

The calculator supports offline expression evaluation, MC, M+, M-, MR,
backspace, sign and percent controls, bounded history, and host-managed
persistence. Only the accepted `state` cache bucket stores memory and history.

## Local packages

The source currently resolves SDK packages from the sibling checkout at
`D:/flutter-mini-program-platform`. This is intentional while the calculator
uses local `mini_program_ui 0.1.8` and `mini_program_sdk 0.5.7` changes.

## Build and verify portable artifacts

```powershell
cd D:\flutter-mini-program-platform
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact build `
  --mini-program-root D:\mini-app-store\mini-apps\calculator
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact verify `
  --mini-program-root D:\mini-app-store\mini-apps\calculator
```

Each portable source bundle is generated under
`mini-apps/<project>/artifacts/<appId>/<version>`. Commit that generated bundle.
The Pages workflow automatically validates and merges every app into the
public `artifacts/<appId>/` tree; no manual publishing copy is required.

Published version directories are immutable. Change `manifest.json` to a new
semantic version before building changed release content.

## Android development

Stage and serve the same site that GitHub Pages deploys:

```powershell
cd D:\mini-app-store
python tool\build_pages_site.py --output _site
python -m http.server 8080 --directory D:\mini-app-store\_site
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

In repository Settings, open Pages and select **GitHub Actions** as the source.
Every push to `main` that changes committed mini-program artifacts validates
and deploys the combined site. The partner handoff expects:

`https://mehedi8603651.github.io/mini-app-store/`

The calculator latest manifest is served at
`https://mehedi8603651.github.io/mini-app-store/artifacts/calculator/latest.json`.

For every additional mini-program:

1. Create it under `mini-apps/<project>`.
2. Run `miniprogram artifact build` and `miniprogram artifact verify`.
3. Commit `mini-apps/<project>/artifacts/<appId>` and push `main`.
4. Use the same repository Pages URL as its `artifactBaseUrl`.
