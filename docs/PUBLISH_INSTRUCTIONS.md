# MiniProgram Static Publish

This folder contains public/static delivery artifacts for `calculator`
version `1.0.0`.

Upload the contents of this folder to any public static host, CDN, object
storage website, or simple HTTPS file server.

GitHub Pages users should keep the generated `.nojekyll` file so generated
paths are served as normal static files. If this folder is committed inside a
larger Pages repo, also keep a `.nojekyll` file at the repo root.

Use the public URL for this folder as the endpoint base URI:

```dart
MiniProgramEndpoint.public(
  apiBaseUri: Uri.parse('https://your-cdn.example.com/public_mini_program/'),
)
```

Public static artifact delivery is unauthenticated. Do not publish secrets,
private user data, auth state, payment data, or business rules into the
mini-program artifacts. Put those behind your optional middle-server API.
