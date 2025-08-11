# Active Context

## Current Focus
- Connect Flutter frontend to Supabase (completed)
- Add Supabase/Firebase dependencies to frontend (completed)
- Fix storage upload typing with `Uint8List` (completed)

## Next Up
- Replace backend `SECRET_KEY` placeholder for production
- Confirm Supabase RLS policies are applied in production
- Add CI/CD secrets for `--dart-define` values during builds

## Recent Changes (2025-08-11)
- Updated `frontend/pubspec.yaml` to include `supabase_flutter` and Firebase packages
- Updated `frontend/lib/core/config/app_config.dart` defaults for dev
- Fixed `Uint8List` conversion in `supabase_service.dart`
- Verified `flutter build web` succeeds
