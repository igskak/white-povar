# System Patterns

## Architecture Decisions
- Flutter uses `supabase_flutter` for DB/auth/storage; Firebase for platform auth and initialization
- Backend loads secrets from `backend/.env` via pydantic-settings
- Frontend runtime config via `String.fromEnvironment` with `--dart-define`

## Component Relationships
- Flutter → FastAPI: REST API (`API_BASE_URL`)
- Flutter → Supabase: direct client (anon key), storage uploads
- FastAPI → Supabase: admin operations via service key
- Flutter → Firebase: initializes with `firebase_options.dart`, optional auth providers

## Security
- Do not commit secrets
- Use CI/CD secrets for builds and hosting
- Apply RLS policies in Supabase as documented
