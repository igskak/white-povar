"""Shared pytest configuration for backend tests."""

import os
import sys
from pathlib import Path


# Supabase's Python client validates API key shape during import-time service
# initialization. Tests do not talk to the real Supabase project, but imported
# FastAPI modules still construct the client. Keep CI/local tests deterministic
# by providing syntactically valid fake JWTs before app modules are imported.
_FAKE_SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6"
    "MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.test-signature"
)
_FAKE_SUPABASE_SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoic2VydmljZV9yb2xl"
    "IiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjQxMDI0NDQ4MDB9.test-signature"
)

os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ["SUPABASE_KEY"] = _FAKE_SUPABASE_ANON_KEY
os.environ["SUPABASE_SERVICE_KEY"] = _FAKE_SUPABASE_SERVICE_KEY
os.environ.setdefault("OPENAI_API_KEY", "test-openai-key")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-ci")
os.environ.setdefault("FIREBASE_PROJECT_ID", "test-firebase-project")

# Keep imports deterministic whether pytest is invoked as `pytest` or
# `python -m pytest`, from the repository root or from `backend/`.
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
