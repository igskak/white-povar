# White Povar — production release runbook

Этот runbook применяется только к зафиксированному SHA release candidate после
успешного `REL-01`. Он не разрешает выполнять следующий шаг, пока не выполнены
его условия go/no-go.

## 0. Preconditions and go/no-go

- Все зависимости `PILOT-00`, `DB-01`, `DEMO-01`, `DEMO-02`, `CFG-01` и
  `REL-01` имеют статус `DONE`; SHA кандидата записан в журнале.
- В Render и Supabase заданы секреты вне git: production `DATABASE_URL`,
  `SUPABASE_URL`, service/anon keys, `SECRET_KEY`, `SUPPORT_EMAIL`,
  `COMMERCE_MODE=demo` и server-only demo allowlist. Значения не выводятся в
  логи и не передаются в Flutter `--dart-define`.
- `EXPECTED_SUPABASE_PROJECT_REF=qnlfvpqmkmbvzmzqgjpo` совпадает с
  `SUPABASE_URL`; `python3 backend/tools/migrate.py plan` завершается успешно
  без `checksum-mismatch` или неизвестных managed migration entries.
- Назначены владелец backup/PITR, owner deploy и решение rollback; нет P0/P1.

**No-go:** отсутствует хотя бы один пункт выше, backup/PITR evidence,
production plan, API readiness или API/web smoke. Остановиться; не применять
migrations и не deploy.

## 1. DB-02 — backup and migrations

1. Записать timestamp и recovery reference Supabase backup/PITR в release
   evidence; проверить, что восстановление доступно владельцу.
2. Из release environment выполнить `python3 backend/tools/migrate.py plan`.
   Сохранить output. Вручную сверить три `manual-review` legacy files с уже
   применённым production state; их runner не запускает.
3. При чистом plan выполнить `python3 backend/tools/migrate.py apply` один раз
   из защищённого release environment и сохранить output `status`.
4. Проверить bootstrap/catalogue/offers/tenant data через production API или
   SQL read-only checks. При migration error остановиться: транзакция rollback
   выполнен автоматически.

## 2. DEPLOY-01 — API, then web

1. Push exact candidate SHA в `main`; дождаться GitHub checks и один
   автоматический Render deploy API. Не запускать второй deploy для того же SHA.
2. Проверить API `/health` и `/health/ready`, CORS с
   `https://white-povar-p79r.onrender.com`, tenant bootstrap, catalogue и
   server-side `COMMERCE_MODE=demo`. Не логировать секреты/allowlist.
3. Только при API smoke green publish Flutter web с public Dart defines,
   `TENANT_SLUG=ohorodnik-oleksandr` и без debug/demo bypass. Дождаться Render
   auto-deploy и HTTP 200 для production web.
4. Проверить auth callback, protected premium route, allowlisted demo purchase
   и non-allowlisted refusal; client success сам по себе не должен открыть
   premium content.

## 3. Rollback decision

- До database apply: не deploy; исправить candidate и заново пройти gates.
- Failed migration: не редактировать ledger и не использовать destructive
  reset. Применить forward corrective migration; restore recorded recovery
  point только если forward fix небезопасен.
- API regression: rollback API к предыдущему healthy Render deploy до web
  promotion.
- Web regression после healthy API: rollback только static-site deploy к
  предыдущему healthy build. Не использовать BrandConfig rollback как замену
  rollback сломанного приложения/schema.
- После любого rollback повторить health/readiness и critical smoke, записать
  deploy IDs, timestamps, observed outcome и владельца решения.
