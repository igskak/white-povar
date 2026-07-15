# Claude Design brief — White Povar

Ниже находится master prompt для генерации UI/UX, совместимого с текущей архитектурой приложения. Перед запуском приложите к задаче файлы из раздела «Контекст для Claude».

## Master prompt

```text
Ты — senior product designer и Flutter UI architect. Спроектируй production-ready UI/UX для существующего приложения White Povar. Это не концепт нового продукта и не greenfield-проект: дизайн должен точно укладываться в приведённую ниже архитектуру, маршруты, состояния и модели. Не придумывай новый backend, новые сущности или навигацию, для которых потребуется переписывать продуктовую логику.

КОНТЕКСТ ПРОДУКТА

White Povar — white-label приложение с рецептами для mobile и web. Пользователь может:
- просматривать каталог рецептов;
- искать по названию, ингредиентам и кухне;
- сфотографировать продукты, проверить распознанные ингредиенты и получить подходящие рецепты;
- открыть рецепт и перейти в пошаговый режим приготовления;
- сохранять рецепты;
- использовать AI-возможности и premium-функции при наличии доступа;
- управлять профилем, настройками и подпиской.

ПЛАТФОРМА И ТЕХНИЧЕСКИЕ ОГРАНИЧЕНИЯ

- Frontend: Flutter, один код для iOS, Android и web.
- UI foundation: Material 3 и существующий ThemeData.
- State management: Riverpod. Все асинхронные экраны имеют loading / empty / error / data состояния.
- Navigation: go_router. Сохрани существующие routes и переходы.
- Изображения рецептов приходят по URL; локальной библиотеки контента сейчас нет.
- Не проектируй UI, зависящий от новых API-полей.
- Не меняй backend contracts, providers, repositories, auth flow или доменные модели.
- Не добавляй отдельную desktop-only информационную архитектуру. Разрешён адаптивный layout тех же экранов.
- Все компоненты должны быть реалистично реализуемы стандартными Flutter widgets и текущими зависимостями. Не требуй сложных blur/3D/WebGL-эффектов.
- Минимальная touch-target зона — 44×44 px, контраст — WCAG AA, поддержка Dynamic Type/text scaling.

СУЩЕСТВУЮЩАЯ НАВИГАЦИЯ — СОХРАНИТЬ

Публичные маршруты:
- /login — sign in / sign up;
- /auth/callback — завершение авторизации.

App shell с нижней навигацией из 4 пунктов:
1. /home — Home;
2. /search — Discover;
3. /saved — Saved;
4. /profile — Profile.

Вложенные маршруты:
- /recipes/:id — детали рецепта;
- /recipes/:id/cook — пошаговый cooking mode;
- /camera — съёмка или выбор фотографии;
- /camera/review — проверка и редактирование ингредиентов;
- /camera/results — найденные по фото рецепты;
- /subscription — статус и предложение Premium;
- /settings — настройки.

Нижняя навигация скрывается во всём camera flow и на экранах recipe detail / cooking mode. Камера запускается CTA с Home, а не является пятой вкладкой. Не меняй это решение.

ГОСТЕВОЙ И АВТОРИЗОВАННЫЙ РЕЖИМЫ

- Каталог, поиск и просмотр рецепта доступны гостю.
- В Profile гость видит приглашение войти.
- В Saved гость видит CTA на вход; авторизованный пользователь — свою коллекцию или empty state.
- Login поддерживает email/password, Google и Apple на non-web платформах; переключение sign in / sign up происходит внутри того же экрана.
- Premium-функции должны использовать понятный gate/upgrade prompt, но базовый контент не должен выглядеть заблокированным.

ДОСТУПНЫЕ ДАННЫЕ РЕЦЕПТА — ИСПОЛЬЗУЙ ТОЛЬКО ИХ

- title, description;
- cuisine, category, tags;
- difficulty (числовой уровень);
- prepTimeMinutes, cookTimeMinutes, totalTimeMinutes;
- servings;
- ingredients: name, amount, unit, notes, order;
- instructions: список строк;
- images: список URL;
- optional videoUrl / videoFilePath;
- isFeatured, isPremium.

Не показывай рейтинг, отзывы, калории, автора с фото, цену или другие данные, которых нет в модели. Nutrition можно показывать только как отдельное premium AI-действие/состояние результата, а не как уже существующее поле рецепта.

ВИЗУАЛЬНОЕ НАПРАВЛЕНИЕ

Создай тёплый современный culinary/editorial интерфейс: премиальный, спокойный, аппетитный, но не ресторанно-пафосный. Он должен ощущаться как практичный ежедневный кухонный помощник.

Используй существующую семантическую палитру как основу:
- background #F6F1E8;
- surface #FFFBF4;
- strong surface #EDE4D6;
- primary text #242019;
- secondary text #6F675C;
- accent/CTA #A94428, pressed #923B22;
- dark ink #1F3027, text on ink #F9F2E7;
- success #2D8F5B, warning #C2842E, error #B00020.

Сохрани 8-point rhythm и текущие шкалы:
- spacing: 4, 8, 12, 16, 24, 32, 40, 56;
- radius: 8, 12, 16, 24;
- elevation: минимальная, уровни 0, 1, 2, 4;
- motion: 150 / 250 / 400 ms.

Не используй generic purple Material look, не делай чрезмерно округлённый «AI SaaS» дизайн, glassmorphism, неон, тяжёлые тени или бесконечные карточки внутри карточек. Фото еды — главный визуальный акцент. Все цвета в спецификации компонентов привязывай к semantic tokens, чтобы приложение можно было white-label кастомизировать.

ЭКРАНЫ И ОБЯЗАТЕЛЬНЫЕ СОСТОЯНИЯ

1. Home
- компактный brand header и вход в Profile;
- hero «что приготовить из имеющихся продуктов»;
- primary CTA «Scan ingredients» → /camera;
- secondary CTA «Type them in» → /search;
- секция рецептов с переходом в Discover;
- recipe cards: image, title, total time, category или cuisine, Featured/Premium badge только по данным модели;
- loading skeleton, empty, error + retry;
- pull-to-refresh.

2. Discover/Search
- поле поиска с clear action;
- запрос запускается после 2 символов или submit;
- стартовое состояние с подсказкой поиска по рецепту, ингредиенту или кухне;
- loading, no results, error + retry, results;
- responsive recipe grid;
- фильтры могут использовать только существующие cuisine, category, difficulty, time и isFeatured. Покажи их как progressive disclosure, чтобы не перегрузить mobile.

3. Recipe detail
- immersive image header с безопасной back action;
- title, description, badges и metadata: total time, servings, difficulty;
- ingredients с amount/unit/notes;
- ordered instructions;
- video block только если videoUrl/videoFilePath существует;
- primary sticky action «Start cooking» → /recipes/:id/cook;
- save и AI actions как secondary actions с корректным guest/premium gating;
- состояния loading, invalid/not found, error.

4. Cooking mode
- один шаг инструкции на экране;
- видимый progress: текущий шаг / всего;
- Previous / Next, на последнем шаге Finish cooking;
- крупный текст, экран не должен выключаться концептуально, минимум отвлечений;
- понятный выход назад без случайной потери прогресса.

5. Camera search — единый flow из трёх шагов
- Capture: permission state, live/placeholder camera area, Take photo, Choose from gallery, captured preview, Retake, Analyze ingredients;
- Review: stepper Capture → Review → Results, список detected ingredients, confirmed/unconfirmed state, edit/delete/add, count confirmed, Find recipes;
- Results: summary использованных ингредиентов, responsive recipe cards, Back to review, Start over;
- предусмотри preparing, uploading/analyzing, permission denied, detection error, no ingredients, no matches и API error состояния.

6. Saved
- guest state с CTA Sign in;
- authenticated empty state с CTA Find a recipe;
- populated state использует тот же RecipeCard, что Home/Search, без отдельной визуальной модели.

7. Profile and Settings
- guest profile invitation;
- authenticated account summary по доступным данным: email и user id; не придумывай avatar/name;
- явные пункты Subscription и Settings;
- Sign out — отдельное безопасное действие;
- Settings пока может быть аккуратным coming-soon state без несуществующих toggles.

8. Subscription/Premium
- current tier/status и optional valid-until date;
- benefits: AI assistant, premium recipe catalog, advanced discovery, nutrition analysis;
- Free и Premium состояния;
- upgrade/manage CTA;
- premium gate card и компактный Premium badge как переиспользуемые компоненты;
- не проектируй payment checkout: в текущей архитектуре его нет.

9. Authentication
- единая карточка/панель для sign in и sign up;
- email, password, show/hide password, inline validation;
- Google и Apple (Apple скрыт на web);
- loading и snackbar/inline error;
- max content width около 440 px на широком экране.

RESPONSIVE ПРАВИЛА

Спроектируй минимум три контрольные ширины:
- mobile: 390 px;
- tablet: 768 px;
- desktop web: 1440 px.

На mobile — одна колонка там, где это улучшает читаемость. На tablet/web используй ограничение ширины контента и 2–3 колонки карточек, не растягивай текст на всю ширину. NavigationBar остаётся частью текущего shell; на desktop можно визуально адаптировать её размещение только если это не требует изменения route structure или пользовательских сценариев. Для результата по умолчанию покажи безопасный вариант с той же нижней NavigationBar.

КОМПОНЕНТЫ, КОТОРЫЕ НУЖНО ОПИСАТЬ

- AppScaffold / page header;
- NavigationBar и все selected/unselected states;
- Primary, secondary, tonal, destructive buttons + loading/disabled states;
- AppTextField + focus/error/disabled states;
- RecipeCard: default, Featured, Premium, image fallback, loading skeleton;
- metadata item/chip;
- filter chip + active filters;
- StateView: loading, empty, error, success where relevant;
- Camera stepper;
- DetectedIngredient row and edit dialog;
- PremiumBadge, PremiumGateCard, upgrade dialog;
- toast/snackbar/dialog/bottom sheet patterns.

ТРЕБУЕМЫЙ РЕЗУЛЬТАТ

Сначала коротко покажи, как ты понял существующую архитектуру и перечисли ограничения, которые сохраняешь. Затем выдай:

1. Sitemap строго на основе перечисленных routes.
2. User-flow схемы для:
   - browse → recipe detail → cooking mode;
   - home → camera → review → results → recipe detail;
   - guest → save/premium action → auth или upgrade gate.
3. Design foundations: semantic colors, typography roles, spacing, radius, elevation, iconography, motion.
4. Component inventory со всеми интерактивными состояниями и точными размерами/paddings.
5. High-fidelity макеты всех перечисленных экранов на mobile 390 px.
6. Responsive варианты ключевых экранов Home, Search и Recipe detail для 768 и 1440 px.
7. Отдельные макеты loading / empty / error / guest / premium-locked состояний, а не только happy path.
8. Developer handoff для Flutter: hierarchy компонентов, constraints, breakpoint rules и соответствие каждого экрана существующим route/widget именам.

Для каждого экрана укажи:
- route;
- назначение;
- входы/выходы;
- состав секций сверху вниз;
- primary и secondary actions;
- состояния данных;
- поведение на mobile/tablet/web;
- какие существующие model fields используются.

ПЕРЕД ФИНАЛОМ ПРОВЕРЬ СЕБЯ

- Ни одного нового route или обязательного backend field.
- Ровно 4 пункта в основной нижней навигации.
- Camera — отдельный 3-step flow.
- Recipe detail и cooking mode без нижней навигации.
- Guest может просматривать каталог.
- Все async states спроектированы.
- Компоненты соответствуют Material 3 и реализуемы во Flutter.
- Визуальные решения основаны на semantic tokens и пригодны для white-label темизации.
- Никаких функций оплаты, рейтингов, отзывов или социальных механик, которых нет в текущем продукте.

Если приложенный код расходится с этим описанием, сначала явно укажи расхождение. Считай код источником истины для routes, моделей и доступных действий; не исправляй архитектуру молча.
```

## Контекст для Claude

Передайте эти файлы вместе с prompt:

1. `frontend/lib/app/router/app_router.dart`
2. `frontend/lib/app/router/route_guards.dart`
3. `frontend/lib/app/theme/tokens/app_tokens.dart`
4. `frontend/lib/app/theme/app_theme.dart`
5. `frontend/lib/app/theme/component_themes.dart`
6. `frontend/lib/features/recipes/models/recipe.dart`
7. `frontend/lib/features/home/presentation/pages/home_page.dart`
8. `frontend/lib/features/search/presentation/pages/search_page.dart`
9. `frontend/lib/features/recipes/presentation/pages/recipe_detail_page.dart`
10. `frontend/lib/features/recipes/presentation/pages/cooking_mode_page.dart`
11. `frontend/lib/features/camera/presentation/`
12. `frontend/lib/features/auth/presentation/pages/login_page.dart`
13. `frontend/lib/features/saved/presentation/pages/saved_page.dart`
14. `frontend/lib/features/profile/presentation/pages/`
15. `frontend/lib/features/subscription/`
16. `frontend/lib/core/widgets/state_views.dart`
17. `FRONTEND_V2_ARCHITECTURE_PLAN.md`

Если Claude принимает ограниченный объём контекста, минимальный набор: router, tokens/theme, Recipe model, Home, Search, Recipe detail и папка camera presentation.

## Рекомендуемая последовательность

Не просите генерировать весь продукт одним визуальным полотном. После master prompt выполняйте по этапам:

1. Foundations + sitemap + component library.
2. Home + Search + RecipeCard со всеми состояниями.
3. Recipe detail + Cooking mode.
4. Полный Camera flow.
5. Saved + Profile + Auth + Subscription.
6. Responsive pass и финальный consistency audit.

На каждом этапе добавляйте: «Используй утверждённые ранее foundations и компоненты; не меняй routes, модели и interaction contracts».
