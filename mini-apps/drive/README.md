# Drive

Android-focused Drive mini-program using the platform's Publisher API file
transfer capability. It supports secure email sessions, account-isolated file
listing, picker-based uploads, transfer progress/cancellation, Downloads
saving, rename, delete, and sign-out.

The AWS test backend is in `../../backends/drive_api`. Its synchronous
Lambda transport is intentionally capped at 3 MiB per file; this is a test
limit, not a platform-wide file limit.

## Build and verify

```powershell
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart build --mini-program-root .
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart artifact build --mini-program-root .
dart run D:\flutter-mini-program-platform\packages\mini_program_tooling\bin\miniprogram.dart artifact verify --mini-program-root .
```

The root `publisher_backend.json` owns the deployed Publisher API URL. The
host only accepts or denies Publisher API and file-transfer permissions.
