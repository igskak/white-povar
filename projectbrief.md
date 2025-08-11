# Project Brief

## Goal
Deliver a white-label cooking app with:
- Flutter frontend (web, iOS, Android)
- FastAPI backend
- Supabase (database, storage, client SDK)
- Firebase (core, auth, hosting)

## Scope
- Auth, recipe CRUD, image upload, search, theming per chef
- Multi-tenant support via chef configuration

## Current Implementation Snapshot (2025-08-11)
- Backend `.env` contains real Supabase and Firebase credentials
- Frontend uses `supabase_flutter`; Firebase initialized via `firebase_options.dart`
- Runtime config passed via `--dart-define` for `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Flutter app builds successfully for web

## Non-Goals (for now)
- Payments, subscriptions
- Offline sync beyond local favorites
