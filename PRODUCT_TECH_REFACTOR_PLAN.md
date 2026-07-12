# White Povar: продуктовая и техническая перезагрузка

Дата ревизии: 2026-07-11

## Продуктовое решение

White Povar стоит развивать как B2B2C-платформу с двумя отдельными поверхностями:

- consumer app для домашнего кулинара;
- chef studio для контента, брендинга, аналитики и монетизации.

Главный consumer-сценарий:

> Покажи, какие продукты у тебя есть → получи подходящие блюда → приготовь пошагово.

Каталог, AI, фото-поиск и подписка должны поддерживать этот сценарий, а не конкурировать с ним за внимание.

North-star metric: завершённые cooking sessions в неделю.

## Целевая информационная архитектура

- Home: ценность продукта, вход в pantry flow, рекомендации, продолжение готовки.
- Discover: текстовый поиск, ручной ввод продуктов, фото, фильтры и история.
- Saved: личная книга рецептов и коллекции.
- Profile: предпочтения, ограничения, язык, единицы и тариф.
- Recipe: обзор, ингредиенты, масштабирование порций и CTA «Start cooking».
- Cooking mode: один шаг за раз, таймеры и отметка завершения.

Подписка не является основной вкладкой. Paywall появляется контекстно после демонстрации пользы.

## Архитектурное решение

Канонический клиент — `frontend/`. Корневой Flutter shell следует вывести из эксплуатации после usage-аудита.

Целевые границы:

```text
Flutter UI
  → feature controller/provider
  → repository interface
  → единый Dio ApiClient
  → FastAPI route
  → application service/use case
  → repository
  → Supabase/Postgres
```

Нужно оставить по одной реализации Recipe DTO/domain model, repository, HTTP client, filter bar и recipe card.

## Security release blockers

До production-релиза обязательны:

1. Закрытые admin/upload и subscription mutation endpoints.
2. JWT verification без service-role fallback, логирования токенов и секретов.
3. User sync, жёстко привязанный к JWT `sub`.
4. Ownership checks для recipe/video mutations.
5. RLS migrations и отказ от service-role для обычных пользовательских запросов.
6. Trusted billing webhook вместо клиентского grant/revoke premium.
7. Rate limits для AI, фото и upload.
8. Blocking CI: тесты и линтеры не могут завершаться через `|| echo`.

В первом срезе уже закрыты публичная production-раздача admin uploader, production premium mutations, IDOR в user sync, утечки частей токена/секрета в логах и `.uid`-ошибки видео.

## Реализовано в Sprint 0 — 2026-07-11

- JWT verification поддерживает Supabase JWKS/ротацию asymmetric keys; legacy HS256 проверяется через Auth server.
- Зафиксированы issuer, audience, authenticated role, expiration и fail-closed алгоритмы.
- Введена явная membership-модель `users.chef_id → chefs.id`.
- Recipe mutations разрешены только участникам соответствующего chef; отсутствие membership даёт 403.
- Реализованы canonical recipe CRUD mapping, ownership-aware PUT/DELETE и persisted favorites.
- Добавлена forward-only RLS migration для users, recipes, children, videos, favorites, subscriptions и internal tables.
- Public read/search явно исключают private и premium content даже при backend service-role запросах.
- Backend test harness и dependency pins стабилизированы; CI и deploy больше не скрывают падения.
- Чистый прогон: 103 backend tests, 9 Flutter tests, Flutter analyze и обязательный flake8.

Перед production deploy необходимо применить
`backend/migrations/2026_07_11_enable_row_level_security.sql` к целевой Supabase базе и назначить `users.chef_id` для chef-аккаунтов. До этого новые ownership/favorites таблицы в production отсутствуют.

## Roadmap

### Sprint 0 — безопасность и контракт

- завершить ownership/RLS аудит;
- зафиксировать OpenAPI-контракт;
- исправить recipe CRUD и таблицы ingredients/nutrition;
- сделать backend checks блокирующими в CI;
- синхронизировать dependency pins и test harness.

### Sprint 1 — consumer core flow

- объединить photo/manual ingredient input;
- ранжировать результат по `есть X из Y`, времени и сложности;
- показывать недостающие продукты и замены;
- добавить save/recently cooked;
- развить cooking mode: checklist, timers, completion.

### Sprint 2 — frontend consolidation

- перевести features на единый ApiClient/repository;
- generated DTO + явный domain mapping;
- удалить дубли моделей, карточек и filter bars;
- добавить responsive shell с NavigationRail для expanded layouts;
- унифицировать loading/error/empty и user-safe errors.

### Sprint 3 — backend decomposition

- разделить router → use case → repository;
- убрать sync Supabase I/O с event loop;
- использовать транзакции/RPC для составных записей;
- вынести ingestion watcher в отдельный worker;
- ввести Alembic baseline и schema drift check.

### Sprint 4 — рост продукта

- chef branding config и отдельная studio;
- локализация, units и dietary preferences;
- контекстная монетизация после value moment;
- продуктовая аналитика по capture → result → cook → complete.

## Definition of done для каждого вертикального среза

- mobile 320/375 и tablet/web 768/1024/1440;
- text scale 100/150/200%;
- loading/error/empty/data;
- keyboard/focus/semantics;
- unit/widget/contract tests;
- отсутствие raw errors и чувствительных данных в логах;
- ownership и authorization tests для каждой mutation.
