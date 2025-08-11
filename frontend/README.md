# Frontend (Flutter)

White Povar cross‑platform Flutter app.

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

These can be passed with `--dart-define` when running or building. Example:

```bash
# Web (Chrome)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>

# Android/iOS
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Note: Defaults are set in `AppConfig` for local development, but production builds should always pass values explicitly.

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
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Build

```bash
# Web
flutter build web \
  --dart-define=API_BASE_URL=https://<your-backend> \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Notes
- Do not commit secrets. Use `--dart-define` or CI/CD secrets.
- Supabase storage uploads require `Uint8List`; see `lib/core/services/supabase_service.dart`.
