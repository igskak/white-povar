# QA-REL — release qualification

This is the release gate for a tenant build. It is deliberately a checklist,
not a claim that a store submission, backup restore, or production deployment
has happened locally. Record the evidence and owner beside every unchecked
item before promoting a build.

## Local, repeatable gate

Run from the repository root. `TENANT_SLUG` must be supplied for the release
web build; use non-secret test values for the other defines.

```bash
cd backend
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python3 -m pytest tests/ -q
.venv/bin/flake8 app tests --select=E9,F63,F7,F82

cd ../frontend
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test -r compact
API_BASE_URL=https://api.test.invalid \
SUPABASE_URL=https://project.supabase.co \
SUPABASE_ANON_KEY=test-anon-key \
TENANT_SLUG=ohorodnik-oleksandr \
scripts/build-web.sh

cd ..
git diff --check
```

The automated suites cover the reproducible portions of the qualification:

| Area | Evidence in the repository |
|---|---|
| Guest/auth and protected-content journeys | `frontend/test/smoke_user_journeys_test.dart`, `frontend/test/route_guards_test.dart`, `backend/tests/test_tenant_isolation_contract.py` |
| Subscriber/one-off server contract | `backend/tests/test_commerce_access_contract.py`, `backend/tests/test_commerce_webhook_contract.py` |
| Two-tenant isolation | `backend/tests/test_tenant_isolation_contract.py`, collection and commerce contract tests |
| Offline/restart | `frontend/test/brand_bootstrapper_test.dart`, `frontend/test/cooking_progress_store_test.dart`, pantry tests |
| Accessibility and adaptive UI | `frontend/test/qa_design_matrix_test.dart` and screen tests at 390/768/1280 |
| Auth callback/deep links | `frontend/test/route_guards_test.dart`, `frontend/lib/features/auth/presentation/pages/auth_callback_page.dart` |
| Privacy and account deletion | `backend/tests/test_observability_contract.py`, `backend/tests/test_auth_completion_contract.py`, `backend/tests/test_release_qualification_contract.py` |
| Config rollback/readiness | `backend/tests/test_studio_release_contract.py`, `backend/docs/observability.md` |

## Staging evidence required before approval

- [ ] Test guest, authenticated, subscriber, and one-off accounts on physical
  iOS, Android, and web; verify a free account receives no protected recipe
  body and both paid accounts receive only their entitled content.
- [ ] Perform the same catalogue/detail/deep-link checks in two staging
  tenants, including a deliberately guessed identifier from the other tenant.
- [ ] Complete StoreKit and Google Play sandbox purchase, cancellation,
  restore, renewal/expiry, refund, and RevenueCat webhook replay. Reconcile
  each result against the server entitlement ledger.
- [ ] Test cold start, network loss and recovery, and cooking-session restart
  on real devices.
- [ ] Run TalkBack/VoiceOver and keyboard-only checks, including 200% text
  size and reduced motion; record accepted P2 deviations with owner and date.
- [ ] Capture web/mobile performance evidence (cold start, interactive search,
  detail and cooking route) against the release target agreed for the pilot.
- [ ] Verify Supabase OAuth redirect URLs and native callback
  `io.supabase.cookingapp://login-callback` in the deployed tenant build.
- [ ] Restore a backup into an isolated environment, verify its tenant data,
  then exercise the documented BrandConfig rollback. Do not call this a
  successful rollback until both are observed.
- [ ] Verify privacy/legal links and execute account deletion using a staging
  account; confirm dependent private data, analytics consent/events, and push
  device bindings are gone, and that the identity can no longer authenticate.
- [ ] Confirm deployment secrets are present only in the secret manager,
  `/health/ready` is green without exposing values, migrations are applied,
  alert/error-log redaction is configured, and backup ownership/RPO/RTO are
  recorded.

## Current release blockers

`COM-02`, `COM-03`, and `COM-04` are blocked: no authenticated store sandbox
configuration, verified StoreKit/Google Play products, or external RevenueCat
webhook worker is available in this workspace. The pending Supabase migrations,
production secrets, deployed OAuth callback configuration, backup restore, and
physical-device evidence are also external operations. Therefore QA-REL must
remain **BLOCKED**; local passing tests are not release sign-off.

Do not use the legacy root `TESTING_GUIDE.md` for release approval: it documents
the superseded debug subscription flow. This checklist is the authoritative
release qualification record.
