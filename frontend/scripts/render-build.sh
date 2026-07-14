#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL:?API_BASE_URL is required}"
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.5}"
FLUTTER_CACHE_ROOT="${RENDER_CACHE_DIR:-$HOME/.cache}"
FLUTTER_HOME="$FLUTTER_CACHE_ROOT/flutter-$FLUTTER_VERSION"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  rm -rf "$FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get
flutter analyze
flutter build web \
  --release \
  --base-href=/ \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WEB_APP_URL="${WEB_APP_URL:-https://white-povar.onrender.com}" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=ENVIRONMENT="${ENVIRONMENT:-production}"
