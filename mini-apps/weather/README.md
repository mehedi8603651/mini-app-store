# Bangladesh Weather

Bangladesh-first weather mini-program for the Flutter Mini-Program Platform.

Features:

- local search across divisions, districts, thanas, areas, upazilas and unions
- Open-Meteo geocoding fallback when no Bangladesh result matches
- current conditions, 24-hour chart and cards, and seven-day forecast
- pull-to-refresh and explicit refresh controls
- persistent selected location and host-approved local data caching

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

The Mini App Store host contains a Weather-only Open-Meteo adapter for local
testing. A production publisher should expose the same relative `forecast` and
`geocoding` routes from its HTTPS middle-server.

Weather and geocoding data are provided by Open-Meteo. Global location data is
based on GeoNames as documented by Open-Meteo.
