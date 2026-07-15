# White Povar — детальный план имплементации

Дата: 15 июля 2026  
Статус: FND-02 выполнена; BrandConfig валидируется и пилотный seed подготовлен.  
Следующая задача: `FND-03`  
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
| 4 | FND-03 | Flutter bootstrap, cache и bundled fallback | FND-02 | TODO |
| 5 | FND-04 | Dynamic themes, fonts и brand assets | FND-03 | TODO |
| 6 | FND-05 | Единый API client и tenant context | FND-03 | TODO |
| 7 | SEC-01 | Tenant isolation и premium teaser contract | FND-05 | TODO |
| 8 | DS-01 | Shared design-system primitives | FND-04 | TODO |
| 9 | DS-02 | Routing и adaptive shell | DS-01 | TODO |
| 10 | UI-01 | Home + brand header + collection promo | DS-02, SEC-01 | TODO |
| 11 | UI-02 | Login/signup/forgot-password states | DS-01, FND-03 | TODO |
| 12 | UI-03 | Paywall visual states без real billing | DS-01, FND-03 | TODO |
| 13 | UI-04 | Search/discovery design parity | DS-02, SEC-01 | TODO |
| 14 | UI-05 | Recipe detail и cooking design parity | DS-01, SEC-01 | TODO |
| 15 | UI-06 | Saved, Profile и Settings design parity | DS-02 | TODO |
| 16 | UI-07 | Camera flow design parity | DS-01 | TODO |
| 17 | QA-DS | Design matrix, goldens и accessibility | UI-01…UI-07 | TODO |
| 18 | CORE-01 | Рабочие favorites/save state | QA-DS | TODO |
| 19 | CORE-02 | Server-side search, filters, tags, pagination | SEC-01 | TODO |
| 20 | CORE-03 | История, cooking progress и offline minimum | CORE-01 | TODO |
| 21 | CORE-04 | Auth completion и guest migration | UI-02, CORE-01 | TODO |
| 22 | CORE-05 | Preferences, allergens и personalization inputs | CORE-02, CORE-04 | TODO |
| 23 | CORE-06 | Pantry и shopping list | CORE-05, UI-07 | TODO |
| 24 | COL-01 | Content kinds поверх recipe infrastructure | CORE-02 | TODO |
| 25 | COL-02 | Collections schema/API и ordered content | COL-01 | TODO |
| 26 | COL-03 | Collection list/detail/content UI | COL-02, UI-05 | TODO |
| 27 | COM-01 | Products, entitlements и access service | COL-02, CORE-04 | TODO |
| 28 | COM-02 | Mobile store adapter и webhook verification | COM-01 | TODO |
| 29 | COM-03 | Purchase/restore/manage paywall integration | COM-02, UI-03 | TODO |
| 30 | COM-04 | One-off collection purchase | COM-03, COL-03 | TODO |
| 31 | VOICE-01 | Microphone, transcript и intent UI | CORE-05 | TODO |
| 32 | VOICE-02 | Structured intent API и tenant retrieval | VOICE-01, CORE-02 | TODO |
| 33 | VOICE-03 | Ranking, no-match и recommendation analytics | VOICE-02 | TODO |
| 34 | AI-01 | Opt-in AI recipe generation в стиле автора | VOICE-03 | TODO |
| 35 | AI-02 | Private generated drafts, safety и evaluation | AI-01 | TODO |
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
| 2026-07-15 | FND-02 | Добавлен единый Pydantic publish-gate BrandConfig: лимиты, кириллица, URL, `courseName`/`courseTag`, font enum, hero roles/focal и вычисляемые OKLCH tokens. Bootstrap fail-closed для невалидного published config. Добавлены pilot JSON fixture, optional SQL seed и monogram avatar 512×512. | `test_brand_config.py` + `test_bootstrap_contract.py`: 19 passed; FastAPI import и `compileall` — PASS; полный `pytest tests/ -v`: 113 passed, 4 failed, 3 errors. | Полный suite сохраняет известный внешний blocker локального Python 3.13: несовместимые Starlette `TestClient`/httpx ломают старые middleware/video-тесты. Seed migration не применялась: в workspace нет `psql`/изолированной БД; production/staging не затрагивались. Reference color tests фиксируют правило из раздела 3 (`OKLCH L × 0.88`) и contrast gates; Flutter parsing/theme и Studio UI остаются FND-03/FND-04/STUDIO-01. |
| 2026-07-15 | FND-01 | Добавлены unique `chefs.slug`, versioned `brand_configs` и отдельные `product_configs` с одним published config на tenant, RLS и published indexes. Реализован публичный `GET /api/v1/bootstrap/{tenant_slug}` с ETag/config version, 304 и fail-closed 404/409. | Новый contract suite: 7 passed; FastAPI bootstrap import и compileall — PASS; полный `pytest tests/ -v`: 103 passed, 4 failed, 3 errors. | Остаточный внешний blocker не изменился: локальный Python 3.13 имеет несовместимые Starlette `TestClient`/httpx (`Client.__init__(app=...)`), из-за чего падают старые middleware/video-тесты. CI закреплён на Python 3.11. Schema-level BrandConfig validation, derivation и pilot seed остаются FND-02. |
| 2026-07-15 | FND-00 | `frontend/` закреплён как canonical production app; Flutter pin вынесен в `frontend/.flutter-version`; CI/Render используют общий web-build contract с обязательным `TENANT_SLUG`; local development сохраняет pilot default. Добавлены config test и воспроизводимые local CI команды. | Frontend: format, analyze, 10 tests и web build — PASS; production build без `TENANT_SLUG` — ожидаемо FAIL с понятной ошибкой; FastAPI import — PASS. Backend: 96 passed, 4 failed, 3 errors. | Follow-up (вне scope): локальный Python 3.13 имеет несовместимую пару Starlette `TestClient`/httpx (`Client.__init__(app=...)`); CI закреплён на Python 3.11. Не исправлялось. Несвязанные существующие изменения `frontend/firebase.json`, `frontend/web/index.html`, `render.yaml` сохранены. |
| 2026-07-15 | PLAN | Создан детальный implementation plan и pilot BrandConfig | Проверка структуры/контрактов вручную | Код приложения не изменён |
