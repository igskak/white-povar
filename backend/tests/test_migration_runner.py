import importlib.util
import os
from pathlib import Path

import pytest


RUNNER_PATH = Path(__file__).parents[1] / "tools" / "migrate.py"
SPEC = importlib.util.spec_from_file_location("migration_runner", RUNNER_PATH)
migrate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(migrate)


def test_manifest_files_checksums_and_dependencies_are_valid():
    manifest = migrate.load_manifest()
    managed = [item for item in manifest if item.get("managed", True)]
    assert len(managed) == 20
    assert all(len(migrate.checksum(item)) == 64 for item in manifest)
    assert manifest[0]["id"] == "legacy_subscription_schema"
    assert any(item["id"] == "2026_07_15_commerce_access" for item in manifest)


def test_status_reports_pending_applied_and_checksum_mismatch():
    manifest = migrate.load_manifest()
    first_managed = next(item for item in manifest if item.get("managed", True))
    ledger = {
        first_managed["id"]: {
            "filename": first_managed["filename"],
            "checksum": migrate.checksum(first_managed),
        },
        "2026_07_15_published_brand_configs": {
            "filename": "2026_07_15_published_brand_configs.sql",
            "checksum": "0" * 64,
        },
    }
    states = {row["id"]: row["state"] for row in migrate.classify(manifest, ledger)}
    assert states[first_managed["id"]] == "applied"
    assert states["2026_07_15_published_brand_configs"] == "checksum-mismatch"
    assert states["2026_07_15_collections"] == "pending"
    assert states["legacy_sample_premium_recipe"] == "manual-review"


def test_project_ref_must_match_and_sql_keeps_transaction_atomic():
    migrate.verify_project_ref("abcdefghijklmnopqrst", "https://abcdefghijklmnopqrst.supabase.co")
    try:
        migrate.verify_project_ref("abcdefghijklmnopqrst", "https://zyxwvutsrqponmlkjihg.supabase.co")
    except migrate.MigrationError:
        pass
    else:
        raise AssertionError("mismatched project ref must fail")
    migration = next(item for item in migrate.load_manifest() if item["id"] == "2026_07_15_collections")
    sql = migrate.migration_sql(migration)
    assert not sql.lstrip().upper().startswith("BEGIN;")
    assert not sql.rstrip().upper().endswith("COMMIT;")


@pytest.mark.skipif(
    not os.getenv("MIGRATION_TEST_DATABASE_URL"),
    reason="set MIGRATION_TEST_DATABASE_URL to run against disposable PostgreSQL",
)
def test_apply_is_idempotent_and_rolls_back_failed_migration(tmp_path, monkeypatch):
    import psycopg

    first = {"id": "first", "filename": "first.sql", "requires": []}
    failed = {"id": "failed", "filename": "failed.sql", "requires": ["first"]}
    (tmp_path / "first.sql").write_text("CREATE TABLE runner_probe (id INTEGER PRIMARY KEY);", encoding="utf-8")
    (tmp_path / "failed.sql").write_text("CREATE TABLE must_rollback (id INTEGER); SELECT no_such_function();", encoding="utf-8")
    monkeypatch.setattr(migrate, "MIGRATIONS_DIR", tmp_path)
    with psycopg.connect(os.environ["MIGRATION_TEST_DATABASE_URL"]) as conn:
        rows = migrate.classify([first], {})
        migrate.apply_pending(conn, [first], rows)
        migrate.apply_pending(conn, [first], migrate.classify([first], migrate.ledger_rows(conn)))
        with conn.cursor() as cursor:
            cursor.execute("SELECT count(*) FROM public.schema_migrations WHERE migration_id = 'first'")
            assert cursor.fetchone()[0] == 1
        with pytest.raises(migrate.MigrationError):
            migrate.apply_pending(conn, [first, failed], migrate.classify([first, failed], migrate.ledger_rows(conn)))
        with conn.cursor() as cursor:
            cursor.execute("SELECT to_regclass('public.must_rollback')")
            assert cursor.fetchone()[0] is None
