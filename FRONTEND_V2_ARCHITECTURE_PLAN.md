# Frontend V2: UI/UX Redesign Architecture & Implementation Plan

## 1) Current State Audit (what blocks good UX)

### Product-level UX issues
- Primary navigation is fragmented: search, camera, profile/subscription are scattered across app bar actions, popup menus, and floating actions.
- Information hierarchy is weak: list/detail/search/camera all feel like separate mini-apps rather than one coherent flow.
- Empty/loading/error states are inconsistent in structure, tone, and actions.
- Mobile-first behavior exists, but large-screen UX is not intentionally designed (cards/grids/layout density remain basic).
- Visual identity is generic Material defaults and does not create a distinctive brand feel.

### Technical UX debt causing slow iteration
- Duplicate architecture intent: repository layer exists, but services still bypass it in places.
- Networking is mixed (`http` + `dio`) with inconsistent error models and retry behavior.
- Auth/session rules are spread across router guards, providers, and services.
- Some important flows are hard-coded or under-specified (profile path, callback handling, premium gating).
- Feature modules are present, but screen composition patterns are inconsistent.

### Design-system gaps
- No formal token system (spacing, radius, elevation, motion, semantic colors).
- Typography is mostly default and not role-driven (display/title/body/caption semantics are weak).
- Component variants/states are not standardized (disabled/loading/error/skeleton).

## 2) V2 Product Direction

### Core UX goals
- Fast path to value in under 2 taps from home.
- Predictable navigation: user always knows where they are and how to return.
- Consistent feedback for loading/error/success across every feature.
- Distinct visual style with high readability and accessibility.
- Easy extensibility for premium and AI features without cluttering base flows.

### Primary user journeys (MVP)
1. Find and cook a recipe quickly.
2. Search by text and filters.
3. Search by photo (capture -> confirm ingredients -> results).
4. Open recipe detail with clear action path (save/share/start cooking).
5. Manage account and subscription without hidden menus.

## 3) Target Frontend Architecture (from clean slate)

## Directory model

```text
frontend/lib/
  app/
    app.dart
    bootstrap.dart
    router/
      app_router.dart
      route_guards.dart
    theme/
      tokens/
      app_theme.dart
      component_themes.dart
  core/
    api/
      api_client.dart
      api_error.dart
      auth_interceptor.dart
    config/
    logging/
    utils/
    widgets/
      app_scaffold.dart
      state_views.dart
  entities/
    recipe/
      recipe.dart
      recipe_repository.dart
    user/
      user.dart
    subscription/
      subscription.dart
  features/
    auth/
      data/
      domain/
      presentation/
    home/
      presentation/
    recipes/
      data/
      domain/
      presentation/
    search/
      data/
      domain/
      presentation/
    camera_search/
      data/
      domain/
      presentation/
    subscription/
      data/
      domain/
      presentation/
    profile/
      data/
      domain/
      presentation/
  widgets/
    recipe/
    search/
    navigation/
main.dart
```

## Layer responsibilities
- `app`: composition root (bootstrapping, router, global theming, app-level providers).
- `core`: shared technical infrastructure (networking, error mapping, base widgets, config).
- `entities`: pure domain contracts and repository interfaces.
- `features`: vertical slices with `data/domain/presentation` boundaries.
- `widgets`: reusable, feature-agnostic UI blocks.

## State management model
- Keep Riverpod.
- Use `Notifier/AsyncNotifier` consistently.
- Rule: presentation never talks directly to raw network client.
- Rule: all async state goes through a unified `UiState<T>` (loading/data/empty/error).

## API/data model
- Standardize on one HTTP stack (`dio` recommended) with:
  - auth interceptor
  - request/response logging in debug only
  - timeout/retry policy
  - typed error mapping into `ApiError`
- Keep Supabase for auth/session source, backend API as business source.
- Every feature repository returns domain models and domain-level failures.

## Navigation model
- `ShellRoute` with bottom navigation tabs:
  - Home
  - Search
  - Camera
  - Saved (or Collections)
  - Profile
- Deep links for recipe detail and auth callback.
- Route guards:
  - guest -> auth routes
  - authenticated -> app shell routes
  - premium gates by feature capability checks.

## 4) New Design System (V2)

### Foundations
- 8pt spacing scale.
- Radius scale: 8 / 12 / 16 / 24.
- Elevation scale with minimal levels (0/1/2/3).
- Semantic color tokens: `bg`, `surface`, `textPrimary`, `textSecondary`, `accent`, `success`, `warning`, `error`.
- One expressive font family + fallback stack; strict type roles:
  - Display
  - H1/H2/H3
  - Body L/M/S
  - Caption

### Component primitives to build first
- `AppScaffold` (header + content + optional bottom bar slot).
- `PrimaryButton`, `SecondaryButton`, `TonalButton`, loading variants.
- `AppTextField` with validation + prefix/suffix support.
- `RecipeCardV2` with consistent media ratio and metadata slots.
- `StateView` set: loading skeleton, empty state, error with retry.
- `FilterChipGroup`, `BottomSheetSelector`, `PremiumGateCard`.

### Accessibility baseline
- Minimum tappable area: 44x44.
- Text contrast AA.
- Dynamic text scaling support.
- Semantic labels for camera/search critical actions.

## 5) Migration Strategy (no risky big-bang)

### What we keep
- Backend API contracts.
- Existing feature business intent (auth, recipes, search, camera search, subscription).
- Existing model schemas where already stable.

### What we replace completely
- Current visual layer (`presentation/pages/widgets`) for all user-facing screens.
- Current ad-hoc routing map and top-level nav ergonomics.
- Mixed async/error rendering patterns.

### What we refactor in place first
- Network stack and error contracts.
- Repository boundaries (remove service bypassing repository contracts).
- Provider naming and lifecycle consistency.

## 6) Sprint Plan

## Sprint 0 (2-3 days): Foundation
- Freeze current UI changes.
- Add V2 folder structure (`app/core/entities/features/widgets`).
- Introduce `ApiClient`, `ApiError`, auth interceptor.
- Introduce global tokens/theme primitives.
- Add shared `StateView` components.

DoD:
- App boots with new shell and placeholder screens.
- Networking layer compiles and is used by at least one feature.

## Sprint 1 (4-5 days): Navigation + Home + Auth
- Implement shell navigation with bottom tabs.
- Rebuild login flow and auth callback UX.
- Rebuild Home/Recipes list screen in V2 style.
- Wire unified loading/empty/error states.

DoD:
- User can authenticate and reach home.
- Recipe list fully functional on V2 stack.

## Sprint 2 (4-5 days): Search + Recipe Detail
- Rebuild text search screen with suggestions + filters.
- Rebuild recipe detail screen with improved hierarchy/actions.
- Add deep-link handling to detail.

DoD:
- Search and detail fully functional on V2 stack.
- No usage of legacy recipe pages for these flows.

## Sprint 3 (4-5 days): Camera Search + Subscription + Profile
- Rebuild capture/review/results flow with clearer step UI.
- Rebuild subscription/profile surfaces; remove hidden menu patterns.
- Add premium gating UI consistency.

DoD:
- End-to-end camera search works in V2.
- Subscription/profile reachable from dedicated navigation entry.

## Sprint 4 (2-3 days): Hardening + Cleanup
- Remove legacy V1 presentation code.
- Add widget/golden tests for design-system components.
- Add smoke integration tests for critical journeys.
- Performance and accessibility pass.

DoD:
- Legacy UI code removed or archived.
- Critical journeys pass tests and manual QA checklist.

## 7) Deletion and Cleanup Plan

After each migrated feature is production-ready:
- Delete old page/widget counterparts from `features/*/presentation` (V1 files only).
- Delete obsolete providers/services not referenced by V2 dependency graph.
- Keep adapters temporarily only when needed for staged rollout.

Final cleanup gate:
- `rg` finds no imports to V1 presentation modules.
- Router has no V1 routes.
- App passes lint + smoke tests.

## 8) Engineering Rules for V2
- One source of truth per feature state.
- No direct network calls in widgets/providers outside repositories.
- All user-visible errors are mapped to human-readable messages.
- Every screen has explicit loading/empty/error/success states.
- No hidden critical actions in overflow menus.

## 9) First Execution Backlog (immediate next tasks)
1. Create `app/bootstrap.dart` + centralized dependency registration.
2. Build `core/api/api_client.dart` + `api_error.dart` + auth interceptor.
3. Build `app/theme/tokens/*` and base component theme files.
4. Introduce shell router + stub V2 screens.
5. Migrate recipes list flow first (highest traffic path).

