#!/usr/bin/env bash
# Runs the same checks as .github/workflows/ci.yml, locally.
#
# Why: prod deploys are gated on green CI (render.yaml -> autoDeployTrigger:
# checksPass). A push that fails CI simply never reaches prod. Running this
# before pushing catches a red build on your machine instead of discovering it
# after the fact on GitHub.
#
# Usage:
#   scripts/ci-local.sh            # frontend + backend (backend best-effort)
#   scripts/ci-local.sh frontend   # frontend only
#   scripts/ci-local.sh backend    # backend only
#
# Exit code is non-zero if any check fails.
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

target="${1:-all}"
fail=0

bold() { printf "\n\033[1m==> %s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✓ %s\033[0m\n" "$1"; }
bad()  { printf "\033[31m✗ %s\033[0m\n" "$1"; fail=1; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$1"; }

run_frontend() {
  if ! command -v flutter >/dev/null 2>&1; then
    warn "flutter not found on PATH — skipping frontend checks (CI will still run them)"
    return
  fi

  bold "frontend: flutter pub get"
  ( cd frontend && flutter pub get ) || { bad "flutter pub get failed"; return; }

  bold "frontend: dart format (verify)"
  if ( cd frontend && dart format --output=none --set-exit-if-changed . ); then
    ok "formatting clean"
  else
    bad "dart format found unformatted files (run: cd frontend && dart format .)"
  fi

  bold "frontend: flutter analyze"
  if ( cd frontend && flutter analyze ); then ok "analyze clean"; else bad "flutter analyze reported issues"; fi

  bold "frontend: flutter test (excluding golden)"
  if ( cd frontend && flutter test --exclude-tags golden ); then ok "tests passed"; else bad "flutter tests failed"; fi
}

run_backend() {
  # Backend has its own checksPass gate and its own venv. Only run if the
  # tools are resolvable; otherwise warn rather than block a frontend-only push.
  local py="python3"
  for cand in backend/.venv/bin/python backend/venv/bin/python; do
    [ -x "$repo_root/$cand" ] && py="$repo_root/$cand" && break
  done

  if ! "$py" -c "import flake8, pytest" >/dev/null 2>&1; then
    warn "backend flake8/pytest not installed (checked $py) — skipping backend checks locally; CI still runs them"
    return
  fi

  bold "backend: flake8 (syntax/undefined-name gate)"
  if ( cd backend && "$py" -m flake8 app/ --count --select=E9,F63,F7,F82 --show-source --statistics ); then
    ok "flake8 clean"
  else
    bad "flake8 reported issues"
  fi

  bold "backend: pytest"
  if ( cd backend && "$py" -m pytest tests/ -q ); then ok "pytest passed"; else bad "pytest failed"; fi
}

case "$target" in
  frontend) run_frontend ;;
  backend)  run_backend ;;
  all)      run_frontend; run_backend ;;
  *) echo "unknown target: $target (use: frontend | backend | all)"; exit 2 ;;
esac

if [ "$fail" -ne 0 ]; then
  printf "\n\033[31m✗ ci-local: checks failed — this push would go RED and would NOT deploy to prod.\033[0m\n"
  exit 1
fi
printf "\n\033[32m✓ ci-local: all checks passed — safe to push.\033[0m\n"
