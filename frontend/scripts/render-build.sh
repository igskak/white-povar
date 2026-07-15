#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL:?API_BASE_URL is required}"
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
: "${TENANT_SLUG:?TENANT_SLUG is required for production builds}"

FLUTTER_VERSION="$(< .flutter-version)"
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
./scripts/build-web.sh
