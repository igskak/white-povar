# Tech Context

## Stack
- Flutter 3.x, Riverpod, Go Router, Dio, Hive
- Supabase (client SDK, storage)
- Firebase (core, auth, hosting)
- FastAPI, Pydantic, Uvicorn

## Key Files
- `frontend/lib/core/config/app_config.dart` (runtime config)
- `frontend/lib/core/services/supabase_service.dart` (client wrapper)
- `lib/firebase_options.dart` and `frontend/lib/firebase_options.dart` (platform configs)
- `backend/app/core/settings.py` (backend settings)

## Commands
- Run web:
  - `flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon>`
- Build web:
  - `flutter build web --release --dart-define=API_BASE_URL=https://<backend> --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon>`
