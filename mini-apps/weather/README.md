# Bangladesh Weather

Bangladesh-first weather mini-program for the Flutter Mini-Program Platform.

Features:

- local search across divisions, districts, thanas, areas, upazilas and unions
- Open-Meteo geocoding fallback when no Bangladesh result matches
- current conditions, 24-hour chart and cards, and seven-day forecast
- pull-to-refresh and explicit refresh controls
- persistent selected location and host-approved local data caching
- optional one-time approximate current location through host-approved policy

## Build location assets

```powershell
dart run tool/build_location_assets.dart
```

The generated files under `assets/data/` are flattened derivatives of:

- `bangladesh_thana_area.json`
- `bangladesh_upzila_area.json`

Source: https://github.com/mehedi8603651/bangladesh-geocode-all-area

## Build and verify

```powershell
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart build --mini-program-root .
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart artifact build --mini-program-root .
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart artifact verify --mini-program-root .
```

Root `publisher_backend.json` declares the production HTTPS middle-server.
The host accepts or denies Publisher API permission; it does not configure a
Weather-specific URL or adapter. Screen actions use relative `forecast` and
`geocoding` routes.

Weather and geocoding data are provided by Open-Meteo. Global location data is
based on GeoNames as documented by Open-Meteo.

Device location is foreground-only and user initiated. The mini-program does
not reverse geocode or track location; it stores the coordinates under the
existing selected-location cache and labels them `Current location`.
