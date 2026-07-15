# White Povar — детальный план имплементации

Дата: 15 июля 2026  
Статус: COM-03 BLOCKED: consumer purchase/restore/manage integration готова к sandbox, но нужны Apple Developer, Google Play Console и RevenueCat accounts, products и active mappings для фактической проверки.
Следующая задача: `COM-02` (external sandbox setup)
Канонический consumer-клиент: `frontend/`  
Backend: `backend/`  
Design source of truth: `White povar redesign brief document/Handoff Spec.dc.html` и `Stage 1 - Foundations.dc.html`, версия 1.2

## 1. Как пользоваться этим документом в новых чатах

Каждый новый чат должен выполнять только один work package из разделов ниже. Чтобы экономить контекст, не требуется перечитывать все остальные детальные work packages.

Порядок работы чата:

1. Прочитать разделы 1–4, строку задачи в очереди, только выбранный work package, Definition of Done и последние записи журнала.
2. Проверить `git status`; не перезаписывать чужие или несвязанные изменения.
3. Реализовать только scope задачи и её прямые prerequisites.
4. Выполнить указанные проверки.
5. Обновить статус задачи в таблице: `TODO` → `IN PROGRESS` → `DONE` или `BLOCKED`.
6. В конце добавить краткую запись в журнал выполнения: дата, задача, изменённые файлы, проверки, решения и остаточные риски.

Шаблон запроса для нового чата:

```text
Работаем в /Users/ihorskakovskyi/Documents/White Povar.
Прочитай в WHITE_POVAR_IMPLEMENTATION_PLAN.md разделы 1–4, строку <ID> в очереди, секцию задачи <ID>, Definition of Done и последние записи журнала.
Соблюдай dependencies, acceptance criteria и out of scope этой задачи.
Переиспользуй текущую реализацию. Не трогай несвязанные пользовательские изменения.
После реализации запусти указанные проверки и обнови статус/журнал в плане.
Не переходи к следующему work package.
```

Одновременно в одном worktree безопасно выполнять только задачи с непересекающимися файлами. По умолчанию задачи выполнять последовательно в указанном ниже порядке.

## 2. Зафиксированные решения и рабочие допущения

1. White-label единица MVP — отдельное приложение конкретного блогера на общей кодовой базе.
2. Первый пилотный tenant — «Огороднік Олександр».
3. Язык MVP — украинский. Схемы и хранение сразу допускают локализованные значения, но второй язык не блокирует пилот.
4. «Курс» в MVP — premium-коллекция контента. В неё могут входить:
   - обычный рецепт;
   - техника;
   - процесс;
   - видео с описанием или шагами.
5. Это не LMS: в MVP нет модулей, домашних заданий, сертификатов и обязательного course progress.
6. Коллекция является отдельной сущностью с обложкой, описанием, упорядоченным списком материалов и правилами доступа.
7. Материалы коллекции переиспользуют существующую recipe-инфраструктуру, но получают `contentKind`: `recipe`, `technique`, `process`, `video`.
8. Монетизация первой полноценной версии: подписка + разовая покупка premium-коллекций. Разовая продажа отдельного рецепта — позже, но entitlement-модель не должна её запрещать.
9. Creator Studio сначала внутренний инструмент команды. Self-service блогера не входит в первый пилот.
10. Изменения runtime-конфига, текстов и фотографий публикуются без новой mobile-сборки. App icon, native splash, package name и store metadata меняются только через build/release pipeline.
11. В tenant-сборку всегда включается последний утверждённый BrandConfig. Бренд `White Povar` не используется как fallback в пользовательском приложении блогера.
12. Hero-фотографии получают явные роли `home`, `login`, `paywall`, `collection`, а не выбираются неявно через `heroPhotos[0]`.
13. Рабочее допущение до COM-02: на web покупки первоначально не оформляются; web читает существующие entitlements, а покупка предлагает открыть mobile app. Отдельный web billing рассматривается перед commerce-релизом.
14. AI-сгенерированный рецепт является приватным пользовательским draft, явно помечается как AI и никогда автоматически не публикуется в каталоге блогера.

## 3. Пилотный BrandConfig

Выбран холодный стальной серо-синий акцент. Буквально белый accent исчезал бы на светлом фоне; белый и молочный сохраняются в нейтральных поверхностях, а стальной цвет остаётся заметным и сдержанным.

`creatorName` сокращён до «Олександр», потому что поле ограничено 16 символами и используется в компактных UI-подписях. Полное имя остаётся названием бренда.

```json
{
  "schemaVersion": 1,
  "tenantSlug": "ohorodnik-oleksandr",
  "locale": "uk",
  "brand": {
    "name": "Огороднік Олександр",
    "creatorName": "Олександр",
    "avatar": "PENDING:/brands/ohorodnik-oleksandr/avatar-512.png",
    "accent": "#5D7183",
    "font": "grotesque",
    "voice": {
      "greeting": "Ой, друзі, ну це щось...",
      "loginTitle": "Готуйте з Олександром",
      "paywallTitle": "Колекції Олександра",
      "courseName": "Майстерня Олександра"
    },
    "courseTag": "maisternia-oleksandra",
    "heroPhotos": [],
    "logo": null,
    "derived": {
      "accentPressed": "#4B5E70",
      "accentOnDark": "#6B8092",
      "onAccent": "#FFFFFF",
      "lightCtaMode": "accentFill"
    }
  }
}
```

Временный avatar — монограмма «О»/«ОО» без изображения вымышленного человека. До загрузки hero-фотографий используется gradient fallback из handoff 13d. Production URL для avatar появится после настройки brand asset bucket.

Правило derivation, которое необходимо закрепить тестами:

- `accentPressed`: OKLCH `L × 0.88`, hue/chroma сохраняются;
- `onAccent`: ink при контрасте ≥ 4.5, иначе white;
- `accentOnDark`: повышение OKLCH lightness до контраста ≥ 4.5 относительно `#16130F`;
- out-of-gamut: уменьшать chroma до попадания в sRGB, затем округлять каждый канал до ближайшего целого;
- light CTA использует accent fill только при контрасте accent / `#F5EEE1` ≥ 3.0.

## 4. Архитектурные ограничения

- Не развивать дублирующее Flutter-приложение в корневом `lib/`. Production Render build использует `frontend/`.
- `chefs` остаётся tenant-идентичностью MVP. Не добавлять отдельную параллельную tenant-сущность без реальной необходимости.
- Published BrandConfig хранить версиями отдельно от базовой записи `chefs`, чтобы поддержать draft, publish и rollback.
- Build получает обязательный `TENANT_SLUG`. Все catalog/search/AI/commerce запросы работают в tenant context.
- Клиентский tenant slug выбирает публичный каталог, но не является доказательством прав. Write/admin access определяется user membership, entitlement — server-side user + tenant + product/content scope.
- Не хранить произвольные remote fonts. В bundle допускаются только Figtree, JetBrains Mono, Source Serif 4, Golos Text и Lora с утверждёнными weights.
- BrandConfig отвечает только за Level 2 persona. Feature flags, products, prices, legal links и AI persona хранятся в отдельном product config.
- Runtime не вычисляет брендовые цвета. Он получает уже проверенные derived tokens.
- Не доверять клиенту `isPremium`, product IDs, price, entitlement или purchase result.
- Не скрывать premium-контент полностью из discovery: список возвращает teaser, detail закрывает защищённое содержимое.
- Сначала достигается design parity, затем добавляются новые продуктовые сценарии.

## 5. Milestones и критерии выхода

### M0 — Baseline и white-label foundation

Выход: tenant определяется однозначно, bootstrap не падает без сети, приложение запускается с брендом Олександра, API не смешивает каталоги.

### M1 — Design parity v1.2

Выход: существующие экраны соответствуют handoff на mobile/tablet/desktop, в light/dark, с реальным BrandConfig и полными loading/empty/error/locked состояниями.

### M2 — Consumer core

Выход: каталог, поиск, сохранения, история, cooking progress, auth и offline minimum работают end-to-end и tenant-safe.

### M3 — Premium collections и commerce

Выход: коллекции содержат разные типы материалов; подписка и разовая покупка дают корректные server-side entitlements; restore работает.

### M4 — Voice recommendations и AI fallback

Выход: пользователь говорит пожелание, редактирует transcript, получает рецепты только из tenant-каталога и при отсутствии результата явно выбирает AI generation.

### M5 — Internal Creator Studio

Выход: команда создаёт draft, валидирует бренд, загружает assets, видит preview, публикует runtime config и отдельно наблюдает build/release status.

### M6 — Pilot release

Выход: security, accessibility, analytics, store sandbox, recovery и production smoke tests пройдены для пилотного tenant.

### M7 — Post-pilot product expansion

Выход: недельное планирование меню, lifecycle-коммуникации, creator insights и продуктовые эксперименты развиваются на основании данных пилота, не усложняя первый релиз.

## 6. Очередь work packages

Статусы: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`.

| Порядок | ID | Work package | Depends on | Статус |
|---:|---|---|---|---|
| 1 | FND-00 | Baseline, canonical app и CI contract | — | DONE |
| 2 | FND-01 | Published BrandConfig schema и bootstrap API | FND-00 | DONE |
| 3 | FND-02 | Brand validator, color derivation и pilot seed | FND-01 | DONE |
| 4 | FND-03 | Flutter bootstrap, cache и bundled fallback | FND-02 | DONE |
| 5 | FND-04 | Dynamic themes, fonts и brand assets | FND-03 | DONE |
| 6 | FND-05 | Единый API client и tenant context | FND-03 | DONE |
| 7 | SEC-01 | Tenant isolation и premium teaser contract | FND-05 | DONE |
| 8 | DS-01 | Shared design-system primitives | FND-04 | DONE |
| 9 | DS-02 | Routing и adaptive shell | DS-01 | DONE |
| 10 | UI-01 | Home + brand header + collection promo | DS-02, SEC-01 | DONE |
| 11 | UI-02 | Login/signup/forgot-password states | DS-01, FND-03 | DONE |
| 12 | UI-03 | Paywall visual states без real billing | DS-01, FND-03 | DONE |
| 13 | UI-04 | Search/discovery design parity | DS-02, SEC-01 | DONE |
| 14 | UI-05 | Recipe detail и cooking design parity | DS-01, SEC-01 | DONE |
| 15 | UI-06 | Saved, Profile и Settings design parity | DS-02 | DONE |
| 16 | UI-07 | Camera flow design parity | DS-01 | DONE |
| 17 | QA-DS | Design matrix, goldens и accessibility | UI-01…UI-07 | DONE |
| 18 | CORE-01 | Рабочие favorites/save state | QA-DS | DONE |
| 19 | CORE-02 | Server-side search, filters, tags, pagination | SEC-01 | DONE |
| 20 | CORE-03 | История, cooking progress и offline minimum | CORE-01 | DONE |
| 21 | CORE-04 | Auth completion и guest migration | UI-02, CORE-01 | DONE |
| 22 | CORE-05 | Preferences, allergens и personalization inputs | CORE-02, CORE-04 | DONE |
| 23 | CORE-06 | Pantry и shopping list | CORE-05, UI-07 | DONE |
| 24 | COL-01 | Content kinds поверх recipe infrastructure | CORE-02 | DONE |
| 25 | COL-02 | Collections schema/API и ordered content | COL-01 | DONE |
| 26 | COL-03 | Collection list/detail/content UI | COL-02, UI-05 | DONE |
| 27 | COM-01 | Products, entitlements и access service | COL-02, CORE-04 | DONE |
| 28 | COM-02 | Mobile store adapter и webhook verification | COM-01 | BLOCKED |
| 29 | COM-03 | Purchase/restore/manage paywall integration | COM-02, UI-03 | BLOCKED |
| 30 | COM-04 | One-off collection purchase | COM-03, COL-03 | BLOCKED |
| 31 | VOICE-01 | Microphone, transcript и intent UI | CORE-05 | DONE |
| 32 | VOICE-02 | Structured intent API и tenant retrieval | VOICE-01, CORE-02 | DONE |
| 33 | VOICE-03 | Ranking, no-match и recommendation analytics | VOICE-02 | DONE |
| 34 | AI-01 | Opt-in AI recipe generation в стиле автора | VOICE-03 | DONE |
| 35 | AI-02 | Private generated drafts, safety и evaluation | AI-01 | DONE |
| 36 | STUDIO-00 | Config CLI и asset pipeline v0 | FND-02 | TODO |
| 37 | STUDIO-01 | Internal Studio drafts и previews | STUDIO-00, QA-DS | TODO |
| 38 | STUDIO-02 | Asset upload, focal roles и validation | STUDIO-01 | TODO |
| 39 | STUDIO-03 | Publish, rollback и build/release jobs | STUDIO-02 | TODO |
| 40 | STUDIO-04 | Internal content, collections и merchandising | COL-03, COM-01 | TODO |
| 41 | OBS-01 | Analytics, privacy и operational monitoring | M2/M3 flows | TODO |
| 42 | LIFE-01 | Notifications и lifecycle campaigns | OBS-01, CORE-04 | TODO |
| 43 | QA-REL | E2E, security, performance и store sandbox | Все release scope | TODO |
| 44 | REL-01 | Staging pilot «Огороднік Олександр» | QA-REL | TODO |
| 45 | REL-02 | Production release и rollback drill | REL-01 | TODO |
| 46 | GROW-01 | Weekly menu planner | CORE-06, COL-03 | TODO |
| 47 | GROW-02 | Creator insights и experiments | OBS-01, REL-02 | TODO |

## 7. Детальные work packages

### FND-00 — Baseline, canonical app и CI contract

**Scope**

- Зафиксировать, что изменяется только `frontend/`, а корневой Flutter scaffold не участвует в production.
- Запустить и записать baseline: frontend format/analyze/tests/web build; backend tests/import.
- Синхронизировать Flutter version между CI и Render.
- Добавить `TENANT_SLUG` как обязательный dart-define во все build entrypoints, пока с pilot default только для local development.
- Не исправлять продуктовые ошибки в этой задаче; оформить их как follow-up.

**Основные файлы:** `.github/workflows/ci.yml`, `frontend/scripts/render-build.sh`, `render.yaml`, `frontend/lib/core/config/app_config.dart`, README/plan.

**Acceptance**

- Один документированный набор команд воспроизводит CI локально.
- Build без production `TENANT_SLUG` завершается понятной ошибкой.
- CI и Render используют совместимую версию Flutter.

**Проверки:** `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build web`; `pytest tests/ -v` и import FastAPI.

### FND-01 — Published BrandConfig schema и bootstrap API

**Scope**

- Добавить уникальный `chefs.slug`.
- Добавить таблицу versioned `brand_configs`: `chef_id`, `version`, `status`, `config`, `created_by`, `created_at`, `published_at`.
- Разрешить только один published config на tenant; draft и archived версии сохраняются.
- Добавить отдельный versioned `product_configs` либо минимальный published JSON с locale/features/links без смешивания с brand.
- Создать публичный `GET /api/v1/bootstrap/{tenant_slug}` с ETag/config version.
- Не использовать старые поля `app_name/theme_config`, которых нет в фактической таблице `chefs`.
- Ответ должен включать tenant ID/slug, published BrandConfig, product config и config version.

**Основные файлы:** новая SQL migration, `backend/app/schemas/chef.py` или новые `brand.py/bootstrap.py`, `backend/app/api/v1/endpoints/config.py`, `backend/app/main.py`, database service.

**Acceptance**

- Неизвестный/inactive tenant → 404 без утечки других tenant.
- Нет published config → controlled 409/404, а не 500.
- Published config возвращается детерминированно и поддерживает `If-None-Match`/304.
- Unit/contract tests покрывают valid, missing, inactive и malformed cases.

**Out of scope:** Studio UI, asset upload, mobile caching.

### FND-02 — Brand validator, color derivation и pilot seed

**Scope**

- Реализовать единый backend validator схемы handoff 13a, включая conditional pair `courseName` + `courseTag`.
- Расширить `heroPhotos` полем `roles[]`; валидировать допустимые роли и focal point 0…1.
- Реализовать OKLCH derivation строго по разделу 3 этого плана.
- Добавить font enum и проверку лимитов/кириллических строк.
- Создать pilot seed/fixture и placeholder monogram avatar 512×512.
- Невалидный draft не публиковать.

**Acceptance**

- Golden color tests воспроизводят три reference brand из handoff и pilot values.
- Pilot config проходит все лимиты и contrast gates.
- `courseName` без `courseTag` и наоборот отклоняется.
- Невалидные URL/focal/roles/font отклоняются с field-level errors.

**Out of scope:** runtime Flutter theme, Creator Studio form.

### FND-03 — Flutter bootstrap, cache и bundled fallback

**Scope**

- Добавить immutable Dart-модели BrandConfig/TenantBootstrap с явным parsing failure.
- Включить validated pilot config и monogram asset в app bundle.
- Startup sequence: bundled pilot → cached valid config → remote config с timeout 3 секунды → сохранить для следующего запуска.
- Не менять бренд посреди активной сессии; свежая remote-версия применяется на следующем cold start, если не требуется security invalidation.
- При remote failure показывать cached/bundled tenant, не generic White Povar.
- Добавить bootstrap state/provider до построения `MaterialApp`.

**Основные файлы:** `frontend/lib/app/bootstrap.dart`, `app.dart`, новый `core/branding/`, `pubspec.yaml`, Hive/shared preferences adapter.

**Acceptance**

- Первый offline start показывает Олександра.
- Повторный offline start использует последнюю валидную cached version.
- Corrupt cache игнорируется и не ломает launch.
- Remote timeout не превышает 3 секунды.
- Widget/unit tests покрывают bundled/cached/remote/corrupt/timeout paths.

### FND-04 — Dynamic themes, fonts и brand assets

**Scope**

- Подключить bundled Figtree, JetBrains Mono, Source Serif 4, Golos Text, Lora и необходимые weights.
- Разделить system tokens и `BrandThemeExtension`.
- Строить light/dark ThemeData из validated derived tokens.
- Persisted `ThemeMode.system/light/dark`.
- Реализовать avatar/logo/hero fallback без серых broken-image блоков.
- Camera остаётся dark по design contract.

**Acceptance**

- Pilot brand и три reference brand рендерятся без hardcoded gold в brand roles.
- Premium gold и system success/warning/error не перекрашиваются.
- Text scale 200% не ломает обязательные действия.
- Font assets доступны offline и не загружаются с Google Fonts.

### FND-05 — Единый API client и tenant context

**Scope**

- Постепенно убрать параллельное использование raw `http`, ad-hoc Dio и дублирующих repositories.
- Через один `ApiClient` передавать auth, locale, tenant slug, request IDs и typed errors.
- Добавить cancellation/debounce там, где это нужно поиску.
- Не считать tenant header авторизацией.

**Acceptance**

- Recipe/search/config/subscription services используют единый transport либо имеют явный migration adapter.
- 401, 403 premium, 404, 409 и network errors различаются.
- Tests проверяют tenant/locale/auth headers и отсутствие токена у guest.

### SEC-01 — Tenant isolation и premium teaser contract

**Scope**

- Удалить optional unscoped behavior из recipes/featured/search/suggestions/filters/photo/AI endpoints.
- Разрешать tenant только через resolved bootstrap context.
- Все write operations проверяют membership пользователя в chef/tenant.
- List/search возвращает premium teaser metadata, но не защищённые ingredients/steps/video URLs.
- Detail access проверяется единым access service.
- Добавить RLS и API integration tests с двумя tenant и одинаковыми названиями контента.

**Acceptance**

- Ни один list/search/detail/favorite/AI тест не получает контент другого tenant.
- Guest видит free detail и premium teaser; premium body закрыт.
- Подмена tenant slug не даёт чужих private/premium данных или entitlements.

### DS-01 — Shared design-system primitives

**Scope**

- Создать общие Button, IconButton, TextField, Chip, Badge, RecipeCard, ContentCard, BrandHeader, UserAvatar, StateView, Skeleton, Sheet/Dialog и responsive container.
- Удалять приватные дубли только после перевода экрана на shared component.
- Добавить semantics, focus, keyboard states и tap target ≥44.

**Acceptance**

- Компоненты покрыты widget/golden tests в light/dark и pilot brand.
- Нет screen-level literal brand colors и повторяющихся button/card implementations.

### DS-02 — Routing и adaptive shell

**Scope**

- Оставить в stateful tab shell только Home, Search, Saved, Profile.
- Вынести auth, settings, subscription, recipe/content detail, cooking и camera в отдельные route branches.
- Сохранять состояние/scroll каждой вкладки.
- Bottom Navigation <600; NavigationRail ≥600; desktop compositions ≥1024.
- Добавить typed query/deep links: search tag, recipe/content, collection, offer return path.

**Acceptance**

- Back/deep link/refresh web работают предсказуемо.
- Settings/paywall/detail не показывают tab navigation.
- Route tests покрывают guest/auth/premium redirect и return-to-origin.

### UI-01 — Home + brand header + collection promo

**Scope**

- Реализовать Home из 12a/13e/13f для pilot brand.
- Различать blogger avatar и user profile avatar.
- Collection promo использует `courseName/courseTag`; guest сначала login, free user → paywall, entitled user → filtered collection/search.
- Полные loading/empty/error/offline states.
- Bookmark подключается только в CORE-01; до этого имеет явный disabled/adapter state, а не ложное успешное действие.

**Acceptance:** visual parity mobile/tablet/desktop, light/dark; no overflow на лимитных строках; hidden promo без conditional pair.

### UI-02 — Login/signup/forgot-password states

**Scope**

- Split login desktop, hero role `login`, gradient fallback.
- Email login, signup mode, validation, forgot-password sent, provider loading/error, guest entry.
- User-cancelled Google/Apple не показывается как system error.
- Предусмотреть account-link/provider-collision UI, даже если backend завершится в CORE-04.

**Acceptance:** handoff states 13i + signup/linking variants; keyboard/focus/autofill; no account enumeration in reset flow.

### UI-03 — Paywall visual states без real billing

**Scope**

- Реализовать route/dialog layouts 13h.
- Разнести idle, products-loading, products-unavailable, purchasing, success, error, user-cancel, active, grace, billing retry, expired и cancelled.
- Prices/trial показывать только из purchase adapter; никаких hardcoded production цен.
- До COM-02 использовать fake adapter в tests/dev и disabled purchase в production.

**Acceptance:** каждый state отдельно тестируется; повторный tap не создаёт двойную покупку; restore/manage доступны по состоянию.

### UI-04 — Search/discovery design parity

**Scope:** search field, recent/suggestions, filters, tag deep link, results grid/list, premium teaser, no-results recovery, loading/error; responsive 1/3/master-detail layouts.

**Acceptance:** query state сериализуется в URL на web; tag `maisternia-oleksandra` открывается напрямую; debounce/cancel не показывает устаревшие результаты.

### UI-05 — Recipe detail и cooking design parity

**Scope:** hero/media, stats, ingredients, steps, premium gate, video, cooking mode, skeleton/error/offline; подготовить shared content detail sections для будущих non-recipe kinds.

**Acceptance:** premium payload не утек через UI/state; cooking navigation доступна с text scale; видео имеет fallback и lifecycle cleanup.

### UI-06 — Saved, Profile и Settings design parity

**Scope:** guest/auth saved states, optimistic placeholders под CORE-01, профиль, subscription status entry, settings, persisted theme, legal/support placeholders из product config.

**Acceptance:** blogger avatar нигде не подменяет user avatar; guest CTA возвращает к исходному действию после login.

### UI-07 — Camera flow design parity

**Scope:** capture/upload, permission, review, confidence, edit list, search results, retake, loading/error; camera theme всегда dark.

**Acceptance:** low-confidence ingredient требует подтверждения; denied/permanently denied permissions имеют разные recovery actions; web camera fallback работает.

### QA-DS — Design matrix, goldens и accessibility

**Scope**

- Golden matrix: 3 reference brands + pilot; light/dark; 390, 768, 1280.
- Semantics, keyboard, contrast, 200% text scale, reduced motion.
- Smoke journeys Home → detail, Search, Camera, Login, Paywall.
- Зафиксировать допустимые platform rendering tolerances.

**Acceptance:** все design gaps из handoff закрыты тестами или явно записанным отклонением; это gate перед расширением продукта.

### CORE-01 — Рабочие favorites/save state

**Scope:** canonical favorite state, mutations на всех карточках/detail, optimistic update/rollback, undo, Saved refresh, auth prompt и guest intent migration.

**Acceptance:** два быстрых тапа не расходятся с сервером; logout очищает private cache; favorite другого tenant невозможен.

### CORE-02 — Server-side search, filters, tags, pagination

**Scope:** убрать client-side full-list filtering; подключить advanced search/suggestions/filters; tenant-safe tag filtering; cursor/offset contract; typo/no-result recovery.

**Acceptance:** стабильная пагинация без дубликатов; facets считаются внутри tenant; premium teaser участвует в discovery.

### CORE-03 — История, cooking progress и offline minimum

**Scope:** viewed/cooked history, active cooking step, timers/wake lock, offline saved recipe + active cooking, sync conflict rules.

**Acceptance:** active cooking переживает restart/offline; private history не остаётся после logout; timer notifications требуют opt-in.

### CORE-04 — Auth completion и guest migration

**Scope:** signup, email verification policy, password reset, provider collision/linking, deletion/logout, server user sync, миграция guest saved/preferences после login.

**Acceptance:** callback/deep-link проверены web/iOS/Android; отсутствие account enumeration; deletion очищает/анонимизирует данные по policy.

### CORE-05 — Preferences, allergens и personalization inputs

**Scope:** diet, allergens, dislikes, preferred time/equipment, household size; explicit consent; server model; применение к search/recommendations.

**Acceptance:** аллерген не используется как мягкий ranking signal — он является жёстким filter/warning; пользователь может удалить/сбросить профиль.

### CORE-06 — Pantry и shopping list

**Scope:** приватный pantry пользователя; ручной ввод, подтверждённые camera results и последующий voice input; optional quantity/freshness; расчёт имеющихся/недостающих ингредиентов; shopping list с группировкой, отметками, share/export и добавлением из рецепта/коллекции.

**Acceptance:** camera/voice никогда молча не добавляют low-confidence продукт; pantry не пересекается между пользователями/tenant; изменение servings корректно пересчитывает shopping list; offline изменения синхронизируются без потери отметок.

### COL-01 — Content kinds поверх recipe infrastructure

**Scope**

- Добавить `content_kind`: recipe/technique/process/video.
- Recipe сохраняет обязательные ingredients/servings/time.
- Technique/process допускают пустые ingredients и используют body/steps/video.
- Video требует video source и может иметь description/steps.
- Сохранить обратную совместимость `/recipes` и текущих Recipe DTO; добавить общий ContentItem mapper постепенно.

**Acceptance:** старые рецепты получают default `recipe`; conditional validation покрыта тестами; search/cards понимают kind; cooking CTA только у recipe/process с шагами.

### COL-02 — Collections schema/API и ordered content

**Scope:** `collections`, `collection_items`, tenant slug, localized title/description, cover, premium flag, publish status, ordered items, teaser; list/detail API с access rules.

**Acceptance:** item может входить в несколько коллекций; порядок стабилен; unpublished не виден consumer; one-off entitlement открывает только купленную коллекцию, subscription — правилами product.

### COL-03 — Collection list/detail/content UI

**Scope:** promo → collection detail; cover, author, description, ordered mixed items, locked previews, resume last item без LMS progress; content-kind detail variants.

**Acceptance:** free preview и locked items различимы; deep links/return after purchase; missing/broken video не ломает коллекцию.

### COM-01 — Products, entitlements и access service

**Scope:** tenant-scoped products/offers/product-content mapping/entitlements/purchase events; subscription and one-off scopes; idempotent access service; no price authority in DB/client.

**Acceptance:** entitlement содержит tenant + product + scope + source + status/expiry; access tests покрывают active, trial, grace, expired, refunded/revoked и one-off.

### COM-02 — Mobile store adapter и webhook verification

**Scope:** выбрать и задокументировать direct StoreKit/Play Billing или managed provider; adapter interface; store product loading; server webhook/receipt verification; sandbox setup.

**Decision gate перед задачей:** подтвердить billing provider и developer accounts. Default recommendation — managed provider для MVP, если стоимость и white-label multi-app policy приемлемы.

**Acceptance:** server, а не client, выдаёт entitlement; webhooks idempotent; duplicate/out-of-order events безопасны; секреты отсутствуют в app bundle.

### COM-03 — Purchase/restore/manage paywall integration

**Scope:** подключить UI-03 к store adapter; monthly/annual selection; eligibility; purchase/restore/manage; return-to-origin; analytics без финансовых PII.

**Acceptance:** success доступен только после подтверждённого entitlement; cancel не error; retry безопасен; restore работает после переустановки.

### COM-04 — One-off collection purchase

**Scope:** store product mapping коллекции, purchase CTA на collection, entitlement scope, refund/revoke, owned state.

**Acceptance:** покупка одной коллекции не открывает другую; подписчик видит корректное состояние; повторная покупка уже owned продукта невозможна.

### VOICE-01 — Microphone, transcript и intent UI

**Scope:** microphone button, permissions, listening/cancel, partial/final transcript, editable text, retry; включить `microphone=(self)` только после работающего consent flow.

**Acceptance:** typed input остаётся полноценной альтернативой; аудио не хранится по умолчанию; denied permission не блокирует поиск.

### VOICE-02 — Structured intent API и tenant retrieval

**Scope:** преобразовать текст в typed intent: occasion, ingredients available/excluded, dish type, protein, lightness, time, diet/allergens, servings; подтверждать неоднозначные критичные параметры; выполнять tenant catalog retrieval.

**Acceptance:** schema-validated output; prompt injection не меняет tenant/access filters; аллергенные ограничения применяются server-side.

### VOICE-03 — Ranking, no-match и recommendation analytics

**Scope:** ранжировать exact/partial matches, объяснять «почему подходит», показывать missing ingredients, корректировать intent, no-match CTA к AI generation.

**Acceptance:** AI generation никогда не запускается без отдельного согласия; ranking evaluation dataset включает пользовательские примеры из brief.

### AI-01 — Opt-in AI recipe generation в стиле автора

**Scope:** approved tenant style profile, retrieval только из разрешённого контента, structured recipe output, safety rules, cost/rate limits, streaming status.

**Acceptance:** генерация не выдаёт себя за опубликованный рецепт блогера; нет копирования premium body в ответ без entitlement; unsafe/unsupported запросы обрабатываются явно.

### AI-02 — Private generated drafts, safety и evaluation

**Scope:** private generated content table, save/edit/delete, AI label, allergen warning, feedback, evaluation set, retention policy.

**Acceptance:** draft видит только владелец внутри tenant; удаление реально удаляет/анонимизирует; quality/safety thresholds задокументированы.

### STUDIO-00 — Config CLI и asset pipeline v0

**Scope:** до Studio UI дать команде CLI для validate/publish pilot JSON, upload avatar, generate monogram/icon/splash/favicon candidates и bundled tenant artifact.

**Acceptance:** dry-run, field errors, immutable published version, rollback command; native assets не обещают runtime update.

### STUDIO-01 — Internal Studio drafts и previews

**Scope:** internal authentication/roles, draft editor, four sections 13m, unsaved changes, Home/Login/Paywall previews теми же tokens/components.

**Acceptance:** только internal role; preview не является скриншотом; concurrent edit conflict обнаруживается version check.

### STUDIO-02 — Asset upload, focal roles и validation

**Scope:** signed upload, dimensions/size/type checks, compression, focal editor, role assignment, crop previews, alt text, broken asset recovery.

**Acceptance:** rejected assets не публикуются; orphan cleanup; URL нельзя подменить на чужой tenant bucket.

### STUDIO-03 — Publish, rollback и build/release jobs

**Scope:** publish validation, audit log, runtime config status, web asset deploy, separate mobile build request/status/failure, rollback config, release history.

**Acceptance:** UI явно различает `config published`, `web deployed`, `mobile build pending`, `store release`; rollback не откатывает DB/content случайно.

### STUDIO-04 — Internal content, collections и merchandising

**Scope:** внутреннее создание/редактирование/publish рецептов, техник, процессов и видео; ingestion review; сборка упорядоченных коллекций; free previews; привязка store products/offers; scheduling и audit log.

**Acceptance:** draft/unpublished контент недоступен consumer API; preview использует consumer components; публикация атомарна; невозможно привязать material/product другого tenant; удаление опубликованного материала предупреждает о коллекциях и покупателях.

### OBS-01 — Analytics, privacy и monitoring

**Scope:** consent, tenant-safe event schema, activation/search/cooking/save/paywall/purchase/voice funnels, error tracking, API health, cost dashboards, data deletion.

**Acceptance:** ни один event не содержит transcript, email, ингредиенты здоровья или purchase receipt без отдельной необходимости/consent; tenant dashboards изолированы.

### LIFE-01 — Notifications и lifecycle campaigns

**Scope:** opt-in уведомления о новом контенте/коллекциях, напоминания о сохранённом/начатом приготовлении, timer alerts и сервисные purchase messages; quiet hours, preferences, deep links, frequency caps и tenant branding.

**Acceptance:** marketing выключен до consent; transactional и marketing категории разделены; deep link ведёт в правильный tenant/content; logout и account deletion удаляют push token binding.

### QA-REL — Release qualification

**Scope:** E2E guest/auth/subscriber/one-off; two-tenant isolation; store sandbox; offline/restart; accessibility; performance; deep links; auth callbacks; backup/rollback; legal/privacy/account deletion.

**Acceptance:** ноль P0/P1 defects; documented accepted P2; release checklist подписан; production secrets/readiness проходят.

### REL-01 — Staging pilot «Огороднік Олександр»

**Scope:** staging tenant/config/content/store sandbox, internal distribution, monitored pilot, feedback channel, rollback ready.

**Acceptance:** все critical journeys подтверждены на реальных iOS/Android/web устройствах; hero photos могут быть добавлены без изменения кода.

### REL-02 — Production release и rollback drill

**Scope:** production build assets, store metadata, privacy/legal, rollout, monitoring, config rollback и app rollback rehearsal.

**Acceptance:** phased rollout; alert owners; tested rollback; post-release smoke; no generic White Povar identity in installed pilot app.

### GROW-01 — Weekly menu planner

**Scope:** недельный календарь, добавление recipe/collection items, servings, drag/reorder, повтор блюд, объединение недостающих ингредиентов в shopping list и share плана.

**Acceptance:** entitlement проверяется при открытии premium item, а не при простом отображении slot; пересчёт servings детерминирован; offline edits безопасно синхронизируются.

### GROW-02 — Creator insights и experiments

**Scope:** tenant dashboard по discovery/save/cooking/conversion/collection performance; cohort/retention; privacy-safe campaign attribution; feature flags и A/B tests paywall/offers в рамках store policy.

**Acceptance:** creator не видит персональные данные пользователей или другой tenant; experiment assignment стабилен; guardrail metrics и stop conditions определены до запуска.

## 8. Обязательные проверки по типу задачи

### Flutter

```bash
cd frontend
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Для route/theme/layout задач дополнительно: targeted goldens на 390/768/1280 и production web build с `TENANT_SLUG`.

### Backend

```bash
cd backend
python3 -m pytest tests/ -v
python3 -c "from app.main import app; print(app.title)"
```

Для migrations/security: применить migration на disposable/staging database и выполнить integration tests с двумя tenant.

### Contract changes

- Backend schema test.
- Flutter JSON parsing test.
- Один общий fixture BrandConfig/bootstrap response.
- Backward compatibility или явная version negotiation.

### Design changes

- Light/dark.
- Pilot + три reference brands.
- Mobile/tablet/desktop.
- Loading/empty/error/offline/locked.
- Keyboard, semantics, 200% text scale.

## 9. Что пока требуется от владельца продукта

Ничего из нижеперечисленного не блокирует FND-00…QA-DS.

До COM-02 потребуется:

- Apple Developer и Google Play Console accounts;
- store product IDs для monthly, annual и one-off collection;
- решение по managed billing provider после оценки цены и multi-app условий.

До REL-01 потребуется:

- реальные hero-фотографии минимум 1600×1200;
- подтверждение или замена monogram avatar;
- support email, privacy policy, terms и social links;
- финальные цены/trial и название первой продаваемой коллекции;
- реальные материалы пилотной коллекции.

## 10. Definition of Done для каждого work package

Задача считается `DONE`, только если:

- реализован весь acceptance scope;
- нет несвязанных изменений;
- добавлены/обновлены тесты;
- обязательные проверки прошли либо конкретный внешний blocker записан;
- документация и contracts обновлены вместе с кодом;
- нет production debug controls, hardcoded цен, tenant IDs, secrets или ложных успешных действий;
- статус и журнал ниже обновлены.

## 11. Журнал выполнения

Добавлять новые записи сверху.

| Дата | ID | Результат | Проверки | Примечания |
|---|---|---|---|---|
| 2026-07-15 | AI-02 | Добавлены tenant- и owner-scoped private AI drafts: таблица с RLS, save/list/edit/delete API, immutable AI label и запрет попадания в `recipes`/catalog. Удаление — hard delete с каскадным удалением feedback; добавлены 30-дневная retention-функция и governance-документ. В AI preview добавлены сохранение private draft, постоянное аллергенное предупреждение, feedback и удаление. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_ai_recipe_generation.py -q` — PASS (6); полный `python3 -m pytest tests/ -q` — PASS (165); `backend/.venv/bin/flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format --output=none --set-exit-if-changed lib test` — PASS; `flutter analyze` — PASS; targeted `flutter test test/search_page_test.dart -r compact` — PASS (7); полный `flutter test -r compact` — PASS; `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS; `git diff --check` — PASS. | Scheduler обязан ежедневно вызывать `purge_expired_generated_recipe_drafts()` после применения migration. Evaluation release gates и versioned fixture документированы в `backend/docs/ai-drafts-governance.md`; real production evaluation требует human review и не выполнялась локально. Существующие Pydantic v2 deprecation warnings остаются вне scope. |
| 2026-07-15 | AI-01 | Добавлен аутентифицированный tenant-scoped SSE endpoint `POST /ai/recipe-generation/stream` и Flutter flow из voice no-match. Генерация возможна только после отдельного per-request opt-in; UI показывает streaming status и явную маркировку «Створено AI, не опублікований рецепт автора». Server-owned approved profile включён только для pilot tenant; model получает исключительно access-filtered metadata (title/tags/content kind) и никогда recipe body, включая premium ingredients/instructions. Structured output валидируется Pydantic; medical/unsafe requests возвращают явный отказ до retrieval/model; добавлены per-user/tenant rate limit и daily token budget. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_ai_recipe_generation.py tests/test_voice_intent_contract.py -q` — PASS (7); `backend/.venv/bin/flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; targeted `flutter test test/search_page_test.dart -r compact` — PASS (7); полный `flutter test -r compact` — PASS (76); CI-like `scripts/build-web.sh` с `TENANT_SLUG=ohorodnik-oleksandr` — PASS; `git diff --check` — PASS. После синхронизации локального окружения с pinned `backend/requirements-dev.txt` полный `python3 -m pytest tests/ -q` — PASS (162); FastAPI import — PASS. | AI-01 deliberately does not persist, edit, delete, collect feedback on, or retain generated recipes: private drafts and evaluation/retention are AI-02. Style-profile approval is server-owned and unknown tenants fail closed; deployment-wide cost accounting remains OBS-01 (AI-01 uses conservative process-local guard). Existing Pydantic v2 deprecation warnings are outside scope. |
| 2026-07-15 | VOICE-03 | `POST /search/intent/retrieve` теперь ранжирует tenant-scoped, access-filtered результаты по exact/partial совпадению и возвращает contract `recommendations`: безопасное объяснение, тип совпадения и до трёх недостающих ингредиентов. Экран поиска показывает «Чому підходить» с доступным подробным описанием; transcript остаётся редактируемым для коррекции intent. Голосовой no-match показывает CTA AI, но тот открывает только информирующий диалог: генерация не запускается и требует отдельного opt-in в AI-01. В server log добавлено privacy-safe агрегированное событие рекомендаций без transcript, ингредиентов, user или recipe IDs. Добавлен evaluation fixture с пилотными примерами brief и контрактные тесты ranking/explanations/missing ingredients. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_voice_intent_contract.py tests/test_search_catalog_contract.py -q` — PASS (7); `backend/.venv/bin/flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format` — PASS; `flutter analyze` — PASS; targeted `flutter test test/search_page_test.dart -r compact` — PASS (6); полный `flutter test -r compact` — PASS (84); `scripts/build-web.sh` with CI-like dart-defines and `TENANT_SLUG=ohorodnik-oleksandr` — PASS; `git diff --check` — PASS. Full `pytest tests/ -v`: 152 passed, 4 failed, 3 errors — pre-existing incompatible Starlette `TestClient`/installed `httpx` (`Client.__init__() got unexpected keyword argument 'app'`) in localization/video endpoint tests, unrelated to VOICE-03. | Не добавлялись AI recipe request/generation, style profile, drafts, safety, rate limits или cost tracking: это строго AI-01/AI-02. Analytics sink/consent routing остаётся OBS-01; VOICE-03 emits only aggregate safe server telemetry. Pydantic v2 deprecation warnings существовали ранее и вне scope. |
| 2026-07-15 | VOICE-02 | Добавлен tenant-scoped `POST /search/intent/retrieve`: локальный schema-validated parser извлекает occasion, available/excluded ingredients, dish type, protein, lightness, time, diets/allergens и servings из final transcript. Control/prompt-like фразы не влияют на intent, tenant или access; tenant берётся только из server context. Retrieval применяет typed filters и profile/intent allergens server-side, затем сохраняет существующий access/teaser contract. Неоднозначное «для сім’ї/на компанію» возвращает requirement подтвердить portions в редактируемом поле. Final voice transcript в Flutter использует этот endpoint; typed search остаётся прежней полноценной альтернативой. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_voice_intent_contract.py tests/test_search_catalog_contract.py -q` — PASS (5); `backend/.venv/bin/flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format` — PASS; `flutter analyze` — PASS; targeted `flutter test test/search_page_test.dart -r compact` — PASS (6); полный `flutter test -r compact` — PASS (84); CI-like `scripts/build-web.sh` with dart-defines and `TENANT_SLUG=ohorodnik-oleksandr` — PASS; `git diff --check` — PASS. | Не добавлялись ranking/explanations/missing-ingredients/no-match analytics или AI CTA: это строго VOICE-03/AI-01. Parser намеренно deterministic и не отправляет transcript в LLM; Pydantic 2 deprecation warnings существовали ранее и вне scope. |
| 2026-07-15 | VOICE-01 | В поиске добавлены microphone CTA, явный consent-dialog, listening/stop/cancel/retry states и partial/final украинский transcript через `speech_to_text`. Transcript остаётся в обычном editable search field и final text запускает существующий tenant-scoped catalog search; audio нигде не сохраняется и не отправляется приложением. Denied/permanently denied/unavailable показывают recovery, не блокируя typed search. Добавлены Android/iOS microphone/speech declarations и `microphone=(self)` только вместе с работающим consent flow. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; targeted `flutter test test/search_page_test.dart -r compact` — PASS (6); полный `flutter test -r compact` — PASS (84); production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS; `git diff --check` — PASS. | Не добавлялись typed intent API, retrieval/ranking, analytics или AI fallback: это VOICE-02/03 и AI-01. Фактические system/browser prompts требуют проверки на поддерживаемых устройствах; приложение не пишет аудио на диск и не передаёт его backend. |
| 2026-07-15 | COM-04 | Не начата реализация: prerequisite COM-03 остаётся `BLOCKED`, поскольку COM-02 не завершена. Код, store product mappings, CTA и entitlement scope не менялись, чтобы не обходить обязательную server-verified purchase/restore integration. | `git status --short` — PASS (clean); сверка queue, COM-03/COM-04 scope и `backend/docs/commerce-revenuecat.md` — PASS. | **BLOCKED:** требуются Apple Developer, Google Play Console и RevenueCat accounts; нужны one-off collection products, active tenant mappings и `REVENUECAT_WEBHOOK_AUTHORIZATION` с работающим webhook. До этого нельзя безопасно проверить purchase одной collection, subscriber state, refund/revoke или запрет повторной покупки. |
| 2026-07-15 | COM-03 | UI-03 подключён к mobile store adapter: годовой/месячный варианты выбираются отдельно от CTA; StoreKit/Play Billing запускает purchase/restore, завершает pending transaction и никогда сам не открывает premium UI. После store result клиент читает новый authenticated tenant-scoped `GET /commerce/entitlement-status` и ожидает server-issued entitlement от webhook; только active/trial/grace открывают access. Cancel остаётся нейтральным состоянием, повторные запросы блокируются, manage ведёт в нативное управление подписками; web по-прежнему честно unavailable. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; targeted `flutter test test/subscription_screen_test.dart -r compact` — PASS (16); backend targeted entitlement/webhook contracts и `python3 -m compileall -q app` — PASS; `git diff --check` — PASS. | **BLOCKED:** COM-02 всё ещё не завершён из-за отсутствия Apple Developer, Google Play Console и RevenueCat accounts, store products, active tenant mappings и webhook secret/configuration. Поэтому нельзя подтвердить реальную restore-after-reinstall и provider webhook delivery. Не добавлялись one-off collection mapping/CTA/owned state (COM-04), цены, product IDs, financial PII analytics или client-side entitlement grants. |
| 2026-07-15 | COM-02 | Выбран managed provider RevenueCat и добавлен tenant-scoped mobile store catalog: production iOS/Android adapter получает только server-mapped StoreKit/Play product IDs и читает локализованные title/price из native store SDK. Web остаётся честно unavailable; checkout, restore и manage намеренно не включались до COM-03. Добавлены `store_product_mappings`, tenant trigger и транзакционный `process_revenuecat_event`: webhook с server-only Authorization сначала дедуплицирует event ledger, отвергает unmapped products, не позволяет older event перезаписать entitlement и только затем создаёт/обновляет server-side subscription entitlement. Документированы provider decision и sandbox rollout. | `python3 -m compileall -q app` — PASS; targeted commerce contracts — PASS (10); isolated `backend/.venv`: полный `pytest tests/ -q` — PASS (153), `flake8 app/ --select=E9,F63,F7,F82` — PASS; Flutter `dart format`, `flutter analyze`, targeted subscription test — PASS (16), полный `flutter test -r compact` — PASS; CI-like `scripts/build-web.sh` — PASS; `git diff --check` — PASS. | **BLOCKED:** SQL migration не применялась: локальной безопасной disposable DB и Apple/Google/RevenueCat accounts нет. Перед sandbox нужны accounts, products, active mappings и `REVENUECAT_WEBHOOK_AUTHORIZATION` в Render/RevenueCat (checklist в `backend/docs/commerce-revenuecat.md`). One-off mapping/scope и consumer purchase/restore/manage остаются строго COM-03/COM-04. Существующие Pydantic 2 deprecation warnings остаются вне scope. |
| 2026-07-15 | COM-01 | Добавлены tenant-scoped `products`, `offers`, `product_content`, `commerce_entitlements` и идемпотентный `purchase_events` ledger. Схема запрещает cross-tenant product/offer/content/entitlement links, переносит legacy `tenant_entitlements` в единую модель и не хранит цены или store product IDs. Единый server-side access service признаёт только active/trial/grace в пределах срока: subscription открывает tenant content, one-off — только collection, явно указанную и в entitlement scope, и в product mapping. Collection detail использует это scoped grant для своих ordered items, не расширяя direct recipe access. | `python3 -m compileall -q app` — PASS; targeted commerce/collection/tenant contracts — PASS (13); isolated `backend/.venv`: полный `pytest tests/ -q` — PASS, FastAPI import/route assertion — PASS и `flake8 app/ --select=E9,F63,F7,F82` — PASS; `git diff --check` — PASS. | SQL migration не применялась: локальной безопасной disposable DB нет. COM-02 всё ещё владеет billing provider, store IDs, receipt/webhook verification и sandbox setup; COM-03/04 — purchase, restore/manage и consumer CTA. Существующие Pydantic 2 deprecation warnings остаются вне scope. |
| 2026-07-15 | COL-03 | Добавлены typed Flutter collection model/service/providers, `/collections` list и `/collections/:id` detail route поверх COL-02 API. Home promo находит published collection по `courseTag`/slug и ведёт напрямую в detail (иначе честно показывает list). Detail показывает cover/fallback, автора, description и стабильный mixed-content order. Preview, locked items и full collection gate имеют разные labels/semantics; locked CTA сохраняет detail `returnTo` и использует только существующие login/paywall routes. Последний открытый item сохраняется как ID для `Продовжити`, а не как LMS progress, и очищается при logout. Recipe model учитывает server `is_locked`; recipe/process/video используют прежние detail routes и video fallback UI-05. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; targeted collection model + recipe-detail/route tests — PASS (9); полный `flutter test -r compact` — PASS (82); `git diff --check` — PASS. Web blocker снят: `flutter clean`, `flutter pub get`, затем production `scripts/build-web.sh` с CI-like dart-defines — PASS (созданы свежие `build/web/index.html` и `main.dart.js`). | Не добавлялись product mapping, prices, one-off purchase, purchase/restore или entitlement events: это COM-01…04. Нет LMS modules/progress: сохранён только локальный resume ID. Нет новых content payloads или video transport; broken/missing video остаётся безопасным fallback текущего UI-05. |
| 2026-07-15 | COL-02 | Добавлены tenant-scoped `collections` и `collection_items`: локализованные `title_i18n`/`description_i18n`, cover, premium/status/publish metadata и уникальный стабильный `position`. Один content item может состоять в нескольких коллекциях; SQL trigger запрещает присоединять content другого tenant. Добавлены consumer `GET /collections` и `GET /collections/{id}`: возвращаются только published записи resolved tenant, list/detail локализуют metadata, а locked premium collection отдаёт только ordered content teasers без steps/ingredients/video. Access вынесен в `resolve_collection_access`; текущий tenant subscription entitlement открывает premium collection, а COM-01 расширит ту же точку one-off scoped entitlement’ами. | `python3 -m compileall -q app` — PASS; targeted collection/recipe/tenant contracts — PASS (15); isolated `backend/.venv`: полный `pytest tests/ -q` — PASS (142), FastAPI import/route assertion — PASS и `flake8 app/ --select=E9,F63,F7,F82` — PASS; `git diff --check` — PASS. | SQL migration не применялась: локальной безопасной disposable DB нет. Нет authoring/update API, collection UI, product mapping, purchase или entitlement event schema — это STUDIO-04, COL-03 и COM-01…04. RLS оставляет consumer-visible rows только published; API с service role дополнительно применяет tenant/access projection. |
| 2026-07-15 | COL-01 | В `recipes` добавлен additive `content_kind` (`recipe`/`technique`/`process`/`video`) с default `recipe`, constraint и tenant index. Сохранён `/recipes` и существующий Recipe DTO; общий `_content_item_from_row` постепенно заменил дублированный mapper list/featured и сохраняет legacy rows как `recipe`. Create validation требует ingredients и steps у recipe, разрешает пустые ingredients у technique/process и требует video URL/file у video. Flutter model безопасно default-ит legacy/unknown kind к recipe; cards показывают тип, а cooking CTA/route разрешены лишь recipe/process со steps. | `python3 -m compileall -q app` — PASS; targeted backend contracts — PASS (15); FastAPI import — PASS; isolated `backend/.venv`: полный `pytest tests/ -q` — PASS (138) и `flake8 app/ --select=E9,F63,F7,F82` — PASS. Flutter: format, `flutter analyze`, targeted content/detail tests — PASS (5), полный `flutter test` — PASS (80); `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | SQL migration не применялась: локальной безопасной disposable DB нет. Обновление существующего content item и Studio authoring остаются в STUDIO-04; schema/API ordered collections, collection UI и access products намеренно не добавлялись (COL-02/03, COM-01). Существующие Pydantic 2 deprecation warnings остаются вне scope. |
| 2026-07-15 | CORE-06 | Добавлены tenant- и user-scoped pantry/shopping tables с RLS, authenticated API и Flutter экран. Pantry поддерживает ручной ввод, optional amount/unit/freshness и подтверждённые camera results; сервер отклоняет неподтверждённые или low-confidence camera позиции. Shopping list группируется по категориям, хранит checkmarks, допускает ручное добавление и добавляет только отсутствующие ингредиенты рецепта с пересчётом по servings. Pending network mutations сохраняются локально и повторяются при следующем чтении, поэтому checkmark не теряется при offline. | `dart format` — PASS; `flutter analyze` — PASS; полный `flutter test` — PASS (78); targeted pantry Flutter tests — PASS (2); production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. `python3 -m compileall -q app`, targeted `test_pantry_contract.py` — PASS (2), isolated `backend/.venv` полный `pytest tests/ -q` — PASS (135), FastAPI import — PASS. | Migration не применялась к disposable/staging DB: локально безопасной disposable Supabase DB нет. Voice source поддержан контрактом, но UI microphone/transcript намеренно не создавался до VOICE-01. Collections отсутствуют до COL-01/02, поэтому add-from-collection не добавлялся. |
| 2026-07-15 | CORE-05 | Добавлены consented tenant-scoped profiles (`diet`, allergens, dislikes, preferred time/equipment, household size), migration с `users`/`chefs` FK и RLS, а также authenticated GET/PUT/DELETE API. Profile UI ведёт на защищённый экран редактирования и полного сброса. Catalog search применяет consented diet/time inputs на сервере и исключает совпадения allergens/dislikes по tags и ingredient names; аллерген не используется как ranking signal и не возвращается клиенту. | `dart format --output=none --set-exit-if-changed test/preference_profile_test.dart`, `flutter analyze`, targeted Flutter JSON-contract test — PASS; полный `flutter test` — PASS (75); isolated `backend/.venv`: targeted contract tests — PASS (5), полный `pytest tests/ -v` — PASS (133), `python3 -m compileall -q app`, FastAPI import и `flake8 app/ --select=E9,F63,F7,F82` — PASS; production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Применение SQL migration к disposable/staging Supabase не выполнялось в локальном окружении без безопасной disposable DB; migration готова к обычному deployment flow. Existing Pydantic 2 deprecation warnings остаются вне scope. Pantry/shopping list, camera/voice input и отдельный recommendation engine не добавлялись: они принадлежат CORE-06/VOICE-01…03. |
| 2026-07-15 | CORE-04 | Завершены auth flows поверх текущего Supabase Auth: единый web/mobile callback для signup, reset, OAuth и linking; signup без session показывает policy подтверждения email; OAuth callback синхронизирует пользователя с backend. Profile позволяет подключить Google identity и удалить аккаунт с явным подтверждением. `DELETE /auth/me` удаляет private application record (cascade для favorites/history/entitlements), затем Supabase identity; logout/deletion очищают private local data. Guest save intents теперь durable и после login мигрируют на authenticated favorites с очисткой только после успешной mutation. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_security.py tests/test_auth_completion_contract.py -q` — PASS (11); isolated `backend/.venv`: `pytest tests/ -q` и `flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format --output=none --set-exit-if-changed .`, `flutter analyze` и полный `flutter test` — PASS; production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Полный backend suite в global Python environment остаётся BLOCKED на pre-existing Starlette `TestClient` / установленном новом `httpx` (4 failed, 3 errors); validation выполнена в requirements-dev `.venv` с pinned `httpx==0.25.2`. Модель и UI preferences намеренно не добавлялись: они принадлежат CORE-05; миграция сохраняет только существующие guest saved intents. Supabase project configuration всё ещё должна разрешать callback URLs `WEB_APP_URL/auth/callback` и `io.supabase.cookingapp://login-callback`, а email confirmation — оставаться включённым. |
| 2026-07-15 | CORE-03 | Добавлены tenant-scoped private view/cook history migration и API, active cooking persistence (recipe snapshot, step, timer) через restart/offline, wake lock в cooking mode и offline fallback для cached Saved recipes. Detail best-effort записывает view, completion — cooked; logout очищает private local history/progress. Таймер отображается in-app и не создаёт notification без отдельного opt-in. | `python3 -m compileall -q app` — PASS; targeted `pytest tests/test_history_contract.py tests/test_recipe_contract.py tests/test_tenant_isolation_contract.py -q` — PASS (11); isolated `.venv`: `pytest tests/ -q` — PASS (129), `flake8 app/ --select=E9,F63,F7,F82` — PASS; `dart format --output=none --set-exit-if-changed .`, `flutter analyze` и полный `flutter test` — PASS (61); production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не добавлялись push/local notifications, cloud sync очереди или history/profile UI: notifications требуют отдельного consent flow, а расширенный conflict/sync UX остаётся для последующих product packages. Global Python full suite несовместим с установленным новым `httpx`; validation выполнена в requirements-dev `.venv` с pinned `httpx==0.25.2`. |
| 2026-07-15 | CORE-02 | Добавлены `GET /search/catalog` и tenant-scoped Supabase query с server-side text/tag/difficulty/time/featured filters, exact count и стабильным `created_at,id` ordering для offset pagination. Search response возвращает `next_offset`/`has_more`; locked premium rows остаются discoverable только как teaser через существующий access layer. Flutter search переключён на catalog endpoint; `ApiRecipeRepository`, `RecipeListNotifier` и filter-options provider больше не загружают полный список для client-side filtering. Добавлены backend contract tests и test auth override для search fixture. | `python3 -m compileall -q app` — PASS; `pytest tests/test_search_catalog_contract.py tests/test_tenant_isolation_contract.py tests/test_recipe_contract.py -q` — PASS (11); `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; targeted `flutter test` — PASS (10); полный `flutter test` — PASS (73); production `scripts/build-web.sh` с CI-like dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не добавлялись persisted search history, preferences/allergen ranking, ingredient matching, collections/content kinds или AI retrieval: это CORE-03/CORE-05/COL-01/VOICE-02. Offset contract детерминирован, но cursor migration не нужна до роста каталога. |
| 2026-07-15 | CORE-01-FIX | Закрыт локальный build blocker из записи CORE-01: остановлены осиротевшие процессы предыдущего `flutter build web`, после чего production web build заново сгенерировал актуальные `build/web` artifacts и процессы завершились. | `scripts/build-web.sh` с test `API_BASE_URL`, `WEB_APP_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ENVIRONMENT=ci` и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Код CORE-01 не менялся; это только cleanup локального Flutter compiler process и повторная верификация. |
| 2026-07-15 | CORE-01 | Добавлен canonical in-memory favorite store: карточки Home/Search/Saved/Camera и detail используют общий save control; authenticated mutation оптимистична, serializes desired states per recipe, делает rollback при ошибке и показывает undo. Guest intent сохраняется до login и применяется после auth; logout очищает private state и Saved provider. API переведён с toggle на идемпотентный `PUT` desired-state contract, а backend проверяет recipe внутри resolved tenant до записи. Добавлены Flutter tests для быстрых taps и guest migration, обновлён backend contract test. | `flutter analyze` — PASS; `flutter test` — PASS (полный suite); targeted `pytest tests/test_recipe_contract.py -q` — PASS (6); `python3 -m compileall -q app`, полный `pytest tests/ -q` и FastAPI import — PASS. `dart format` применён; `--set-exit-if-changed` локально возвращает false-positive `Changed` при неизменном содержимом файла на Dart 3.5.4. Production `scripts/build-web.sh` с test dart-defines начал `Compiling lib/main.dart for the Web...`, но локальный process не вернул final status через terminal bridge. | Не добавлялись history/cooking/offline persistence, auth signup/linking/deletion, search pagination или commerce. Server tenant check сохранён; client tenant header не используется как authorization. |
| 2026-07-15 | QA-DS | Добавлены единая QA design matrix и `qa_design_matrix_test.dart`: pilot + три reference BrandConfig рендерятся в light/dark на 390/768/1280; проверены 200% scale, reduced motion, accessible navigation, semantics, keyboard submit и contrast. `QA_DESIGN_MATRIX.md` сопоставляет UI-01…UI-07 states с уже существующими smoke/screen/golden tests и фиксирует policy platform rendering tolerances. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (71), включая QA-DS matrix и существующие 390/768/1280 goldens; production `scripts/build-web.sh` с test dart-defines, `ENVIRONMENT=ci` и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не добавлялись product flows, новые routes, runtime brand fallbacks или assets. Reference-brand matrix намеренно structural/token-based, а checked-in pixel goldens сохраняются для pilot: font hinting, antialiasing и native camera/video pixels фиксируются state/semantics/layout tests, не platform-sensitive snapshots. |
| 2026-07-15 | ENV-FIX | Закрыты два технических follow-up: production `scripts/build-web.sh` снова завершился после очистки зависшего локального Flutter процесса; backend проверен в чистом Python 3.13 virtualenv, установленном из `requirements-dev.txt`. README теперь предписывает isolated `.venv` и полный dev requirements, чтобы глобальный `httpx` не мог заменить зафиксированный `0.25.2`, совместимый со Starlette `TestClient`. | Production web build с test dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS; Python 3.13 venv: `pytest tests/ -q` — PASS (125), `flake8 app/ --select=E9,F63,F7,F82` — PASS (0). | Остаются только Pydantic 2 deprecation warnings; они не являются failures и не относятся к текущим follow-up. |
| 2026-07-15 | TEST-FIX | Исправлен зафиксированный blocker Flutter test suite: `recipe_detail_page_test.dart` теперь переопределяет `authProvider` через `AuthNotifier.testing()`, поэтому fixture не обращается к неинициализированному `Supabase.instance`. | `flutter test test/recipe_detail_page_test.dart` — PASS (3); полный `flutter test` — PASS (68). | Изменён только тестовый fixture; production auth и UI‑05 scope не менялись. |
| 2026-07-15 | UI-07 | Изменены camera capture/review/results foundations, permission state/service, confidence parsing и UI-07 tests/goldens. Camera flow теперь принудительно использует dark theme независимо от app theme; capture сохраняет native camera + gallery и явный browser upload fallback. Denied permission повторно запрашивается, permanently denied ведёт в system settings; в обоих случаях галерея остаётся доступна. Low-confidence detection (<70%) не подтверждается автоматически; review поясняет необходимость подтверждения/удаления и не запускает поиск, пока такие позиции не обработаны. Добавлены targeted tests и goldens для recovery на 390/768/1280. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test test/ui_07_camera_test.dart` — PASS (5); UI-07 golden update/check 390/768/1280 — PASS. Полный `flutter test` — BLOCKED на pre-existing `recipe_detail_page_test.dart`: fixture создаёт `RecipeDetailPage` без override `authProvider`, поэтому вызывает неинициализированный `Supabase.instance` (3 failures); UI-07 tests проходят. Production `scripts/build-web.sh` с test `API_BASE_URL`, `WEB_APP_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TENANT_SLUG=ohorodnik-oleksandr` и `ENVIRONMENT=ci` — BLOCKED локально: `flutter build web` остался без дочернего compiler process и вывода свыше 3 минут после `Compiling lib/main.dart for the Web...`; процесс этой задачи остановлен. | Не добавлялись pantry/shopping list, persist scan history, server-side ingredient matching, camera hardware preview, OCR model или новые routes: это CORE-06/CORE-03 и последующие product packages. Текущие capture/upload и backend photo-search adapter сохранены. |
| 2026-07-15 | UI-06 | Изменены `saved_page.dart`, `profile_page.dart`, `settings_page.dart`, shared `UserAvatar`, добавлены `ProductConfig`, UI-06 tests/goldens и plan. Saved/Profile получили единый guest/auth presentation: CTA на login сохраняют исходный `/saved` или `/profile`; user avatar всегда остаётся глифом/инициалами без blogger avatar. Profile содержит entry для subscription, read-only placeholders для будущих saved/history/scan stats и без ложных CORE-01 действий. Settings переиспользует persisted `ThemeMode` через segmented control; support/legal placeholders и версия берутся из `ProductConfig`, без production URLs до их утверждения. Добавлены Profile guest goldens на 390/768/1280. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test test/ui_06_pages_test.dart test/brand_theme_test.dart` — PASS (6); UI-06 golden update/check 390/768/1280 — PASS; production `scripts/build-web.sh` с test `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. Полный `flutter test` — BLOCKED на pre-existing `recipe_detail_page_test.dart`: тест создаёт `RecipeDetailPage` без override `authProvider`, вследствие чего обращается к неинициализированному `Supabase.instance`; отдельный повтор воспроизводит тот же сбой. | Не добавлялись favorite mutation/optimistic save, history, cooking progress, notification switches, локализация или реальные legal/support endpoints: это CORE-01, CORE-03, LIFE-01 и product configuration перед REL-01. Неисправный UI-05 test fixture не менялся, так как он не входит в UI-06 scope. |
| 2026-07-15 | UI-05 | Изменены `recipe_detail_page.dart`, `cooking_mode_page.dart`, shared `content_detail_sections.dart`, `recipe_detail_page_test.dart`, plan. Detail получил immersive hero, adaptive mobile/tablet и desktop dual-pane composition, stats, shared ingredients/steps sections, loading skeleton, offline/error retry и sticky cooking CTA. Premium detail строит только title/hero/stats и gate: ingredients, steps и video не попадают в UI tree; cooking route повторно применяет gate. Cooking mode получил один крупный шаг, progress, desktop step list, финальный state и подтверждение выхода. Переиспользован существующий `RecipeVideoWidget`: direct/external video fallback и lifecycle dispose сохранены. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (59), включая UI-05 locked-payload и 390/768/1280; `scripts/build-web.sh` с test `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не добавлялись save mutation, cooking progress persistence, ratings, timers, content-kind model/API или коллекции: это CORE-01, CORE-05 и COL-01…03. Gate является presentation safety layer; entitlement всё ещё подтверждается server-side SEC-01 contract. |
| 2026-07-15 | UI-04 | Изменены `search_page.dart`, `search_provider.dart`, `search_page_test.dart`, plan. Search `/search` переведён на discovery composition: search field, session recent/suggestions, filter controls, прямой deep link `tag=maisternia-oleksandra`, premium teaser, recovery для no-results, skeleton loading и error/retry. Query и tag теперь сериализуются в web URL. Реализованы mobile 1-column, tablet 3-column и desktop 420px master-detail layouts; notifier сохраняет только актуальный результат после debounce/cancel. Добавлены UI-04 tests для URL, tag deep link, 390/768/1280 и stale-result cancellation. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (56); `scripts/build-web.sh` с test `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Server-side filters, pagination, persisted search history и расширение search API намеренно не добавлялись: это CORE-02. Detail остаётся существующим route/UI-05 scope; premium payload по-прежнему определяется SEC-01 server contract. |
| 2026-07-15 | UI-03 | Paywall `/subscription` и `/offers/:offerId` переведён на brand-driven layouts 13h: mobile route и 560px dialog ≥600, paywall hero/fallback, offer/status presentation. Добавлен purchase-adapter boundary: debug/tests получают fake catalog, production до COM-02 показывает products-unavailable и не может начать покупку. Отдельно покрыты idle, loading, unavailable, purchasing, success, error, user-cancel, active, grace, billing retry, expired и cancelled; restore/manage показываются только в релевантных состояниях, повторный tap не запускает вторую покупку. Добавлены goldens 390/768/1280 и 200% text-scale test. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (52), включая UI-03 states и 390/768/1280 goldens; production `scripts/build-web.sh` с test dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Реальные StoreKit/Google Play products, checkout, restore verification, entitlement refresh и manage deep links не реализованы: это COM-02/COM-03. Цены существуют только в `FakePurchaseAdapter` для debug/tests; production adapter не содержит product IDs или цен. |
| 2026-07-15 | UI-02 | Login переведён на brand-driven тёмный layout: `login` hero с fallback, 72px avatar, signup, inline validation, password visibility/autofill/focus, отдельный reset screen с одинаковым sent result, Google/Apple loading/error и guest entry. Desktop ≥1024 использует split hero/form max 440; добавлены 390/768/1280 goldens и 200% text-scale test. User-cancelled/unopened OAuth возвращает нейтральное unauthenticated state; provider collision подготовлен безопасным UI banner до backend CORE-04. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (36), включая UI-02 states, 390/768/1280 goldens и 200%; `scripts/build-web.sh` с production dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не реализовывались email verification, реальное linking/collision resolution, account deletion или guest migration: это CORE-04. Reset intentionally never reveals account existence. |
| 2026-07-15 | UI-01 | Home переведён на пилотный `BrandConfig`: shared `BrandHeader` показывает блогера, `UserAvatar` — только профиль пользователя; greeting и условное promo берутся из config. Promo без пары `courseName/courseTag` скрыт, а CTA ведёт guest на login, free user на paywall, premium user на tag-filtered search. Добавлены adaptive Home layouts: центрированный 480px mobile/tablet feed и desktop master-detail. Loading/empty/error/offline retry сохранены, bookmark явно disabled до CORE-01. Runtime BrandConfig теперь парсит и валидирует conditional pair. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (31), включая Home на 390/768/1280; `scripts/build-web.sh` с production dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Не добавлялись save mutation, collection detail или billing: это scope CORE-01/COL-03/COM-03. Hero photo не требуется для Home и не создаёт новой asset dependency. |
| 2026-07-15 | DS-01 | Добавлены общие `AppButton`, `AppIconButton`, `AppTextField`, `AppChip`, `AppBadge`, `ContentCard`, `BrandHeader`, `UserAvatar`, `AppSkeleton`, `ResponsiveContainer` и helpers Sheet/Dialog. `StateView` переведён на shared button, а карточка рецепта — на общий card primitive; новые controls используют Material focus/keyboard states, semantics и минимальный tap target 44px. Добавлены light/dark pilot widget tests и golden для набора primitives. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (30); targeted golden — PASS; `scripts/build-web.sh` с build-only production dart-defines и `TENANT_SLUG=ohorodnik-oleksandr` — PASS. | Экранные частные реализации и их product-specific composition намеренно не удалялись: их перевод относится к DS-02 и UI-01…UI-07. Не добавлялись новые product flows или routing. |
| 2026-07-15 | DS-02 | Tab navigation переведена на `StatefulShellRoute.indexedStack`: Home, Search, Saved и Profile сохраняют свой state/scroll; settings, offer/paywall, recipe/content detail, cooking и camera вынесены в самостоятельные route branches без tab navigation. Добавлены typed search/tag, content, collection и offer return-path links, безопасный guest → login → origin redirect и адаптивный shell (bottom <600, rail ≥600, desktop composition ≥1024). | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter analyze` — PASS; `flutter test` — PASS (30); targeted adaptive route tests на 390/768/1280 — PASS; CI-like `scripts/build-web.sh` с `TENANT_SLUG` — PASS. | Коллекция пока имеет только нейтральную route-ветку: полноценный collection screen остаётся в COL-03. Доступ к premium content по-прежнему подтверждает серверный entitlement contract SEC-01; routing не доверяет client `isPremium`. Незакоммиченные файлы DS-01 не изменялись и не входят в DS-02 commit. |
| 2026-07-15 | SEC-01 | Добавлены обязательный resolved `X-Tenant-Slug` context, tenant-scoped запросы recipes/featured/favorites/search/suggestions/filters/photo и AI context. Исключены caller-supplied chef filters; detail и list используют единый access service. Premium rows остаются discoverable как `is_locked` teaser без ingredients, instructions, nutrition и video URLs. Добавлены tenant-scoped entitlements, RLS hardening и двух-tenant contract tests с одинаковым title. | `python3 -m compileall -q app` — PASS; targeted `pytest` (recipe, tenant isolation, bootstrap) — PASS (17); FastAPI import — PASS; полный `pytest tests/ -q`: 118 passed, 4 failed, 3 errors. | Полный suite сохраняет известный внешний blocker локального Python 3.13: несовместимые Starlette `TestClient`/httpx (`Client.__init__(app=...)`) ломают прежние localization/video-тесты. `flake8` не установлен локально; CI запускает lint на Python 3.11. Миграция не применялась: локальной изолированной БД нет; production/staging не затрагивались. |
| 2026-07-15 | FND-05 | Recipe, search, photo-search и subscription сервисы переведены на единый `ApiClient`; transport добавляет tenant slug, locale, request ID и bearer token только при наличии сессии. Typed `ApiError` различает 401/403/404/409 и network errors; text search получил debounce и отмену предыдущего запроса. Удалены production debug controls, выдававшие premium. | `dart format --output=none --set-exit-if-changed lib test` — PASS; `flutter test` — PASS (21); `flutter analyze` — PASS; `scripts/build-web.sh` с production dart-defines — PASS. | `HttpBrandBootstrapRemoteLoader` остаётся явным startup migration adapter: он загружает bootstrap до создания Riverpod/`ApiClient`; после bootstrap config-запросы используют общий transport. Tenant header передаёт context и не служит авторизацией; её проверка остаётся server-side scope SEC-01. |
| 2026-07-15 | FND-04 | Добавлены bundled Figtree, JetBrains Mono, Source Serif 4, Golos Text и Lora; `BrandThemeExtension` строит light/dark темы из validated derived tokens, а `ThemeMode.system/light/dark` сохраняется в SharedPreferences. Добавлены безопасные avatar/logo/hero fallbacks и доступный при 200% text scale выбор темы; camera flow сохраняет dark contract и использует dark brand accent при наличии brand theme. | `dart format --output=none --set-exit-if-changed .` — PASS; `flutter test` — PASS (18); `flutter analyze` — PASS; `scripts/build-web.sh` с production dart-defines — PASS. | Premium gold и system success/warning/error остаются system tokens, не tenant-brand roles. Полноценное подключение новых asset widgets к экранным компонентам и перевод legacy screen-level colours — scope последующих DS-01/UI packages; FND-04 не меняет product flows. |
| 2026-07-15 | FND-03 | Добавлены immutable Dart-модели BrandConfig/TenantBootstrap с fail-closed parsing, bundled validated pilot bootstrap и monogram SVG. Startup выбирает bundled → valid cache, запрашивает remote не дольше 3 секунд и сохраняет валидный ответ только для следующего cold start; app получает tenant bootstrap через Riverpod до `MaterialApp`. | `dart format` — PASS; `flutter test` — PASS (14); `flutter analyze` — PASS; `scripts/build-web.sh` с production dart-defines — PASS. | Remote brand намеренно не применяется в активной сессии. Corrupt/mismatched cache и invalid/timeout remote безопасно оставляют cached или bundled tenant; generic White Povar fallback не используется. Dynamic theme/assets rendering остаются FND-04, общий API client — FND-05. |
| 2026-07-15 | FND-02 | Добавлен единый Pydantic publish-gate BrandConfig: лимиты, кириллица, URL, `courseName`/`courseTag`, font enum, hero roles/focal и вычисляемые OKLCH tokens. Bootstrap fail-closed для невалидного published config. Добавлены pilot JSON fixture, optional SQL seed и monogram avatar 512×512. | `test_brand_config.py` + `test_bootstrap_contract.py`: 19 passed; FastAPI import и `compileall` — PASS; полный `pytest tests/ -v`: 113 passed, 4 failed, 3 errors. | Полный suite сохраняет известный внешний blocker локального Python 3.13: несовместимые Starlette `TestClient`/httpx ломают старые middleware/video-тесты. Seed migration не применялась: в workspace нет `psql`/изолированной БД; production/staging не затрагивались. Reference color tests фиксируют правило из раздела 3 (`OKLCH L × 0.88`) и contrast gates; Flutter parsing/theme и Studio UI остаются FND-03/FND-04/STUDIO-01. |
| 2026-07-15 | FND-01 | Добавлены unique `chefs.slug`, versioned `brand_configs` и отдельные `product_configs` с одним published config на tenant, RLS и published indexes. Реализован публичный `GET /api/v1/bootstrap/{tenant_slug}` с ETag/config version, 304 и fail-closed 404/409. | Новый contract suite: 7 passed; FastAPI bootstrap import и compileall — PASS; полный `pytest tests/ -v`: 103 passed, 4 failed, 3 errors. | Остаточный внешний blocker не изменился: локальный Python 3.13 имеет несовместимые Starlette `TestClient`/httpx (`Client.__init__(app=...)`), из-за чего падают старые middleware/video-тесты. CI закреплён на Python 3.11. Schema-level BrandConfig validation, derivation и pilot seed остаются FND-02. |
| 2026-07-15 | FND-00 | `frontend/` закреплён как canonical production app; Flutter pin вынесен в `frontend/.flutter-version`; CI/Render используют общий web-build contract с обязательным `TENANT_SLUG`; local development сохраняет pilot default. Добавлены config test и воспроизводимые local CI команды. | Frontend: format, analyze, 10 tests и web build — PASS; production build без `TENANT_SLUG` — ожидаемо FAIL с понятной ошибкой; FastAPI import — PASS. Backend: 96 passed, 4 failed, 3 errors. | Follow-up (вне scope): локальный Python 3.13 имеет несовместимую пару Starlette `TestClient`/httpx (`Client.__init__(app=...)`); CI закреплён на Python 3.11. Не исправлялось. Несвязанные существующие изменения `frontend/firebase.json`, `frontend/web/index.html`, `render.yaml` сохранены. |
| 2026-07-15 | PLAN | Создан детальный implementation plan и pilot BrandConfig | Проверка структуры/контрактов вручную | Код приложения не изменён |
