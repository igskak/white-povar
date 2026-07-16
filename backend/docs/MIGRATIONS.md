# Production migrations

Use `python3 tools/migrate.py status` to inspect the ledger and `python3 tools/migrate.py plan` for a read-only preflight. Both require `DATABASE_URL`, `SUPABASE_URL`, and `EXPECTED_SUPABASE_PROJECT_REF`; the runner compares the expected ref with `SUPABASE_URL` before it connects. It never prints either URL or credentials.

`python3 tools/migrate.py apply` is deliberately forward-only. It takes a PostgreSQL advisory transaction lock, runs one manifest migration and its ledger entry in a single transaction, then fails immediately on an error or checksum mismatch. Do not use `run_migrations_direct.py`; it is retained only as historical code.

Before a production apply in DB-02: record a Supabase backup/PITR recovery reference, run `plan`, reconcile the three `manual-review` legacy files against production without replaying them, and save the status output with the release evidence. On any failed migration, stop: its transaction was rolled back. Restore from the recorded recovery point only when a forward fix is unsafe; never delete or edit a `schema_migrations` row to force a retry.

## Legacy baseline procedure

`baseline-legacy` is the only way to register a confirmed historical migration
without executing its SQL. It is deliberately limited to
`legacy_subscription_schema` and `legacy_subscription_backfill`; DB-02 must
first confirm the subscription columns and their non-null backfill in a
read-only production query. Run it only after backup evidence is recorded:

```bash
python3 tools/migrate.py baseline-legacy \
  --migration legacy_subscription_schema \
  --migration legacy_subscription_backfill
```

The command writes only matching checksum ledger entries under the same
advisory lock as `apply`; rerunning it is a no-op and a checksum mismatch fails
closed. `legacy_sample_premium_recipe` remains `manual-review`: its historical,
random data update cannot be safely proved or replayed, and no managed
migration depends on it.
