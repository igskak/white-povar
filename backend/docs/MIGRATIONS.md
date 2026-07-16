# Production migrations

Use `python3 tools/migrate.py status` to inspect the ledger and `python3 tools/migrate.py plan` for a read-only preflight. Both require `DATABASE_URL`, `SUPABASE_URL`, and `EXPECTED_SUPABASE_PROJECT_REF`; the runner compares the expected ref with `SUPABASE_URL` before it connects. It never prints either URL or credentials.

`python3 tools/migrate.py apply` is deliberately forward-only. It takes a PostgreSQL advisory transaction lock, runs one manifest migration and its ledger entry in a single transaction, then fails immediately on an error or checksum mismatch. Do not use `run_migrations_direct.py`; it is retained only as historical code.

Before a production apply in DB-02: record a Supabase backup/PITR recovery reference, run `plan`, reconcile the three `manual-review` legacy files against production without replaying them, and save the status output with the release evidence. On any failed migration, stop: its transaction was rolled back. Restore from the recorded recovery point only when a forward fix is unsafe; never delete or edit a `schema_migrations` row to force a retry.
