# Production configuration runbook

This runbook prepares configuration only. It does not authorize a migration,
seed, deploy, or a change to a production secret.

## Render API service

Set these server-only values in Render. Do not place their values in git, Flutter
`--dart-define`, logs, readiness responses, or support tickets:

- `SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_KEY`, `SUPABASE_SERVICE_KEY`,
  `SUPABASE_JWT_SECRET`, `DATABASE_URL`, and `OPENAI_API_KEY`;
- `DEMO_COMMERCE_ALLOWED_EMAILS` only after the product owner supplies the demo
  accounts; and
- `REVENUECAT_WEBHOOK_AUTHORIZATION` only for the later mobile integration.

For the web pilot set `ENVIRONMENT=production`, `COMMERCE_MODE=demo`,
`WEB_APP_URL=https://white-povar-p79r.onrender.com`, and preserve all three
entries in `ALLOWED_ORIGINS` from `render.yaml` (Render plus the two existing
Firebase origins). A future custom domain must be added to both values in a
separate change, after its DNS and browser preflight are verified.

The API fails startup in production, and `/health/ready` returns `503`, if a
required value is absent, `COMMERCE_MODE` is invalid, or `WEB_APP_URL` is not an
allowed CORS origin. These responses identify only setting names, never values.

## Render web service

Only public browser values may be passed as Dart defines: `API_BASE_URL`,
`WEB_APP_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TENANT_SLUG`,
`ENVIRONMENT`, `SUPPORT_EMAIL`, `BUILD_LABEL`, and `GOOGLE_OAUTH_ENABLED`.
The build script refuses a production build without `SUPPORT_EMAIL`.

`SUPABASE_ANON_KEY` is public by design; service-role, database, OpenAI,
application, commerce, and allowlist secrets must never be bundled into web.
Leave `GOOGLE_OAUTH_ENABLED=false` until its Supabase provider and callback have
been verified. Apple sign-in is not offered on web in this pilot.

## Supabase Auth preflight before activation

1. Set Site URL to `https://white-povar-p79r.onrender.com`.
2. Add `https://white-povar-p79r.onrender.com/auth/callback` to Redirect URLs.
   The same callback is used for email confirmation and password reset.
3. If Google is enabled, configure its provider redirect in Google/Supabase,
   complete a browser sign-in, then set `GOOGLE_OAUTH_ENABLED=true` in Render.
4. Verify email/password sign-in, sign-up confirmation, password-reset return,
   and a CORS preflight from the deployed web origin.

Until formal legal pages exist, Settings presents in-app demo privacy and
demo-use notices instead of linking to placeholder or broken URLs.
