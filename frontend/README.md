# Frontend (Flutter)

White Povar cross‑platform Flutter app.

`frontend/` is the canonical consumer application and the only Flutter app
included in production builds. The repository-root Flutter scaffold is not a
production target.

**Current Version**: Stable build from commit d9e2453

## Stack
- Flutter 3.x
- Riverpod, Go Router
- Supabase (supabase_flutter)
- Firebase (firebase_core, firebase_auth)

## Configuration

The app reads runtime configuration via `String.fromEnvironment(...)` in `lib/core/config/app_config.dart`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `API_BASE_URL`
- `TENANT_SLUG`

These can be passed with `--dart-define` when running or building. Example:

```bash
# Web (Chrome)
flutter run -d chrome \
  --dart-define=ENVIRONMENT=development \
  --dart-define=TENANT_SLUG=ohorodnik-oleksandr \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>

# Android/iOS
flutter run \
  --dart-define=ENVIRONMENT=development \
  --dart-define=TENANT_SLUG=ohorodnik-oleksandr \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

`TENANT_SLUG` is required for CI, staging, and production builds. Local
development may omit it only with `ENVIRONMENT=development`, which uses the
pilot `ohorodnik-oleksandr` tenant.

## Firebase

Firebase is initialized via `lib/firebase_options.dart`.

If you need to regenerate configs:

```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

This will update:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

## Install Dependencies

```bash
flutter pub get
```

## Run

```bash
flutter run -d chrome \
  --dart-define=ENVIRONMENT=development \
  --dart-define=TENANT_SLUG=ohorodnik-oleksandr \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Build

```bash
# CI-compatible production web build
API_BASE_URL=https://<your-backend> \
WEB_APP_URL=https://<your-web-app> \
SUPABASE_URL=https://<your-project>.supabase.co \
SUPABASE_ANON_KEY=<your-anon-key> \
TENANT_SLUG=ohorodnik-oleksandr \
ENVIRONMENT=production \
./scripts/build-web.sh
```

## Local CI baseline

From the repository root, use the same checks as CI (Flutter version is pinned
in `frontend/.flutter-version`):

```bash
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
API_BASE_URL=https://white-povar-api-p79r.onrender.com \
WEB_APP_URL=https://white-povar-p79r.onrender.com \
SUPABASE_URL=https://example.supabase.co \
SUPABASE_ANON_KEY=test-anon-key \
TENANT_SLUG=ohorodnik-oleksandr \
ENVIRONMENT=ci \
./scripts/build-web.sh

cd ../backend
python3 -m pytest tests/ -v
python3 -c "from app.main import app; print(app.title)"
```

## Notes
- Do not commit secrets. Use `--dart-define` or CI/CD secrets.
- Supabase storage uploads require `Uint8List`; see `lib/core/services/supabase_service.dart`.
