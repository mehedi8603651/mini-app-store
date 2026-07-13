# Brain Test mini-program

Brain Test is a static, offline true-or-false arithmetic challenge built with
the Flutter Mini Program Platform.

## Features

- Easy, Medium, and Difficult question generators.
- Ten-second lifecycle countdown for every question.
- Safe Core-Dart math evaluation and strict action branching.
- Bounded score history and best scores per difficulty.
- Host-approved persistence through the `state` cache bucket only.
- Four portable Mp screens: Home, Game, Result, and History.

## Build and verify

Run from `D:/flutter-mini-program-platform`:

```powershell
dart run packages/mini_program_tooling/bin/miniprogram.dart build `
  --mini-program-root D:\mini-app-store\mini-apps\brain_test
dart run packages/mini_program_tooling/bin/miniprogram.dart validate brain_test `
  --mini-program-root D:\mini-app-store\mini-apps\brain_test
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact build `
  --mini-program-root D:\mini-app-store\mini-apps\brain_test
dart run packages/mini_program_tooling/bin/miniprogram.dart artifact verify `
  --mini-program-root D:\mini-app-store\mini-apps\brain_test
```

The immutable release is generated under
`artifacts/brain_test/<version>`. Increment `manifest.json` before rebuilding
changed content after version `1.0.0` has been published.
