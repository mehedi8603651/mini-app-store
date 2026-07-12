# Calculator mini-program

A static, offline Mp calculator for the Flutter Mini Program Platform.

## Features

- Core-Dart expression evaluation through `Mp.math.evaluate`.
- Digit, decimal, operator, percent, sign, clear, and backspace controls.
- MC, M+, M-, and MR composed from reusable `Mp.state` actions.
- Bounded history with a separate history screen.
- Host-approved persistence through `Mp.cache.state` only.
- Responsive phone layout with a constrained work area on wider Android
  screens.

## Source

- `mp/program.dart` registers the calculator and history screens.
- `mp/screens/calculator_home.dart` defines the keypad and memory behavior.
- `mp/screens/calculator_history.dart` renders and clears saved history.
- `calculator.partner.json` requests the state cache policy from hosts.

## Build and validate

Run from `D:/flutter-mini-program-platform`:

```powershell
dart run packages/mini_program_tooling/bin/miniprogram.dart validate calculator `
  --mini-program-root D:\mini-app-store\mini-apps\calculator
```

The app has no required host capabilities and stores no login, token, or
session data.
