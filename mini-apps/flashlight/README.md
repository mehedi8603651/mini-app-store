# Flashlight mini-program

A focused Android flashlight controller for the Flutter Mini Program Platform.

## Included

- Live flashlight availability and enabled-state checks.
- Host-controlled foreground permission handling.
- One-tap toggle and manual status refresh.
- Automatic flashlight shutdown when the mini-program closes.
- No cached hardware state and no background operation.

## Build and verify

```powershell
miniprogram build
miniprogram artifact build
miniprogram artifact verify
```

The host must accept `permissions.flashlight` and install the Android
flashlight capability provider.
