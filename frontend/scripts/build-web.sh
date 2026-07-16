#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL:?API_BASE_URL is required}"
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

ENVIRONMENT="${ENVIRONMENT:-production}"
TENANT_SLUG="${TENANT_SLUG:-}"

if [ "$ENVIRONMENT" != "development" ] && [ -z "$TENANT_SLUG" ]; then
  echo "TENANT_SLUG is required for $ENVIRONMENT builds. Set it with the deployment environment or CI." >&2
  exit 1
fi

if [ "$ENVIRONMENT" = "production" ] && [ -z "${SUPPORT_EMAIL:-}" ]; then
  echo "SUPPORT_EMAIL is required for production builds." >&2
  exit 1
fi

# Local development is the only context allowed to use the pilot tenant by default.
TENANT_SLUG="${TENANT_SLUG:-ohorodnik-oleksandr}"

flutter build web \
  --release \
  --base-href=/ \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WEB_APP_URL="${WEB_APP_URL:-https://white-povar-p79r.onrender.com}" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=ENVIRONMENT="$ENVIRONMENT" \
  --dart-define=TENANT_SLUG="$TENANT_SLUG" \
  --dart-define=SUPPORT_EMAIL="${SUPPORT_EMAIL:-}" \
  --dart-define=BUILD_LABEL="${BUILD_LABEL:-v1.0.0}" \
  --dart-define=GOOGLE_OAUTH_ENABLED="${GOOGLE_OAUTH_ENABLED:-false}"
