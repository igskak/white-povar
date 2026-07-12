"""Shared pytest configuration for backend tests."""

import sys
from pathlib import Path


# Keep imports deterministic whether pytest is invoked as `pytest` or
# `python -m pytest`, from the repository root or from `backend/`.
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
