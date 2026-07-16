#!/usr/bin/env python3
"""Fail-closed, ledger-backed runner for White Povar SQL migrations."""
import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS_DIR = ROOT / "migrations"
MANIFEST_PATH = MIGRATIONS_DIR / "manifest.json"
LOCK_ID = 781469310221
LEDGER_SQL = """
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    migration_id TEXT PRIMARY KEY,
    filename TEXT NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    duration_ms BIGINT NOT NULL CHECK (duration_ms >= 0)
)
"""


class MigrationError(RuntimeError):
    pass


def load_manifest(path=MANIFEST_PATH):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    migrations = data.get("migrations")
    if not isinstance(migrations, list) or not migrations:
        raise MigrationError("Manifest contains no migrations")
    ids = set()
    for item in migrations:
        migration_id = item.get("id")
        filename = item.get("filename")
        if not migration_id or not filename or migration_id in ids:
            raise MigrationError("Manifest has a missing or duplicate migration ID")
        if Path(filename).name != filename or not (MIGRATIONS_DIR / filename).is_file():
            raise MigrationError("Manifest references a missing migration file")
        ids.add(migration_id)
    for item in migrations:
        unknown = set(item.get("requires", [])) - ids
        if unknown:
            raise MigrationError("Manifest has an unknown dependency")
    return migrations


def checksum(migration):
    return hashlib.sha256((MIGRATIONS_DIR / migration["filename"]).read_bytes()).hexdigest()


def project_ref_from_url(url):
    host = urlparse(url).hostname or ""
    match = re.search(r"(?:^|\.)db\.([a-z0-9]{20})\.supabase\.co$", host)
    if match:
        return match.group(1)
    match = re.search(r"^([a-z0-9]{20})\.supabase\.co$", host)
    return match.group(1) if match else None


def verify_project_ref(expected, supabase_url):
    actual = project_ref_from_url(supabase_url)
    if not expected or not actual or actual != expected:
        raise MigrationError("Supabase project ref verification failed")


def connect():
    database_url = os.getenv("DATABASE_URL")
    expected_ref = os.getenv("EXPECTED_SUPABASE_PROJECT_REF")
    supabase_url = os.getenv("SUPABASE_URL", "")
    if not database_url:
        raise MigrationError("DATABASE_URL is required")
    verify_project_ref(expected_ref, supabase_url)
    try:
        import psycopg
    except ImportError as error:
        raise MigrationError("Install backend requirements before running migrations") from error
    return psycopg.connect(database_url)


def ledger_rows(conn):
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT migration_id, filename, checksum_sha256 FROM public.schema_migrations")
            return {row[0]: {"filename": row[1], "checksum": row[2]} for row in cursor.fetchall()}
    except Exception as error:
        conn.rollback()
        if getattr(error, "sqlstate", None) == "42P01":
            return None
        raise MigrationError("Unable to read migration ledger") from error


def classify(manifest, ledger):
    result = []
    for migration in manifest:
        current_checksum = checksum(migration)
        entry = {"id": migration["id"], "filename": migration["filename"], "checksum": current_checksum}
        if not migration.get("managed", True):
            entry["state"] = "manual-review"
        elif ledger is None:
            entry["state"] = "ledger-missing"
        elif migration["id"] in ledger:
            saved = ledger[migration["id"]]
            entry["state"] = "applied" if saved["filename"] == migration["filename"] and saved["checksum"] == current_checksum else "checksum-mismatch"
        else:
            missing = [item for item in migration.get("requires", []) if item not in ledger]
            entry["state"] = "blocked" if missing else "pending"
            if missing:
                entry["blocked_by"] = missing
        result.append(entry)
    return result


def print_status(rows):
    for row in rows:
        suffix = ""
        if row.get("blocked_by"):
            suffix = " blocked_by=" + ",".join(row["blocked_by"])
        print(f"{row['state']:17} {row['id']} ({row['filename']}){suffix}")


def migration_sql(migration):
    sql = (MIGRATIONS_DIR / migration["filename"]).read_text(encoding="utf-8")
    # Checked-in forward migrations wrap themselves in BEGIN/COMMIT. Remove only
    # that outer pair so the runner can atomically write SQL and its ledger entry.
    sql = re.sub(r"^\s*BEGIN\s*;", "", sql, count=1, flags=re.IGNORECASE)
    sql = re.sub(r"COMMIT\s*;\s*$", "", sql, count=1, flags=re.IGNORECASE)
    return sql


def apply_pending(conn, manifest, rows):
    bad = [row for row in rows if row["state"] == "checksum-mismatch"]
    if bad:
        raise MigrationError("Checksum mismatch; refusing to run migrations")
    with conn.transaction():
        with conn.cursor() as cursor:
            cursor.execute("SELECT pg_advisory_xact_lock(%s)", (LOCK_ID,))
            cursor.execute(LEDGER_SQL)
    # A new ledger has no rows, so entries previously reported as ledger-missing
    # become pending (or dependency-blocked) only after its creation commits.
    rows = classify(manifest, ledger_rows(conn) or {})
    for migration in manifest:
        row = next(item for item in rows if item["id"] == migration["id"])
        if row["state"] != "pending":
            continue
        started = time.monotonic()
        try:
            with conn.transaction():
                with conn.cursor() as cursor:
                    cursor.execute("SELECT pg_advisory_xact_lock(%s)", (LOCK_ID,))
                    cursor.execute(migration_sql(migration))
                    cursor.execute(
                        "INSERT INTO public.schema_migrations (migration_id, filename, checksum_sha256, duration_ms) VALUES (%s, %s, %s, %s)",
                        (migration["id"], migration["filename"], checksum(migration), int((time.monotonic() - started) * 1000)),
                    )
        except Exception as error:
            raise MigrationError(f"Migration failed: {migration['id']}") from error
        print(f"applied {migration['id']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "plan", "apply"))
    args = parser.parse_args()
    load_dotenv(ROOT / ".env")
    manifest = load_manifest()
    try:
        with connect() as conn:
            ledger = ledger_rows(conn)
            rows = classify(manifest, ledger)
            if args.command == "status":
                print_status(rows)
            elif args.command == "plan":
                print_status(rows)
                print("Read-only preflight complete; no migrations were applied.")
            else:
                apply_pending(conn, manifest, rows)
    except MigrationError as error:
        print(f"Migration runner refused: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
