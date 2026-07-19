# White Povar — план production web-пилота

Дата: 16 июля 2026

Статус: `PILOT-00`, `DB-01`, `DEMO-01`, `DEMO-02`, `CFG-01`, `REL-01` и `DB-02` завершены

Следующая задача: `SHOW-01` — `IN PROGRESS`: QA-01 завершён; подготовить resettable demo accounts, two repeatable runs, сценарий и fallback materials.

Production web: `https://white-povar-p79r.onrender.com`

Production API: `https://white-povar-api-p79r.onrender.com`

Production Supabase: `igskak's Project` (`qnlfvpqmkmbvzmzqgjpo`)

Первый tenant: `ohorodnik-oleksandr`

Этот документ является текущим исполнимым планом до завершения web-пилота.
`WHITE_POVAR_IMPLEMENTATION_PLAN.md` сохраняется как полный продуктовый roadmap и
история уже реализованных work packages, но не определяет ближайшую очередь работ.

## 1. Цель итерации

Получить привлекательную и максимально рабочую production web-версию White Povar,
которую можно показывать кулинарным блогерам и поварам:

- с персональным брендом «Огороднік Олександр»;
- с регистрацией и рабочими пользовательскими сценариями;
- с каталогом, коллекциями, персонализацией, voice recommendations и AI;
- с демонстрацией подписки и разовой покупки premium-коллекции;
- с реальным server-side entitlement после demo-покупки;
- без Apple Developer Account, App Store и мобильного release;
- с возможностью позднее заменить demo-commerce на Stripe без переделки access model.

Итерация заканчивается не после локальной реализации, а после успешного production
smoke test и готового сценария показа продукта.

## 2. Зафиксированные решения

1. Отдельный staging пока не создаётся.
2. Текущий production используется как pilot/demo environment, поскольку реальных
   пользователей ещё нет.
3. Любая опасная production-операция требует backup или другого проверенного
   recovery path.
4. Мобильная версия, Apple Developer Account, StoreKit, Google Play Billing,
   RevenueCat mobile configuration, APNs/FCM и mobile store QA перенесены в
   следующую итерацию.
5. Первый commerce mode — `demo`, без реального списания денег.
6. Demo-покупка не маскируется под реальный платёж: UI сообщает, что деньги не
   списываются, и предлагает активировать демонстрационный доступ.
7. Demo-покупка создаёт настоящий tenant-scoped server entitlement. Клиентский
   success state сам по себе доступ не выдаёт.
8. Demo-commerce доступен только разрешённым аккаунтам и выключается server-side
   kill switch.
9. Следующая реальная web-платёжная интеграция — прямой Stripe Checkout.
10. Web не зависит от RevenueCat. Мобильные магазины позднее смогут использовать
    RevenueCat поверх той же таблицы `commerce_entitlements`.
11. Все новые database migrations проходят через migration ledger, checksum,
    транзакционное выполнение и fail-fast поведение.
12. Нельзя запускать старый `backend/run_migrations_direct.py` на production в его
    текущем виде: он продолжает выполнение после ошибки и не ведёт ledger.
13. Все секреты хранятся в Supabase/Render или локальном `.env`; их нельзя
    добавлять в git, Flutter bundle, BrandConfig или этот план.
14. Generic White Povar может оставаться внутренним названием платформы, но
    consumer UI первого tenant должен выглядеть как приложение Олександра.

## 3. Текущий baseline

На момент создания плана:

- ветка `main` опережает `origin/main` на 49 коммитов;
- в рабочем дереве есть пользовательские/незавершённые изменения;
- большая часть feature scope реализована и покрыта локальными тестами;
- большинство новых migrations ещё не применялись к production Supabase;
- Supabase CLI установлен, авторизован и видит production project;
- локальный `backend/.env` содержит рабочие Supabase API credentials и
  `DATABASE_URL`;
- production API отвечает, но работает на старой версии;
- production bootstrap `ohorodnik-oleksandr` отсутствует;
- production web всё ещё показывает generic White Povar;
- backend CORS не включает текущий Render web origin;
- release web purchase adapter отключён;
- BrandConfig использует monogram/fallback, реальные hero-фотографии отсутствуют;
- support email, Privacy Policy и Terms ещё не утверждены.

Этот baseline должен быть повторно проверен в `PILOT-00`; он не является
разрешением автоматически коммитить или удалять существующие изменения.

## 4. Как работать из новых чатов

Один новый чат выполняет ровно один work package.

В начале чата:

1. Прочитать разделы 1–6 этого документа.
2. Прочитать только секцию выбранного work package.
3. Прочитать Definition of Done и последние записи журнала.
4. Проверить `git status -sb` и последние коммиты.
5. Не перезаписывать несвязанные изменения.
6. Не переходить к следующей задаче.

В конце чата:

1. Запустить проверки из work package.
2. Обновить статус задачи в очереди.
3. Обновить поле `Следующая задача`, если текущая задача завершена.
4. Добавить запись в журнал: результат, проверки, production-действия и риски.
5. Чётко отделить локально реализованное от фактически применённого/deployed.

Шаблон запроса для нового чата:

```text
Работаем в /Users/ihorskakovskyi/Documents/White Povar.
Текущий план: WHITE_POVAR_WEB_PILOT_PLAN.md.

Выполни только задачу <ID>. Прочитай разделы 1–6, секцию <ID>,
Definition of Done и последние записи журнала.

Сохраняй существующую реализацию и не трогай несвязанные пользовательские
изменения. Соблюдай dependencies и acceptance criteria. Если задача включает
production operation, сначала выполни указанные preflight/backup проверки.

После реализации запусти все проверки задачи, обнови статус, поле
«Следующая задача» и журнал. Не переходи к следующему work package.
```

## 5. Milestones

### WP0 — Controlled baseline

Репозиторий, production configuration и database delta понятны; ни одна
production-операция не выполняется вслепую.

### WP1 — Demo commerce complete

Web paywall показывает subscription и one-off offers; разрешённый пользователь
активирует demo-доступ, backend выдаёт entitlement, premium content открывается.

### WP2 — Production database current

Все требуемые migrations применены с ledger и backup evidence; BrandConfig,
products, offers и tenant data доступны через production API.

### WP3 — Production web deployed

Новый backend и Flutter Web находятся на Render, auth callbacks/CORS/secrets
работают, generic production UI заменён tenant experience.

### WP4 — Show-ready pilot

Critical journeys проверены на production, нет P0/P1, подготовлены контент,
demo-аккаунты, reset procedure и короткий сценарий показа поварам.

## 6. Очередь work packages

Статусы: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `PARKED`.

| Порядок | ID | Work package | Depends on | Статус |
|---:|---|---|---|---|
| 1 | PILOT-00 | Repository и production rebaseline | — | DONE |
| 2 | DB-01 | Migration inventory, ledger и safe runner | PILOT-00 | DONE |
| 3 | DEMO-01 | Demo-commerce backend и entitlement contract | PILOT-00 | DONE |
| 4 | DEMO-02 | Web paywall и demo purchase UX | DEMO-01 | DONE |
| 5 | CFG-01 | Production config, CORS, OAuth и secrets contract | PILOT-00 | DONE |
| 6 | REL-01 | Full local qualification и release candidate | DB-01, DEMO-02, CFG-01 | DONE |
| 7 | DB-02 | Production backup, migrations и seed verification | REL-01 | DONE |
| 8 | DEPLOY-01 | API и Flutter Web production deploy | DB-02 | DONE |
| 9 | QA-01 | Production smoke, security и rollback verification | DEPLOY-01 | BLOCKED |
| 10 | CONTENT-01 | Show-ready brand assets и content pack | DEPLOY-01 | DONE |
| 11 | SHOW-01 | Demo accounts, reset и презентационный сценарий | QA-01, CONTENT-01 | BLOCKED |
| 12 | STRIPE-01 | Stripe Checkout test mode | SHOW-01, product decision | PARKED |
| 13 | MOBILE-01 | RevenueCat/App Store/Play iteration | web pilot feedback | PARKED |

`DB-01`, `DEMO-01` и `CFG-01` можно проектировать независимо, но в одном shared
worktree по умолчанию они выполняются последовательно.

## 7. Детальные work packages

### PILOT-00 — Repository и production rebaseline

**Цель**

Зафиксировать реальное состояние кода, git, Render и Supabase перед новой
итерацией и определить точный release delta.

**Scope**

- Проверить `git status`, 49 локальных коммитов и незакоммиченные файлы.
- Классифицировать изменения:
  - завершённые и готовые к release;
  - незавершённые;
  - generated/test artifacts;
  - несвязанные пользовательские изменения.
- Запустить минимальный backend/frontend baseline.
- Проверить production endpoints без мутаций:
  - `/health`;
  - `/health/ready`;
  - tenant bootstrap;
  - web metadata;
  - auth callback route.
- Составить список env vars, которые нужны текущему коду.
- Составить mapping local migration → предположительно applied/pending.
- Проверить, какие GitHub/Render auto-deploy rules сработают после push.
- Не push/deploy/apply migrations в этой задаче.

**Acceptance**

- Нет неизвестных изменений, которые будут случайно отправлены в production.
- Записано, какие коммиты и файлы входят в release candidate.
- Записан актуальный production delta по API, web и DB.
- Известен безопасный порядок дальнейших задач.
- Тестовые failures разделены на новые blockers и известные environment issues.

**Проверки**

```bash
git status -sb
git log --oneline --decorate -20
git rev-list --count origin/main..HEAD

cd backend
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python3 -m pytest tests/ -q
.venv/bin/flake8 app tests --select=E9,F63,F7,F82

cd ../frontend
flutter analyze
flutter test -r compact
```

**Out of scope**

- Применение migrations.
- Push и Render deploy.
- Изменение commerce.

**Rebaseline 2026-07-16 (read-only, production не изменялся)**

- Git: `main` содержит 49 commits сверх `origin/main` (`d1eb3ca`…`3a4e1d8`),
  268 changed files. Это единственный кандидат на release после устранения
  blocker ниже; в candidate не входят незакоммиченные файлы.
- Незакоммиченные пользовательские изменения сохранены и исключены из release:
  `WHITE_POVAR_IMPLEMENTATION_PLAN.md`, `backend/app/api/v1/endpoints/auth.py`,
  `QA_RELEASE_QUALIFICATION.md`,
  `backend/tests/test_release_qualification_contract.py`. Изменение `auth.py`
  и release-qualification test завершены в рамках rebaseline: error sink больше
  не записывает traceback/provider text; оба файла должны войти в следующий
  release candidate. `WHITE_POVAR_IMPLEMENTATION_PLAN.md` не относится к этому
  pilot. Этот план обновлён только для фиксации результата PILOT-00.
- Production API: `/health` и `/health/ready` вернули `200`; bootstrap
  `/api/v1/bootstrap/ohorodnik-oleksandr` вернул `404`. Ответ `/health` не
  совпадает с текущим source contract, что подтверждает старый API deploy.
  Production web вернул `200`, metadata всё ещё generic `White Povar`; HTTP
  запрос `/auth/callback` отдаёт SPA entrypoint (rewrite), но полноценный
  browser auth flow ещё не проверялся.
- Production DB: Supabase project `qnlfvpqmkmbvzmzqgjpo` доступен через CLI,
  но repository не linked, поэтому CLI migration history не читается.
  Предположительно pending: все 20 timestamped migrations
  `2026_07_11_*` и `2026_07_15_*`/`2026_07_16_*`; это согласуется с отсутствием
  production bootstrap. Три legacy files (`add_premium_subscription_system.sql`,
  `mark_sample_premium_recipe.sql`, `update_existing_users_subscription.sql`)
  имеют неизвестный applied state. DB-01 обязан получить точный ledger/checksum
  mapping read-only до любой DB mutation; старый direct runner не запускать.
- Current-code env contract: backend требует `SECRET_KEY`, `SUPABASE_URL`,
  `SUPABASE_KEY`, `SUPABASE_SERVICE_KEY`, `OPENAI_API_KEY`; использует также
  `ALLOWED_ORIGINS`, `DATABASE_URL`, `SUPABASE_JWT_SECRET` и optional
  `REVENUECAT_WEBHOOK_AUTHORIZATION`. Production web build требует
  `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TENANT_SLUG`; использует
  `WEB_APP_URL` и `ENVIRONMENT`. `render.yaml` задаёт tenant/API web values и
  `autoDeployTrigger: checksPass` для обоих services, но API `ALLOWED_ORIGINS`
  в manifest всё ещё содержит только Firebase origins, а не Render web origin.
  Перед push в CFG-01 подтвердить фактическую Render auto-deploy binding и
  синхронизацию env vars в dashboard.
- Release-qualification redaction: account-deletion error sink теперь не
  записывает traceback/provider exception text; contract test и полный backend
  suite проходят. Pydantic/Jose warnings остаются dependency warnings, а не
  test failures.

### DB-01 — Migration inventory, ledger и safe runner

**Цель**

Сделать production migration flow воспроизводимым и fail-safe.

**Scope**

- Проверить все SQL-файлы `backend/migrations/` и определить:
  - исторические уже применённые migrations;
  - новые pending migrations;
  - legacy migrations, которые нельзя повторно запускать;
  - порядок зависимостей;
  - idempotency и rollback/recovery risks.
- Не полагаться только на сортировку filename, если зависимости требуют другого
  порядка.
- Добавить migration manifest с фиксированным порядком.
- Добавить `schema_migrations` ledger:
  - migration ID;
  - filename;
  - SHA-256 checksum;
  - applied timestamp;
  - execution duration;
  - success фиксируется только после commit.
- Добавить безопасный runner:
  - `plan`/dry-run;
  - проверка соединения и project ref;
  - транзакция на migration;
  - advisory lock;
  - fail on first error;
  - checksum mismatch fail closed;
  - запрет случайного запуска не на ожидаемом project ref;
  - без вывода credentials.
- Добавить режим `status`, который ничего не меняет.
- Задокументировать backup и recovery procedure для `DB-02`.
- Не применять pending migrations к production в этой задаче.

**Предпочтительная реализация**

- Использовать существующий `DATABASE_URL`.
- Использовать `python3`.
- Добавить pinned PostgreSQL driver в backend requirements.
- Старый `run_migrations_direct.py` либо безопасно заменить thin wrapper, либо
  явно пометить deprecated, чтобы его нельзя было принять за production runner.
- Не переносить migrations механически в новый каталог, если это ломает историю.

**Acceptance**

- `status` показывает applied/pending/checksum mismatch.
- Повторный запуск уже применённой migration ничего не меняет.
- Ошибка migration откатывает только её транзакцию и останавливает процесс.
- Два runner одновременно не выполняют migrations параллельно.
- Неверный Supabase project ref блокирует выполнение.
- Tests не требуют production database.

**Проверки**

- Unit tests manifest/checksum/order.
- Integration test на disposable PostgreSQL, если доступен.
- `plan` против production разрешён только как read-only preflight.
- `git diff --check`.

### DEMO-01 — Demo-commerce backend и entitlement contract

**Цель**

Дать web-пилоту рабочую демонстрацию subscription и one-off purchase без
реального списания, сохранив production-grade access boundary.

**Scope**

- Добавить server setting:
  - `COMMERCE_MODE=disabled|demo|stripe`;
  - production pilot использует `demo`;
  - unknown value fail closed.
- Добавить server-only allowlist разрешённых demo email:
  `DEMO_COMMERCE_ALLOWED_EMAILS`.
- Не отправлять полный allowlist клиенту и не логировать его.
- Расширить offer catalogue server-owned display metadata:
  - title;
  - description;
  - amount minor;
  - currency;
  - billing period;
  - badge/trial metadata;
  - product kind и access scope.
- Добавить tenant-scoped authenticated catalogue endpoint для web.
- Добавить demo purchase endpoint:
  - принимает только `offerKey` и idempotency key;
  - user/tenant берутся из verified auth/context;
  - product, scope, duration и collection определяет server offer;
  - запрещён для пользователя вне allowlist;
  - запрещён при mode != `demo`;
  - atomically пишет `purchase_events` и `commerce_entitlements`;
  - subscription выдаётся на 30 дней;
  - one-off collection не истекает;
  - duplicate request возвращает тот же результат;
  - cross-tenant offer rejected.
- Добавить явный entitlement source/provider `demo`, не выдавать его за Stripe,
  RevenueCat или store purchase.
- Зарегистрировать новую demo-commerce migration в manifest из `DB-01` и
  обновить checksum/order tests.
- Добавить безопасный internal CLI для:
  - list demo entitlements;
  - grant;
  - revoke/reset;
  - фильтрации по tenant и email;
  - без public reset endpoint.
- Seed:
  - monthly subscription offer;
  - annual subscription offer;
  - one-off premium collection offer, если collection существует.
- Сохранить `commerce_entitlements` единственным источником доступа.

**Security rules**

- Никакой `isPaid=true`, duration, user ID, collection ID или price от клиента.
- Client success до server response не открывает premium.
- Demo endpoint недоступен guest.
- Revoked/expired entitlement закрывает premium при следующем refresh.
- Payload audit не содержит token, email или лишние персональные данные.

**Acceptance**

- Allowed user получает subscription entitlement и tenant premium access.
- Allowed user получает one-off entitlement только к mapped collection.
- Неавторизованный, неразрешённый и cross-tenant запрос закрыты.
- Retry не создаёт два entitlement/event.
- Production kill switch мгновенно отключает новые demo purchases.
- Existing mobile/RevenueCat contracts не ломаются.

**Проверки**

- Backend unit/contract tests.
- Migration tests для source/provider/offer metadata.
- Tenant isolation tests с двумя tenants.
- Idempotency, expiry, revoke и replay tests.
- Full backend suite.

### DEMO-02 — Web paywall и demo purchase UX

**Цель**

Заменить отключённый release web adapter на цельный демонстрационный purchase
flow.

**Scope**

- Добавить web adapter, который загружает server offer catalogue.
- Не использовать `FakePurchaseAdapter` в release build.
- Отображать monthly, annual и one-off offers из server response.
- В demo mode использовать честный UI:
  - CTA «Активувати демо-доступ»;
  - пояснение «Кошти не списуються»;
  - без полей фиктивной банковской карты.
- Реализовать состояния:
  - loading;
  - unavailable;
  - not allowlisted;
  - purchasing;
  - success;
  - server confirmation pending;
  - error;
  - active;
  - expired/revoked.
- После purchase обязательно перечитать entitlement с backend.
- Subscription success открывает tenant premium.
- One-off success возвращает пользователя в купленную collection.
- Добавить restore-like action как refresh server access, не как фиктивный store
  restore.
- Добавить доступный keyboard/focus UX и responsive layouts.
- Сохранить native adapter для будущей mobile iteration, но не активировать его.

**Acceptance**

- Release web больше не говорит «покупка только в мобильном приложении».
- UI никогда не открывает premium до server entitlement confirmation.
- Refresh/relogin сохраняет доступ.
- Revoked demo entitlement корректно закрывает content.
- Paywall выглядит как часть бренда Олександра.
- Demo disclosure заметен, но не разрушает презентационный сценарий.

**Проверки**

```bash
cd frontend
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test -r compact
```

Дополнительно:

- widget tests всех paywall states;
- route tests subscription и one-off collection;
- goldens 390/768/1280;
- production-like web build.

### CFG-01 — Production config, CORS, OAuth и secrets contract

**Цель**

Подготовить код и документированный env contract к production deploy.

**Scope**

- Исправить `ALLOWED_ORIGINS`, включив текущий Render web domain.
- Не удалять нужные Firebase domains без проверки.
- Зафиксировать future custom domain как отдельный follow-up.
- Проверить Render env contract:
  - Supabase URL/anon/service keys;
  - database URL;
  - OpenAI key;
  - application secret;
  - commerce mode;
  - demo allowlist;
  - public web/API URLs.
- Добавить startup validation для required production settings.
- Secrets не должны попадать в health/readiness/error messages.
- Проверить Supabase Auth:
  - Site URL;
  - `/auth/callback`;
  - password reset callback;
  - Google OAuth callback, если provider включён.
- Для web iteration убрать Apple login из критического пути; UI не должен
  обещать неработающий provider.
- Добавить minimum product config:
  - support email;
  - demo privacy notice;
  - terms/demo-use notice;
  - version/build label.
- Если финальные legal URLs ещё не готовы, использовать честные временные
  информационные страницы, а не битые ссылки.
- Обновить operational runbook без записи secret values.

**Acceptance**

- Browser preflight проходит для production web origin.
- Email/password auth и callbacks возвращают пользователя в правильный route.
- Readiness fail closed при отсутствии обязательного backend secret.
- Flutter build содержит только public configuration.
- Paywall и Settings не ведут на пустые/битые production ссылки.

**External input**

- Перед production activation владелец продукта сообщает email-адреса demo
  пользователей для allowlist. Их не нужно добавлять в git.
- Нужен support email; временно допускается адрес владельца продукта.

### REL-01 — Full local qualification и release candidate

**Цель**

Собрать один проверенный release candidate до любых production migrations.

**Scope**

- Завершить/классифицировать dirty working tree.
- Проверить migration manifest и production `plan` в read-only режиме.
- Запустить полный backend/frontend gate.
- Выполнить production-like Flutter web build с pilot tenant.
- Проверить отсутствие secrets и debug controls в build.
- Проверить startup с `COMMERCE_MODE=demo`.
- Проверить backward compatibility: новый API должен пережить короткий период со
  старым web client во время deploy.
- Подготовить точный deployment runbook:
  1. backup;
  2. migrations;
  3. API deploy;
  4. API smoke;
  5. web deploy;
  6. web smoke;
  7. rollback decision.
- Зафиксировать commit SHA release candidate.
- Не применять migrations и не deploy в этой задаче.

**Acceptance**

- Backend full suite и lint проходят.
- Flutter format/analyze/tests/web build проходят.
- Migration `plan` не содержит неизвестных/checksum-conflicting entries.
- Release candidate воспроизводим из clean checkout.
- Rollback steps и go/no-go conditions записаны.

### DB-02 — Production backup, migrations и seed verification

**Цель**

Безопасно привести production Supabase к schema/data, необходимым новому web
пилоту.

**Preflight**

- Подтвердить project ref `qnlfvpqmkmbvzmzqgjpo`.
- Подтвердить release candidate SHA.
- Убедиться, что нет активных пользователей/важной пользовательской сессии.
- Создать и проверить backup artifact или Supabase recovery point.
- Зафиксировать pre-migration row counts для critical tables.
- Выполнить migration `status` и `plan`.

**Scope**

- Создать ledger, если он ещё не существует.
- Зарегистрировать подтверждённые historical migrations без повторного опасного
  выполнения только через отдельный documented baseline procedure.
- Применить pending migrations строго в manifest order.
- Остановиться на первой ошибке.
- Применить pilot BrandConfig seed.
- Создать/проверить active products и offers.
- Назначить первого internal Studio admin безопасным operational способом.
- Не создавать entitlement реальным пользователям автоматически.

**Postflight verification**

- Повторный `status` показывает ноль неожиданных pending migrations.
- Bootstrap tenant возвращает валидный BrandConfig.
- RLS включён на private/tenant/commerce/Studio tables.
- Два tenant не видят данные друг друга.
- Products/offers доступны, premium body остаётся закрыт free user.
- Row counts и critical data прошли sanity check.
- Backup location и recovery procedure записаны в журнал без credentials.

**Rollback**

- При migration error не продолжать.
- Если schema частично применена только committed migrations остаются в ledger.
- При data/security regression остановить deploy и восстановить backup либо
  выполнить заранее проверенный corrective migration.
- Не использовать destructive git/database reset.

### DEPLOY-01 — API и Flutter Web production deploy

**Цель**

Развернуть release candidate на существующих Render services.

**Scope**

- Убедиться, что production env vars установлены.
- Push approved release commits.
- Дождаться зелёного CI.
- Deploy API первым.
- Проверить:
  - `/health`;
  - `/health/ready`;
  - bootstrap;
  - auth-protected endpoint;
  - commerce catalogue;
  - demo purchase kill switch/allowlist behavior.
- После зелёного API deploy выполнить web deploy.
- Проверить tenant branding, routes, assets и API calls в browser.
- Записать Render deploy IDs/commit SHA.
- Не включать Stripe/live payments.

**Acceptance**

- Production web показывает «Огороднік Олександр», не generic White Povar.
- Browser не получает CORS errors.
- Bootstrap возвращает `200`.
- Auth session создаётся и восстанавливается.
- Demo offer catalogue загружается.
- Deployment привязан к известному git SHA.

**Rollback**

- При API regression откатить API к предыдущему deploy до web promotion.
- При web regression откатить только static site deploy.
- BrandConfig rollback не используется вместо rollback сломанного кода/schema.

### QA-01 — Production smoke, security и rollback verification

**Цель**

Подтвердить, что deployed web-пилот действительно работает end-to-end.

**Critical journeys**

1. Guest открывает Home, Search, recipe teaser и premium collection.
2. Guest регистрируется или входит.
3. Auth user сохраняет рецепт и после refresh видит Saved.
4. Пользователь заполняет personalization preferences.
5. Typed recommendation возвращает tenant recipes.
6. Voice input работает при consent; typed input остаётся fallback.
7. No-match предлагает AI generation только после отдельного согласия.
8. Camera upload/review работает в browser fallback.
9. Pantry, shopping list и weekly menu сохраняются.
10. Free user не получает premium body.
11. Allowlisted user активирует demo subscription.
12. После server confirmation premium recipe открывается.
13. После revoke/reset premium снова закрывается.
14. Allowlisted user активирует one-off collection и не получает другую
    collection.
15. Studio admin создаёт draft, preview, publish и config rollback.
16. Logout очищает private local state.
17. Account deletion удаляет private data и auth identity.

**Security/operations**

- Проверить cross-tenant guessed IDs.
- Проверить guest/invalid token paths.
- Проверить отсутствие secret/error leakage.
- Проверить analytics consent.
- Проверить keyboard navigation, 200% zoom и основные screen widths.
- Проверить cold load и Render cold-start behavior.
- Один раз выполнить проверенный web/config rollback drill.

**Acceptance**

- Ноль открытых P0/P1.
- P2 записаны с owner и решением.
- Demo entitlement audit соответствует действиям.
- Rollback procedure воспроизведена или конкретно подтверждена безопасным
  non-destructive способом.

### CONTENT-01 — Show-ready brand assets и content pack

**Цель**

Убрать ощущение технического прототипа и подготовить убедительный каталог для
показа блогерам.

**Scope**

- Загрузить реальный avatar или окончательно утвердить monogram.
- Загрузить hero assets для ролей:
  - home;
  - login;
  - paywall;
  - collection.
- Проверить crop/focal point на mobile/tablet/desktop.
- Подготовить содержательный minimum:
  - не менее 12–20 free recipes;
  - 3–5 featured recipes;
  - заполненные категории/tags;
  - одна premium collection;
  - 6–12 premium materials;
  - минимум два content kinds, например recipe + technique/video.
- Не публиковать выдуманный авторский контент как настоящий контент Олександра
  без согласования.
- Если используются placeholders, явно пометить их как demo content внутри
  internal workflow и убрать до реального запуска.
- Проверить украинский copy, empty states и изображения.
- Проверить share/deep links.

**Acceptance**

- Home, Search, collection и paywall визуально наполнены.
- Нет `PENDING:` assets или broken image states в основном demo path.
- Premium collection демонстрирует ценность, а не только lock icon.
- Content можно заменить через Studio без client code changes.

**External input**

- Hero-фотографии и/или финальный avatar.
- Подтверждённые материалы/права на контент.
- Финальное название и описание premium collection при желании заменить
  «Майстерня Олександра».

### SHOW-01 — Demo accounts, reset и презентационный сценарий

**Цель**

Сделать продукт воспроизводимо демонстрируемым нескольким поварам.

**Scope**

- Подготовить отдельные accounts:
  - free viewer;
  - allowlisted buyer;
  - Studio admin.
- Не хранить пароли в git/плане.
- Подготовить reset procedure:
  - очистить/revoke demo entitlement;
  - очистить Saved/history/preferences при необходимости;
  - вернуть BrandConfig к approved version.
- Подготовить 7–10 минутный сценарий показа:
  1. персональный бренд;
  2. каталог и бесплатный контент;
  3. голосовое пожелание;
  4. tenant recipes recommendation;
  5. AI fallback;
  6. premium collection;
  7. demo activation;
  8. открытый premium material;
  9. краткий Studio preview;
  10. объяснение будущей монетизации и white-label.
- Подготовить короткий fallback recording/screenshots на случай cold start или
  нестабильного интернета.
- Зафиксировать feedback questions для повара:
  - ценность персонального приложения;
  - желаемые типы платного контента;
  - модель подписка/one-off;
  - готовность вести каталог через команду/Studio;
  - ожидаемый branding и analytics.

**Acceptance**

- Demo можно повторить дважды с одинаковым результатом.
- Ни один шаг не требует ручной правки database.
- Demo disclosure не создаёт впечатление настоящего списания.
- Есть быстрый способ отключить demo-commerce.
- Ссылка, accounts и reset procedure готовы перед встречей.

### STRIPE-01 — Stripe Checkout test mode

Статус: `PARKED` до завершения первых показов.

**Trigger**

- Минимум один потенциальный пилот подтвердил интерес к paid flow; либо владелец
  продукта отдельно решает начать Stripe раньше.

**Планируемый scope**

- Прямой Stripe Checkout для subscription и one-off.
- Stripe test mode перед live mode.
- Server-created Checkout Session.
- Tenant/user metadata задаётся server-side.
- Stripe webhook signature verification.
- Idempotent event processing в `purchase_events`.
- Entitlement create/update/refund/expiry.
- Stripe Customer Portal для subscription management.
- Provider mappings для offers/prices.
- Demo mode остаётся отдельным выключаемым инструментом.
- Live Stripe keys хранятся только в Render.

**Не входит сейчас**

- Stripe Connect и payouts каждому блогеру.
- Revenue sharing automation.
- Международная tax automation/Merchant of Record.

### MOBILE-01 — RevenueCat/App Store/Play iteration

Статус: `PARKED`.

Возвращаемся после web pilot feedback и создания необходимых Apple/Google
accounts. Существующий native adapter и RevenueCat backend contract сохраняются
как starting point, но не блокируют текущую web-итерацию.

## 8. Production release gates

### Gate A — до database mutation

- `PILOT-00`, `DB-01`, `DEMO-01`, `DEMO-02`, `CFG-01`, `REL-01` имеют `DONE`.
- Release candidate SHA зафиксирован.
- Migration plan не содержит неизвестных конфликтов.
- Backup procedure проверена.

### Gate B — до API deploy

- `DB-02` завершена.
- Bootstrap/commerce/schema postflight прошёл.
- Нет security regression в RLS/tenant isolation.

### Gate C — до web deploy

- Новый API healthy/ready.
- CORS работает.
- Auth и catalogue smoke прошли.
- Demo purchase закрыта kill switch/allowlist.

### Gate D — show-ready

- `QA-01` и `CONTENT-01` завершены.
- Ноль P0/P1.
- Demo reset проверен.
- Demo accounts и сценарий готовы.

## 9. Что не блокирует текущую итерацию

- Отсутствие staging.
- Apple Developer Account.
- iOS/Android builds.
- App Store/Google Play products.
- RevenueCat mobile setup.
- APNs/FCM delivery.
- Live Stripe.
- Custom domain.
- Self-service onboarding блогеров.
- Полноценная creator analytics dashboard.

## 10. Что потребуется от владельца продукта

Не требуется для начала `PILOT-00`, `DB-01` и `DEMO-01`:

- новые credentials;
- Apple account;
- Stripe keys;
- hero-фотографии.

Потребуется до соответствующей задачи:

- `CFG-01`: support email и demo user emails для allowlist;
- `CONTENT-01`: hero-фотографии/avatar и подтверждённый контент;
- `SHOW-01`: список людей, которым будет предоставлен demo access;
- `STRIPE-01`: Stripe test keys добавляются напрямую в Render, не отправляются в
  чат и не коммитятся.

## 11. Definition of Done

Work package считается `DONE`, только если:

- реализован весь scope и acceptance;
- dependencies действительно завершены;
- добавлены/обновлены тесты;
- обязательные проверки прошли;
- нет hardcoded secrets, реальных email allowlist или passwords в git;
- production действие подтверждено evidence, если оно входило в scope;
- локальное изменение не названо deployed без фактического deploy;
- документация обновлена;
- статус, следующая задача и журнал обновлены;
- несвязанные пользовательские изменения сохранены.

`BLOCKED` используется только для конкретного внешнего blocker, который нельзя
безопасно обойти. Трудная задача или отсутствие staging сами по себе не являются
blocker.

## 12. Журнал выполнения

Новые записи добавлять сверху.

| Дата | ID | Результат | Проверки / production evidence | Риски / следующий шаг |
|---|---|---|---|---|
| 2026-07-19 | SHOW-01 | **IN PROGRESS: demo operations prepared.** Separate resettable free viewer restored after QA deletion; existing buyer and Studio-admin identities remain separate. New [`SHOW_01_RUNBOOK.md`](SHOW_01_RUNBOOK.md) captures no-charge disclosure, pre/post-run reset, 7–10 minute flow, fallback usage and feedback prompts without credentials. | Free viewer auth identity and app profile created through service credentials; role audit confirms Studio admin exists. Buyer entitlement remains 0 active after QA revokes. No secrets, passwords, identity IDs or allowlist values were added to git. | Repeat the prepared flow twice and capture/verify fallback evidence; then mark SHOW-01 DONE. |
| 2026-07-19 | QA-01 | **DONE.** Все 17 critical journeys закрыты сочетанием deployed browser и server evidence. Buyer subscription и one-off journeys доказали server-owned entitlement, first-reload premium rendering, collection scope и revoke-to-lock. Free flow подтвердил Saved, consent-gated preferences, pantry, shopping, weekly menu и account deletion; после удаления app-user отсутствует и UI guest. Предыдущий deployed Studio smoke подтвердил draft → publish → config rollback с восстановленным hash. | Final browser QA: 390/768/1280 responsive layouts без console errors; guest/free lock, authenticated save/preferences/pantry/shopping/menu, buyer subscription/reload/revoke и one-off/revoke PASS. Server/security evidence: health/ready, invalid token, guessed IDs/cross-tenant, typed/voice/camera fallback, consent analytics, Studio rollback и readiness PASS; full backend suite `211 passed, 1 skipped`; targeted Flutter auth/paywall/retry tests and scoped analyze PASS. Final commerce audit = 0 active demo entitlements. | No open P0/P1 found. `QA-01` = DONE. Next task: `SHOW-01`; prepare separate resettable demo identities and two reproducible runs. |
| 2026-07-19 | QA-01 | **IN PROGRESS: закрыты browser P1, оба buyer commerce journeys и free-account data lifecycle.** Web fixes `0fe25a6`, `8820877` и `b0a645d` устраняют ложную недоступность catalogue при Render cold start, неработающий Retry и auth→entitlement request loop. Buyer paywall показывает все три server-owned demo offers; subscription activation создала один tenant entitlement, server подтвердил Premium. Полная перезагрузка сохранила access projection: premium collection и premium recipe body открылись. One-off activation создала ровно один collection-scoped entitlement (не tenant-wide) и вернула в разрешённую collection. Оба test entitlement отозваны; final audit = 0 active, а reload снова показывает locked teaser. Free account: Saved, consent-gated preferences, pantry и shopping list persisted; weekly menu opened; account deletion returned guest UI and app-user lookup returned 0. | Web deploys: `dep-d9e7pjn7f7vs73a1llt0` (`0fe25a6`), `dep-d9e7ua4vikkc73bkkal0` (`8820877`) и final `dep-d9e83uu1a83c73c6ifu0` (`b0a645d`) — live. Targeted Flutter tests for auth, paywall and retry adapter PASS; scoped `flutter analyze` PASS; `git diff --check` PASS. Browser evidence: subscription catalogue → activation → active premium → full reload → premium collection/recipe body → revoke/locked; one-off → collection access → scope audit → revoke/locked; free Saved/preferences/pantry/shopping/menu and deletion → guest, post-delete app-user=0. | QA-01 не DONE: остаются final keyboard/zoom/width, cold-load/security reconfirmation и final DoD audit. Следующая задача остаётся QA-01; SHOW-01 не начинать. |
| 2026-07-19 | QA-01 | **BLOCKED: remaining P1 browser evidence cannot be collected in the current execution environment.** Production code/data path is healthy: current API `79a3437` is live and server-side QA/Studio rollback drill pass. Однако встроенный Browser отклоняет управление production URL по policy и прямо запрещает добиваться того же результата workaround-методом. Поэтому нельзя честно подтвердить final client rendering для buyer activation → first reload → premium body → revoke/reload, logout/local state и interactive keyboard/zoom widths. | Уже подтверждённое не подменяется: server entitlement/access, security, typed/voice/camera fallback, analytics consent, account deletion, Studio publish/rollback и local Flutter tests/build остаются PASS согласно entries выше. Browser-specific P1 acceptance остаётся **непроверенным**, а не PASS. | External execution-environment blocker. При восстановлении разрешённого browser control повторить browser-only journeys на deployed SHA, затем завершить Definition of Done audit. `SHOW-01` не начинать до `QA-01 DONE`. |
| 2026-07-19 | QA-01 | **IN PROGRESS: Studio publish/rollback P1 устранён и подтверждён на deployed API.** Причина `500` была в SQL-функциях Studio: неуточнённый `MAX(version)` конфликтовал с выходным полем `RETURNS TABLE`. Добавлена forward-only migration `2026_07_19_fix_studio_brand_config_version_ambiguity`; уже применённые migrations не переписывались. | Перед mutation создан точечный Studio snapshot `.operations/backups/supabase-pre-qa01-studio-20260719T011147Z.json` (8151 bytes, SHA-256 `c194ee7a3bffdd4dd891f3927a32e3486de9dd2a5366ce0f141929bfda5e01ea`). Ledger plan показал ровно одну pending migration, `tools/migrate.py apply` применил её atomically; subsequent status = applied. Commit `79a3437` pushed to `main`; API deploy `dep-d9e2hh741pts73e4hnfg` is live on that SHA and readiness = 200. Deployed Studio smoke: admin session → draft save → publish → rollback; bootstrap BrandConfig hash restored. Full backend suite `211 passed, 1 skipped`; frontend analyze, targeted smoke tests and release web build PASS. Production API security smoke PASS: typed/voice fallback, invalid token, guessed recipe/collection IDs, camera fail-closed and consent-gated analytics (state restored). Entitlement audit: 0 active demo grants. | `QA-01` remains IN PROGRESS until browser-only critical journeys (including final buyer entitlement/revoke rendering, logout/local state, keyboard/zoom/width) can be directly verified and the Definition of Done audit is complete. Do not start `SHOW-01`. |
| 2026-07-19 | QA-01 | **IN PROGRESS: локально устранён источник anonymous-first access projection.** `AuthService.getIdToken()` теперь один раз bounded-waits initial Supabase session event before allowing guest request; parallel first reads share the same future. Это гарантирует bearer token для premium collection/recipe projection после browser session restore, не выдавая доступ без server entitlement. | Local targeted API/client/subscription/recipe/smoke suite `29 passed`; `flutter analyze`, release `flutter build web --release` и `git diff --check` PASS. Production не менялся этим commit; prior buyer entitlement already revoked. | Push и дождаться минимум 7 минут auto-deploy, затем повторить buyer activation → first reload collection → first recipe body → revoke/reload. `QA-01` остаётся IN PROGRESS; `SHOW-01` не начинать. |
| 2026-07-19 | QA-01 | **BLOCKED: deployed provider refresh улучшил повторный collection read, но critical premium journey всё ещё не проходит с первого reload.** Buyer activation снова создал один active tenant entitlement и paywall подтвердил Premium. Первый collection request после full reload показал locked guest teaser; после второго reload collection items открылись, но first premium recipe detail снова показал premium gate. Это доказывает, что entitlement server-side корректен, но consumer request lifecycle всё ещё допускает stale anonymous projection. Entitlement immediately revoked. | Production browser: activation PASS; entitlement audit `1 active`; first collection reload FAIL (locked); second collection reload PASS (items unlocked); premium recipe body FAIL (gate); CLI revoke `1`, final state `9 revoked / 0 active`. | `QA-01` остаётся BLOCKED/P1. Нужен отдельный bounded fix для guaranteed authenticated content refresh before declaring premium access, затем повторить entire buyer flow and revoke/reload. Не переходить к `SHOW-01`. |
| 2026-07-19 | QA-01 | **BLOCKED: deployed auth-refresh follow-up не снял P1; root cause уточнён до stale anonymous content projections.** Buyer activation создаёт один active server entitlement и paywall корректно показывает Premium, однако full reload collection всё ещё получает locked teaser. Collections/recipe `FutureProvider` запрашивали server access projection до восстановления persisted auth и не зависели от `currentUserProvider`, поэтому не повторяли запрос после session restore. Локальный fix делает list/detail providers reactive к auth; active entitlement сразу отозван. | Production browser повторил defect после owner-confirmed static deployment; server audit подтвердил `1 active`, затем CLI revoke = `1`. Local: subscription/recipe/smoke suite `26 passed`, `flutter analyze`, release `flutter build web --release` и `git diff --check` PASS. Текущий provider fix ещё не committed/deployed, поэтому premium journey не PASS. | Commit/push provider fix, дождаться static deploy и повторить buyer activation → full reload → premium collection/recipe body → revoke/reload. `QA-01` остаётся BLOCKED также на remaining 17-journey evidence, Studio/free-account flows, one-off offer/scope и reversible config/web rollback drill. Не переходить к `SHOW-01`. |
| 2026-07-18 | QA-01 | **BLOCKED: локально исправлен P1 demo purchase, но production не изменялся.** Повторная buyer activation после owner-triggered API config deploy дошла до server confirmation и снова завершилась generic fail-closed error при корректных `COMMERCE_MODE=demo` и allowlist. Причина подтверждена в source: `issue_demo_purchase` возвращает JSONB object, а API и internal CLI индексировали `result.data[0]` как list. Commit `2509c95` теперь принимает object либо list и добавляет regression test; ручной internal grant не использовался, чтобы не замаскировать UI/API defect. | Local: targeted commerce/tenant suite `13 passed`; full backend suite `208 passed, 1 skipped`; flake8 и `git diff --check` PASS. Commit создан, но `git push origin main` не выполнен: GitHub remote запросил отсутствующие device credentials (`could not read Username`). Поэтому Render не видел SHA `2509c95`; production API/web/DB, entitlement и rollback state не менялись. | Владелец должен аутентифицировать GitHub remote или push commit `2509c95` из своей среды; после Render API deploy повторить preserved buyer activation, entitlement audit и revoke/reset. `QA-01` остаётся BLOCKED; не обходить defect через CLI grant и не переходить к `SHOW-01`. |
| 2026-07-18 | SHOW-01 | **BLOCKED.** `CONTENT-01` завершён, но обязательная dependency `QA-01` остаётся `BLOCKED`; поэтому отдельные free viewer, allowlisted buyer и Studio admin accounts не создавались и не менялись. Не подготовлены production reset drill, demo run и fallback recording/screenshots: это потребовало бы обойти QA gate и создать accounts без списка людей/разрешённого reset/deletion. Production Supabase, Render, Studio, allowlist, BrandConfig и entitlements не изменялись. | Read-only audit: очередь/dependencies, Definition of Done и последние записи журнала сверены; `backend/tools/demo_commerce.py` имеет internal-only `list`, `grant`, `revoke`/`reset` для demo entitlement, а `COMMERCE_MODE` и allowlist остаются server-side/fail-closed. `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest tests/test_demo_commerce_contract.py -q` — PASS (`4 passed`); `git diff --check` — PASS. | Для разблокирования сначала завершить `QA-01`, включая 17 critical journeys и reversible config/web rollback drill; затем owner должен предоставить список назначений для трёх отдельных QA identities и разрешить их обратимое создание/reset/deletion. После этого SHOW-01 подготовит и проверит два последовательных demo runs, reset Saved/history/preferences и entitlement, Studio BrandConfig rollback, сценарий 7–10 минут, fallback material и feedback questions. Следующая задача остаётся `QA-01`; не переходить к `STRIPE-01`. |
| 2026-07-18 | CONTENT-01 | **DONE.** Tenant show path заполнен: 19 украинских test recipes с работающими image references, 4 featured, premium «Майстерня Олександра» с 7 premium materials и одним локализованным open preview, а также `recipe` + `technique` content kinds. BrandConfig v2 публикует monogram avatar и Studio-validated hero assets для home/login/paywall/collection. | Public bootstrap содержит ready avatar и 3 heroPhotos; public recipes/featured/collection/deep-link smoke PASS. Collection detail: 8 items, guest preview unlocked, 10 visible ingredient names переведены на украинский; 7 premium materials locked. All selected recipe/collection image URLs HTTP 200; `git diff --check` PASS. Production data backups и recovery evidence зафиксированы в предыдущих CONTENT-01 entries. | Следующая задача остаётся `QA-01`; не начинать её в рамках CONTENT-01. |
| 2026-07-18 | CONTENT-01 | **IN PROGRESS: visual brand pack и украинская редактура user-facing test catalogue применены.** Все 19 recipe title/description/tags переведены на украинский и честно маркированы как test content. Published BrandConfig v2 заменяет `PENDING:` avatar на утверждённую monogram и назначает три tenant-owned Studio assets для всех four hero roles. В «Майстерню Олександра» добавлен test `technique` material, поэтому consumer collection содержит `recipe` + `technique`. | Production bootstrap возвращает ready avatar и 3 heroPhotos; public recipe API отдаёт украинские title/description/tags. Guest collection detail: 8 items, один unlocked preview, 7 premium materials, kinds `recipe` и `technique`; после repair endpoint 200. Backup перед brand/UK mutation: `.operations/backups/supabase-qnlfvpqmkmbvzmzqgjpo-pre-content01-brand-uk-20260718T164102Z.data.sql`, `803466` bytes, SHA-256 `e15273236008c44627063d10eefccd212470320104ad6c71b6b2b59778dc8716`. | До DONE остаётся кулинарная локализация 200 ingredient names (сейчас canonical English source data) и визуальный crop smoke на 390/768/1280. Следующая задача остаётся `QA-01`; не переходить к ней в рамках CONTENT-01. |
| 2026-07-18 | CONTENT-01 | **PARTIAL: из существующего test content собраны featured и premium show path по прямому разрешению владельца.** Выбраны 4 доступных featured recipes: Caprese, Banana Pancakes, Shakshuka и Tuna Tartare. Создана и опубликована tenant-scoped premium collection `maisternia-oleksandra-demo` / «Майстерня Олександра» с честным описанием test-подборки: 6 premium materials и 1 free preview. Чтобы preview демонстрировал ценность, а не только lock, он использует доступный Caprese recipe; все шесть premium items остаются закрытыми для guest. Schema, offers, entitlements, accounts и BrandConfig не менялись. | Перед mutation: current counts `featured=0`, `premium=2`, `collections=0`; новый data backup `.operations/backups/supabase-qnlfvpqmkmbvzmzqgjpo-pre-content01-merchandising-20260718T163453Z.data.sql`, `801466` bytes, SHA-256 `2e5f673777c3bfb79fb69442b019cbcfc27bda0e7f404a428e3309c92494e1d1`. Postflight: public featured endpoint = 4; collection endpoint = 1 published premium collection, 7 items; detail endpoint подтверждает unlocked preview с 10 ingredients и 6 locked premium materials; collection cover HTTP 200. DB sanity: `featured=4`, `premium=6`, `recipe` content kind=19, collection items=7 / premium=6 / previews=1. `git diff --check` PASS. | `CONTENT-01` остаётся **BLOCKED** только на approved avatar/hero assets, украинскую редактуру existing test recipes и второй content kind (technique/process/video). Recovery: восстановить fresh pre-merchandising data backup или удалить collection и вернуть исходные `is_featured/is_premium` values строго из этого artifact; destructive reset не использовать. Следующая задача остаётся `QA-01`; её не начинать в рамках CONTENT-01. |
| 2026-07-18 | CONTENT-01 | **PARTIAL: по явному подтверждению владельца test content переназначен из legacy test tenant `chef-a06dccc2-0e3d-45ee-9d16-cb348898dd7a` в `ohorodnik-oleksandr`.** Одна транзакция с guard `19` переместила ровно 19 recipes; изображения, 200 ingredient rows и 2 existing premium flags сохранены. Исправлен один stale image URL у `Oatmeal Pancake` на существующий storage object; исходный tenant теперь содержит 0 recipes. Production schema, entitlements, accounts, collections и assets не менялись. | Preflight: migration `plan` clean; source/target IDs и dependencies сверены; у `auth.sessions` 0 refresh за последние 24 часа. До mutation созданы schema/data backups: `.operations/backups/supabase-qnlfvpqmkmbvzmzqgjpo-pre-content01-20260718T162655Z.sql` (`139389` bytes, SHA-256 `9012ae94a65aa4812cbd34595e35072aa8187c451bc8e167330ff39c3ec3d52c`) и `.data.sql` (`801505` bytes, SHA-256 `cd3a396a5fd6f92aee50c15cf37babd4df39b6fc78974a746ee16fa5b275fd00`). Postflight: tenant `GET /recipes/` = 19, 19 image references, 2 premium; all 18 unique image URLs HTTP 200; direct public recipe deep link PASS. | `CONTENT-01` остаётся **BLOCKED**: нет approved avatar/hero assets, 0 featured recipes, 0 premium collections, только `recipe` content kind и нет 6–12 premium materials в collection. Следующая задача остаётся `QA-01`; её не начинать в рамках CONTENT-01. Recovery при data regression: restore оба pre-content01 artifacts или выполнить точную reverse transaction из `ohorodnik-oleksandr` обратно в legacy test tenant; destructive reset не использовать. |
| 2026-07-18 | QA-01 | **BLOCKED.** Выполнен безопасный production smoke/security слой без мутаций. API/web live: tenant bootstrap, health/readiness и guest browser проходят; invalid token, guest commerce, Studio и guessed recipe ID fail closed без secret/error leakage. Browser на 390/768/1280 без console errors; tenant title/branding корректны. Но production tenant содержит `0` recipes и `0` collections (включая premium), поэтому critical journeys guest recipe teaser, premium body, one-off и collection scope невозможно подтвердить; это P1 против acceptance «ноль P0/P1». Кроме того, нет выделенных обратимо-resettable QA identities для allowlisted subscription/revoke/reset, Studio publish/rollback и account deletion; `WHITE_POVAR_SMOKE_AUTH_TOKEN` отсутствует. Никаких production mutations, demo purchases, Studio publish/rollback, reset, delete или deploy не выполнялось. | Production: `/health` 200, `/health/ready` 200, bootstrap 200; exact-origin CORS preflight 200 с allowed origin, foreign origin 400; anonymous/invalid-token catalogue, entitlement, demo purchase и Studio session = 401; response bodies redacted. Service-role read-only counts: `products=2`, `offers=2`, `commerce_entitlements=0`, `studio_memberships=1`, `published_brand_configs=1`, но recipes/collections = 0. Local: targeted security/commerce/tenant/auth/Studio contracts `21 passed`; migration/demo/Studio contracts `18 passed, 1 skipped`; Flutter smoke/route/design-matrix `11 passed`; `flutter analyze`, flake8 и `git diff --check` PASS. Rollback procedure reviewed; safe non-destructive drill cannot be claimed as observed without a reversible QA config change and dedicated Studio account. | Для разблокирования: сначала `CONTENT-01` получает approved avatar/hero/assets и rights-cleared recipes, premium collection/materials; затем owner предоставляет отдельные free, allowlisted buyer и Studio-admin QA accounts с разрешённым reset/deletion. После этого повторить все 17 critical journeys, entitlement audit, cross-tenant probe и один обратимый config/web rollback drill. Следующая задача остаётся `QA-01`; не переходить к `SHOW-01`. |
| 2026-07-18 | CONTENT-01 | **BLOCKED: dependency `DEPLOY-01` теперь DONE, но отсутствует обязательный внешний content input.** Нельзя правомерно и честно опубликовать новый show-ready каталог от имени Олександра без утверждённых hero/avatar и подтверждённых материалов/прав. Выдуманный авторский content, placeholders или подмена `PENDING:` asset не создавались; production/Studio/Supabase/Render не изменялись. | Read-only production audit: `GET /api/v1/bootstrap/ohorodnik-oleksandr` возвращает `PENDING:/brands/ohorodnik-oleksandr/avatar-512.png` и пустой `heroPhotos`; tenant-scoped `GET /recipes/` и `GET /collections/` возвращают `total_count: 0`. Следовательно, Home/Search/collection/paywall не могут пройти show-ready acceptance. | Для разблокирования нужны: final avatar либо явно утверждённая monogram, hero assets для home/login/paywall/collection и подтверждённые материалы/права (плюс финальное название/описание premium collection, если оно меняется). Следующая задача остаётся `QA-01`; её не начинать в рамках CONTENT-01. |
| 2026-07-18 | DEPLOY-01 | **DONE.** Final web deploy `dep-d9dq3qtp1rgs73epl8e0` is `live` on exact SHA `7ca6c82cd3c6de1492b899fa2499a2c1f1f7bac7`; API/database не изменялись. Auth corrective fix подтверждён на production: owner test user login → Profile отображает authenticated profile; после reload Profile остаётся authenticated. Authenticated demo catalogue загружается; current account корректно получает fail-closed «Демо-доступ поки недоступний для цього акаунта», поэтому activation/purchase/entitlement mutation не выполнялись. | GitHub `backend-ci` и `frontend-ci` — success. Browser: tenant brand, login, protected Profile, session restore и authenticated catalogue — PASS; browser errors/CORS errors отсутствуют. API `/health` 200 `healthy`, `/health/ready` 200 `production`, bootstrap tenant brand 200, exact-origin CORS — PASS. Web `/main.dart.js` 200 with `Cache-Control: no-cache`. | Следующая задача: `QA-01`. Stripe/live payments не включались; rollback не нужен, previous web deploy сохраняется в Render history. |
| 2026-07-18 | DEPLOY-01 | **P1 воспроизведён локально; причина сужена до server-side отклонения token refresh; добавлены router fix и auth-диагностика.** Полная локальная репродукция production web build против управляемой gotrue-заглушки: (1) со здоровым auth-сервером login → Profile и restore после reload работают на текущем коде; (2) деплойнутый production bundle корректно восстанавливает синтетическую сессию из `localStorage` (проверено на prod origin без credentials); (3) точный production-симптом (login → Home ok → Profile guest, storage пуст после reload, в логе нет `/logout`) воспроизводится тогда и только тогда, когда access token приходит с истечением ≤30s и последующий `grant_type=refresh_token` отклоняется: gotrue 2.25 рефрешит сразу после login (порог 3×10s тиков), на не-retryable 400 делает `_removeSession` + `signedOut(sessionExpired)`, и supabase_flutter стирает persisted session. Т.е. клиентский код ведёт себя корректно, а сессию убивает сервер/конфигурация. Дополнительно найден и исправлен второй симптом «после login выбрасывает на Home вместо возврата в Profile»: `appRouterProvider` пересоздавал GoRouter на каждом auth-изменении и терял `returnTo`; router теперь стабильный c `refreshListenable`. Добавлена token-free `AuthDiagnostics` (event, signOutReason, fromBroadcast, expiresInSec, clockSkewSec, sessionId) — печатает trail в browser console. | Instrumented browser timeline: `SIGNED_IN`+persist → через ~3s `removeItem`+`SIGNED_OUT` при refresh 400; network log: `password grant 200` → `refresh_token 400` → wipe. Prod: `main.dart.js` содержит `supabase-flutter/2.15.4`+`gotrue-dart/2.25.0`, синтетический restore-тест пройден. Local gates: `dart format` PASS, `flutter analyze` PASS, targeted `flutter test` (auth_diagnostics, route_guards, auth_service, login_page) 18 passed. Чтение production auth config/Management API и auth-схемы БД не выполнялось (permission classifier); mutations в production нет. | Владельцу: проверить в Supabase Dashboard → Auth: JWT expiry (вернуть ≥3600s), Refresh token rotation/reuse interval, «Single session per user», Time-box/Inactivity timeout — текущая сигнатура указывает на короткий JWT + отклоняемый refresh (например, time-boxed/single-session-revoked сессия). После deploy этого билда один owner login в prod console даст `[auth-diag]` trail с точным `signOutReason`, `expiresInSec` и `clockSkewSec` без раскрытия credentials. Следующая задача остаётся `DEPLOY-01`. |
| 2026-07-18 | CONTENT-01 | **BLOCKED: задача не может быть начата без нарушения dependencies и content policy.** `DEPLOY-01` остаётся `BLOCKED` на owner-authenticated production smoke, поэтому его dependency фактически не завершена. Кроме того, в репозитории нет утверждённых hero-фотографий/avatar и подтверждённых материалов с правами; существующий tenant bootstrap всё ещё содержит `PENDING:` avatar и пустой `heroPhotos`. Выдуманный авторский контент Олександра не создавался, production/Studio/Supabase/Render не изменялись. | Read-only audit: `git status -sb` clean; `frontend/assets/branding/ohorodnik-oleksandr_bootstrap.json` и `pilot_bootstrap.json` подтверждают `PENDING:` avatar и пустые hero assets; catalog/content contracts поддерживают content kinds и Studio replacement, но не являются show-ready content pack. | Для разблокирования: сначала завершить `DEPLOY-01`, затем предоставить/утвердить avatar или окончательную monogram, hero assets и права/финальные материалы. Следующая задача остаётся `DEPLOY-01`; `CONTENT-01` не обходить placeholder- или выдуманным author content. |
| 2026-07-17 | DEPLOY-01 | **BLOCKED: web auth persistence fix `c7f0257` deployed but production symptom persists.** Web-only deploy `dep-d9cu23beo5us73b5k61g` is `live` on exact SHA `c7f025753cde2464dc9b93a4427fd347de2a08e2`; API/database не менялись. | GitHub `backend-ci` и `frontend-ci` — success. Browser: корректный test login → Home, затем reload → tenant Home; переход Profile всё равно показывает guest CTA. Поэтому auth restoration, authenticated commerce catalogue и allowlist/kill-switch не заявлены. | Не делать новый speculative deploy: сначала instrument/diagnose actual browser auth storage/session state without exposing credentials, затем внести только подтверждённый fix. Следующая задача остаётся `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **BLOCKED: owner-authenticated smoke подтвердил, что corrective auth fix не закрывает production P1.** Существующий approved test user успешно вошёл: Home показал tenant branding «Огороднік Олександр» и authenticated navigation. После browser reload оболочка Home сохранилась, но переход на protected `#/profile` показал guest CTA «Увійти». Следовательно, реальная Supabase session не восстановилась; состояние Home после reload само по себе не является доказательством auth restoration. Повторные sign-in attempts, account creation/reset, commerce purchase и entitlement mutations не выполнялись. | Owner-provided screenshots: successful authenticated Home до reload; Home после reload; protected Profile после reload с guest state. Deployed web остаётся `dep-d9chl88js32c73aj55mg` на code SHA `6ea0e6fc12df8916d253c6f1b363188899f78e5d`; API/web ранее подтверждены healthy, branding/routes/assets загружаются. Authenticated `/commerce/catalogue` и allowlist/kill-switch не заявлены, поскольку session restoration gate провален. | Диагностировать production web auth storage/restore path после `gotrue 2.25.0`: установить, почему Home shell переживает reload, а `Supabase.auth.currentSession/currentUser` на protected route пусты. Не закрывать DEPLOY-01 и не переходить к authenticated commerce smoke до узкого verified fix и нового web deploy. |
| 2026-07-16 | DEPLOY-01 | **Corrective auth fix deployed; code-level P1 root cause устранена, acceptance остаётся BLOCKED только на owner-authenticated browser smoke.** Диагностика подтвердила race в pinned `gotrue 2.13.0`: stale background refresh/recovery мог завершиться после нового password sign-in и удалить более новую session. `supabase_flutter` обновлён до `2.15.4` (`gotrue 2.25.0`), где session-version guard не позволяет stale refresh перезаписать или разлогинить concurrent session. Совместимость и CI release gate исправлены без API/DB/schema/config/secrets изменений. Commits `d6c8674d1c12972f7ad8d38f5f46b0edceff5b22`, `d313c9d23c7b0ead4e20e89f50e3fe27f3826f8f`, `6ea0e6fc12df8916d253c6f1b363188899f78e5d`; final web deploy `dep-d9chl88js32c73aj55mg` — `live`. | Deployed code SHA `6ea0e6f`; последующие изменения `main` — только release journal. GitHub `frontend-ci` и `backend-ci` для deployed SHA — green. Local release gates: `flutter analyze` PASS; full workstation suite с platform goldens — `92 passed`; Linux-equivalent CI suite — `87 passed` с явно tagged/excluded platform-specific pixel goldens; production-like web build PASS. Production: web HTTP 200, Flutter entrypoint present, `/main.dart.js` `Cache-Control: no-cache`, deployed bundle содержит `supabase-flutter/2.15.4` и `gotrue-dart/2.25.0`; API `/health`, `/health/ready`, tenant bootstrap и exact-origin CORS — PASS. | `WHITE_POVAR_SMOKE_AUTH_TOKEN` отсутствует, поэтому не заявлены browser login → Profile persistence, authenticated `/commerce/catalogue` и allowlist/kill-switch. Не создавать production account и не генерировать privileged session ради закрытия rollout; владелец должен предоставить/открыть approved test session, после чего повторить authenticated smoke. Rollback не нужен: web/API healthy, DB impact `none`. Следующая задача остаётся `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **BLOCKED: first corrective auth attempt deployed but did not resolve the P1.** Commit `70f6d807375258605d7453264c32624256dbfea1` (`fix(auth): retain successful email sessions`) makes backend profile sync best-effort and sets provider state from a successful email response; web-only deploy `dep-d9cgjertqb8s73b2soag` is `live`. Repeated production login → Profile still becomes guest, so this change is not claimed as a resolution. No commerce/demo/reset/account mutations were made. | Local: `dart format` and `flutter analyze` PASS; production-like web artifact rebuilt. Targeted Flutter test again stalled during compiler startup and was stopped without failure output. Render deploy exact SHA/status PASS. Browser: corrected owner email reaches Home with no login error, then protected Profile is guest; console has only font fallback warnings. | Diagnose actual auth storage/event flow before another code change. Then deploy a verified corrective fix and repeat auth restoration, authenticated catalogue, and allowlist/kill-switch. Next task remains `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **BLOCKED: выявлена P1 production auth-session regression.** После owner correction test email login UI переводит на Home без ошибки, но следующий protected Profile сразу показывает guest state; direct protected route также возвращает на Login. Это не credential blocker и не может быть закрыто повторными попытками входа. Commerce mutations, demo activation, reset и account creation не выполнялись. | Browser: tenant branding корректен; login → Home transition проходит; Profile после transition — guest; console без auth/CORS/API errors (только font fallback warnings). | Нужен узкий corrective fix auth state/session persistence, затем новый web deploy и повторить auth restoration, `/commerce/catalogue`, allowlist/kill-switch. Следующая задача остаётся `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **BLOCKED: authenticated smoke не начат, так как production отверг явно предоставленные owner credentials.** Login UI вернул нейтральное fail-closed сообщение «Email або пароль не підходять»; password/email не сохранялись, не записаны в этот документ и дальнейшие sign-in attempts прекращены. Никакие commerce mutations, demo activation, reset или creation account не выполнялись. | Browser: tenant login page доступна, брендинг «Огороднік Олександр» корректен. Controlled sign-in attempts завершились credential rejection; protected profile показал guest state. Console: только существующие font fallback warnings, без CORS/API errors. | Владелец должен предоставить действующую test session либо подтвердить/восстановить пароль вне чата; после этого проверить auth restoration, authenticated `/commerce/catalogue` и allowlist/kill-switch. Следующая задача остаётся `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **Production cache fix deployed, задача остаётся BLOCKED только на authenticated smoke.** Найдена и устранена причина краткого generic/stale Flutter client: stable entrypoint `main.dart.js` мог CDN-кэшироваться (`s-maxage=300`) после нового HTML shell. В Render static-site headers добавлено `Cache-Control: no-cache` для `/main.dart.js`; source-of-truth дополнен тем же правилом и защитными no-cache rules для остальных stable Flutter entrypoints (`flutter.js`, `flutter_service_worker.js`, `version.json`). Изменение опубликовано в `main` как `99c7a0de7574eedefe1b5826feac7653d404a6fc` (`fix(web): prevent stale Flutter bundles`) и web-only deploy `dep-d9cgc59kh4rs73co60sg` — `live`. API и database не изменялись. Владелец уточнил operational policy pilot: пока нет конечных пользователей, при code/config проблемах предпочтителен fix-in-place; rollback — только при риске данных, безопасности или полной недоступности. | Render deploy подтверждён `live` на exact SHA `99c7a0d`. External HTTP: `/main.dart.js` 200, `Cache-Control: no-cache` (после deploy; до него было `public, max-age=0, s-maxage=300`). API повторно healthy/ready: `/health` 200 `healthy`, `/health/ready` 200 `production`; bootstrap endpoint доступен, CORS preflight с web origin 200 и exact allowed origin. Browser после cache-busted load имеет tenant page title «Огороднік Олександр». `git diff --check` и YAML parse — PASS. | Для полного DEPLOY-01 остаётся только owner-provided authenticated session: проверить session restore, catalogue и demo allowlist/kill-switch. Не создавать обычные production accounts ради rollout; следующая задача остаётся `DEPLOY-01`. |
| 2026-07-16 | DEPLOY-01 | **BLOCKED после production rollout, восстановленного до exact SHA.** `65bae0a1ba07cef8b8f9bb37bea715d3f8636241` pushed в `main`; владелец явно разрешил concurrent rollout. API deploy `dep-d9cg0i8js32c739belsg` — `live`. После owner-configured public `SUPPORT_EMAIL` web build `dep-d9cg31uq1p3s73df9t20` — `live`. Browser initially showed generic cached client build; временный rollback deploy `dep-d9cg5iuq1p3s73dfe8e0` на `7a75b029…` подтвердил, что прежний build не передавал `TENANT_SLUG`, и был сразу заменён финальным web deploy `dep-d9cg7m8js32c73bbcsqg` — `live` на exact SHA. В browser production web теперь показывает «Огороднік Олександр» и штатный empty catalogue; console errors отсутствуют. Approved test user существует, email подтверждён и account не заблокирован. Миграции и secrets не изменялись в DEPLOY-01. | Read-only deploy dry-run в Render workspace `My workspace` — PASS: services/URLs/repository/branch подтверждены. API smoke — PASS: `/health` 200 (`healthy`), `/health/ready` 200 (`production`), tenant bootstrap 200 с BrandConfig «Огороднік Олександр», CORS OPTIONS с web origin 200 и exact `Access-Control-Allow-Origin`. Web: HTTP 200, Flutter entrypoint present; final bundle содержит `ohorodnik-oleksandr`; browser branding/routes/API call — PASS; tenant recipe request 200. Guest commerce catalogue и demo purchase — 403 `Not authenticated`, без entitlement mutation (fail-closed). | Для полного acceptance остаётся только authenticated production smoke: создать/восстановить auth session существующего test user, проверить authenticated commerce catalogue и allowlist/kill-switch behavior. Следующая задача остаётся `DEPLOY-01`; API/web rollback не нужен, оба final deploys healthy. |
| 2026-07-16 | DB-02 | **DONE.** Production Supabase `qnlfvpqmkmbvzmzqgjpo` приведён к pilot schema/data через ledger runner: подтверждённые legacy subscription schema/backfill зарегистрированы отдельной baseline procedure без запуска их SQL; применены все 22 managed migrations и pilot BrandConfig seed. Исправлены два defects самого migration flow: runner теперь пересчитывает dependencies после каждого committed entry, а новая forward migration `2026_07_16_seed_demo_commerce_offers` идемпотентно создаёт demo monthly/annual offers после tenant seed. Назначен один tenant-scoped internal Studio admin; entitlement реальным пользователям не выдавались. Production API/web не deployed. | Preflight: project ref подтверждён, active auth sessions `0`; pre-counts `chefs=1`, `recipes=19`, `users=3`, schema ledger/config/commerce/Studio tables отсутствовали. Backup artifact создан до mutation: `.operations/backups/supabase-qnlfvpqmkmbvzmzqgjpo-pre-db02-20260716T150035Z.sql`, `42840` bytes, SHA-256 `ce5ef3f66c06d9a9d53bee22616d8c5232299f60a2f211a95b1ed42013b47e1b`; путь исключён из git, recovery — restore этот SQL artifact или recorded Supabase recovery path по `RELEASE_RUNBOOK.md`, без destructive reset. Read-only `plan` — clean; final `status`: 22 managed `applied`, 2 confirmed legacy `baseline-applied`, только non-executable `legacy_sample_premium_recipe` = `manual-review`. Postflight: valid BrandConfig, two tenants, `products=2`/`offers=2` (month/year), `commerce_entitlements=0`, Studio admins `1`, RLS enabled on 11 relevant tables; rolled-back cross-tenant offer probe rejected. Targeted migration tests `5 passed, 1 skipped`, migration lint and `git diff --check` — PASS. Full backend collection again hung without output in this local environment and was stopped; REL-01's successful full gate remains the release evidence. | Production bootstrap HTTP remains a deploy-time check because current API is intentionally old; database BrandConfig was validated against the runtime schema directly. No premium collection exists, so one-off offer is intentionally absent and free users have zero entitlements. Next task: `DEPLOY-01` (API first, then web); do not run another DB apply except a new forward corrective migration. |
| 2026-07-16 | REL-01 | **DONE.** Release candidate зафиксирован как `6cf0843`. Dirty tree классифицирован: единственное оставшееся изменение `WHITE_POVAR_IMPLEMENTATION_PLAN.md` сохранено как несвязанное пользовательское. Подтверждены server-controlled demo commerce, backward-compatible existing API routes, точный release/rollback runbook, server-only secrets contract и отсутствие release debug purchase adapter в bundle. Production не изменялась, migrations не применялись, deploy не выполнялся. | Read-only production migration `plan` — PASS: unknown/checksum conflicts отсутствуют; ledger ещё отсутствует, 21 managed migration показана `ledger-missing`, 3 legacy — `manual-review`. `COMMERCE_MODE=demo` production startup validation — PASS. Backend fresh environment: `205 passed, 1 skipped` (только optional disposable PostgreSQL integration), flake8 — PASS. Flutter format/analyze — PASS, полный suite — `92 passed`, production-like pilot web build — PASS (`✓ Built build/web`). Bundle scan: server-only secrets и `FakePurchaseAdapter`/`debug.*` products отсутствуют. Exact RC source snapshot повторил backend/frontend gates и web build. `git diff --check` — PASS. | Перед `DB-02` сохранить Supabase backup/PITR evidence и вручную сверить 3 legacy migrations; только затем запускать ledger-backed `apply`. Следующая задача: `DB-02`. |
| 2026-07-16 | REL-01 | Устранены две Flutter analyzer info diagnostics (brace around demo-purchase error return и unused paywall helper); application behavior не менялся. Production не изменялась, migrations/deploy не выполнялись. | `flutter analyze` — PASS (no issues). Полный `flutter test` был запущен и завершился перед production-like build; web build с public test defines и pilot tenant снова остановлен локально на `Compiling lib/main.dart for the Web...` после >80 секунд без результата. | **BLOCKED:** воспроизводимо завершить `scripts/build-web.sh` в рабочем Flutter environment и сохранить successful output; затем закрыть REL-01. Следующая задача остаётся `REL-01`; `DB-02` не начинать. |
| 2026-07-16 | REL-01 | Исправлен local config contract для `EXPECTED_SUPABASE_PROJECT_REF`: Settings принимает server-only project ref, не раскрывая его через API; regression test добавлен. Migration manifest test синхронизирован с фактическими 21 managed migrations. Read-only production `plan` теперь подключается к production и завершён без unknown/checksum-conflicting entries; ledger отсутствует, поэтому managed migrations корректно показаны как `ledger-missing`, три legacy — `manual-review`. Production не изменялась, migrations не применялись, deploy не выполнялся. | Fresh Python 3.13 environment: backend `pytest tests/ -q` — **205 passed, 1 skipped** (disposable PostgreSQL integration требует отдельный `MIGRATION_TEST_DATABASE_URL`); backend flake8 — PASS. `tools/migrate.py plan` — PASS/read-only. Flutter formatter/analyzer снова не завершаются в этом workspace (analyzer остановлен после ~2 минут без diagnostics); frontend source tree не менялся в этом work package. | **BLOCKED:** нужен воспроизводимый Flutter environment, в котором `dart format`, `flutter analyze`, `flutter test` и production-like `scripts/build-web.sh` завершаются; после этого повторить frontend gate и clean-checkout verification. Следующая задача остаётся `REL-01`; `DB-02` не начинать. |
| 2026-07-16 | REL-01 | Dirty tree классифицирован как scope завершённых DB-01/DEMO-01/CFG-01 и release qualification; добавлен точный `RELEASE_RUNBOOK.md` с go/no-go, backup/migration, API→web promotion и rollback decision. Создан fresh Python 3.13 venv из `backend/requirements.txt`; imports `gotrue`, `supabase`, `psycopg` в нём проходят, устраняя прежний повреждённый local venv как объяснение blocker. Production не изменялась, migrations не применялись, deploy не выполнялся. | Read-only migration preflight с `EXPECTED_SUPABASE_PROJECT_REF=qnlfvpqmkmbvzmzqgjpo` прошёл project-ref guard, но production pooler отверг локальный `DATABASE_URL` (`ENOTFOUND tenant/user`), поэтому ledger не прочитан и acceptance migration plan не подтверждён. В clean venv targeted backend collection проходит, но full backend collection не завершается в ограниченное время; Flutter format сообщает одно существующее style-расхождение, analyzer — 2 pre-existing info; full frontend test/build ещё не даёт завершённого evidence в этом окружении. `git diff --check` — PASS. | **BLOCKED:** владелец/оператор должен вне git предоставить валидный production `DATABASE_URL` для project `qnlfvpqmkmbvzmzqgjpo` (или исправить pooler tenant/user) и воспроизводимую backend test environment; затем повторить полный backend/frontend gate, clean-checkout build и read-only `plan`. Следующая задача остаётся `REL-01`; `DB-02` не начинать. |
| 2026-07-16 | CFG-01 | Render contract теперь сохраняет Render web origin вместе с проверенными Firebase origins; API fail-closed валидирует production secrets/config, DB URL, commerce mode и соответствие `WEB_APP_URL` CORS allowlist, не раскрывая values. Web получает только public Dart defines, production build требует support email; Google OAuth скрыт до подтверждённой конфигурации, Apple не предлагается на web. Settings содержит честные in-app demo privacy/use notices и build label. Добавлен runbook Supabase Auth/Render без secret values. | Локальные CORS preflight/readiness contract tests (4 passed), backend flake8, Flutter format и полный `flutter test -r compact` (87 passed) — PASS; `flutter analyze` имеет только 2 pre-existing info diagnostics. Production-like web build с тестовыми public values и `git diff --check` — PASS. Полный backend pytest был остановлен: в этом окружении он завис на collection без вывода; это фиксируется для `REL-01`. Production Render/Supabase не изменялись, migrations не применялись и deploy не выполнялся. | Перед `REL-01` владелец продукта должен вне git задать Render `SUPPORT_EMAIL`, demo allowlist и завершить Supabase Site URL/redirect URLs; Google включать только после browser OAuth verification. Future custom domain — отдельный follow-up. Следующая задача: `REL-01`. |
| 2026-07-16 | DEMO-02 | Release web adapter заменён на server-catalogue demo flow: CTA «Активувати демо-доступ», заметное disclosure «Кошти не списуються», allowlist/unavailable/loading/purchasing/server-confirmation/error/active/expired состояния и refresh server entitlement после каждой активации/обновления доступа. One-off после server confirmation возвращает к mapped collection; native store adapter сохранён для mobile. Обновлены widget-state tests и goldens 390/768/1280. | `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, targeted paywall goldens/tests, полный `flutter test -r compact`, production-like `flutter build web --release` и `git diff --check` — PASS. Production не изменялся, migrations не применялись и web не deployed. | До production flow необходимы `CFG-01` и `REL-01`; allowlist и kill switch остаются только server-side. Следующая задача: `CFG-01`. |
| 2026-07-16 | DEMO-01 | Добавлен fail-closed server commerce mode (`disabled|demo|stripe`) и server-only email allowlist; authenticated tenant catalogue с display metadata; demo purchase принимает только `offerKey` и `Idempotency-Key`, а user/tenant/scope/price/duration определяются сервером. Новая migration расширяет offers, добавляет `demo` source, защищённый service-role-only transactional RPC, seed monthly/annual и conditional one-off offer, а также internal CLI `backend/tools/demo_commerce.py` для list/grant/revoke/reset. Existing RevenueCat/mobile endpoints не менялись. | Targeted DEMO/commerce/migration tests, полный backend suite, flake8 и `git diff --check` — PASS. Migrations/seed не применялись, production не изменялся и не заявляется deployed. | До DB-02 migration ожидает обычный ledger/backup flow. `DEMO-02` должен использовать catalogue и server confirmation, не раскрывая allowlist и не открывая premium по client success. Следующая задача: `DEMO-02`. |
| 2026-07-16 | DB-01 | Добавлены фиксированный `backend/migrations/manifest.json` (20 managed timestamped migrations), SHA-256 ledger `schema_migrations`, fail-closed runner `backend/tools/migrate.py` с `status`/read-only `plan`/`apply`, project-ref guard, advisory lock, транзакцией migration+ledger и checksum fail-closed. Три legacy SQL отмечены manual-review и не запускаются runner; старый direct runner теперь отказывает. Добавлена recovery procedure для DB-02. Pending migrations не применялись. | Unit checks manifest/checksum/status/project-ref: 3 passed; disposable PostgreSQL integration подтвердил idempotent rerun и rollback failed migration. Полный backend suite: 196 passed; flake8, `flutter analyze`, `flutter test -r compact` и `git diff --check` прошли. Read-only production `plan` был остановлен до соединения: локальный venv не содержит новый driver до переустановки requirements; production DB не менялась. | Перед DB-02 установить обновлённые backend requirements в release environment, сохранить backup/PITR evidence, выполнить production `plan` и вручную сверить applied state трёх legacy files; только затем разрешён `apply`. Следующая задача: `DEMO-01`. |
| 2026-07-16 | PILOT-00 | Снят локальный release-qualification blocker: account-deletion error sink больше не добавляет traceback с provider exception text в логи; contract test сохранён. Rebaseline полностью завершён, production не изменялся. | Targeted contract — PASS; backend `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python3 -m pytest tests/ -q`: 193 passed; backend flake8 — PASS; frontend `flutter analyze` и `flutter test -r compact` — PASS; `git diff --check` — PASS. | `PILOT-00` = `DONE`; следующая задача `DB-01`. Незакоммиченные `auth.py` и contract test теперь являются намеренной частью следующего release candidate; несвязанные user changes сохранены. |
| 2026-07-16 | PILOT-00 | Выполнен read-only rebaseline. 49 commits (`d1eb3ca`…`3a4e1d8`, 268 files) определены как release candidate после устранения blocker; 5 незакоммиченных файлов сохранены и исключены. Зафиксированы API/web/DB delta, env contract, migration uncertainty и Render rules. Production не изменялся. | `git diff --check` и backend flake8 прошли; frontend `flutter analyze` и `flutter test -r compact` прошли. Backend pytest: 192 passed, 1 failed — незакоммиченный `test_release_qualification_contract.py` выявляет provider exception/email в traceback из незакоммиченного `auth.py`. API `/health` и `/health/ready`: 200; tenant bootstrap: 404; web: 200/generic metadata; `/auth/callback`: SPA entrypoint. CLI видит project, но repo не linked, migration history не прочитана. | `PILOT-00` остаётся `BLOCKED`: перед release qualification владелец незакоммиченной auth/test change должен безопасно устранить утечку текста provider exception и добиться passing backend suite. Затем повторить pytest и завершить статус; DB-01/DEMO-01/CFG-01 не начинать. |
| 2026-07-16 | PLAN | Создан отдельный production web-pilot roadmap. Зафиксированы отсутствие staging, demo-commerce до Stripe, production Supabase `qnlfvpqmkmbvzmzqgjpo`, безопасный migration flow и mobile scope как PARKED. | Сверены текущий roadmap, git baseline, Render endpoints, Supabase CLI/API access и существующий commerce contract. Production не изменялся. | Следующая задача `PILOT-00`. Перед migrations требуется rebaseline и безопасный runner; старый direct runner не использовать. |
