# White Povar — Design Conformance Spec

Verification checklist for the "Chef's Table" design (Handoff Spec v1.2 + Stage 1
Foundations, stages 10–13). Hand this to Claude Code alongside a changed screen and
ask it to check each applicable box.

**How to read this document.** It describes what the app *must* look like, not what a
particular screen currently does. Where the shipped app deliberately diverges from a
mockup, the divergence is recorded inline under **Accepted divergence** — those are
decisions, not bugs, and should not be "fixed".

**Scope rules that override everything else:**

- Never add a route, backend field or domain model. The design is drawn *from* this
  codebase; the code is the source of truth for routes, models and available actions.
- Never remove working functionality. This is a presentation-layer alignment.
- Every colour in a widget resolves from a token. No `Colors.*` (except
  `Colors.transparent`), no inline hex.
- The tenant accent comes from `BrandConfig`. `premiumGold` is a **product-tier**
  token and must never stand in for a brand accent.
- Every async screen keeps its loading / empty / error / data branches.

---

## 1 · Tokens

Semantic colours live in `SemanticColors`
([app_tokens.dart](frontend/lib/app/theme/tokens/app_tokens.dart)), a `ThemeExtension`
with an explicit set per `Brightness`, read in widgets as `context.semantic`.

| Token | dark | light | Use |
|---|---|---|---|
| `background` | `#16130F` | `#F5EEE1` | Scaffold |
| `surface` | `#221D16` | `#FDF8EE` | Cards, nav, fields |
| `surfaceStrong` | `#2E2820` | `#EBE0CC` | Borders, dividers, chips |
| `textPrimary` | `#F3E9DA` | `#1C1710` | Headings, body |
| `textSecondary` | `#B9AC98` | `#7C7159` | Metadata, captions |
| `success` | `#7A9E7E` | `#3E6B4A` | Confirmed, matched |
| `warning` | `#C9A24B` | `#B0832E` | Low confidence |
| `error` | `#D67A6B` | `#A8362A` | Errors, destructive |

Brand-owned roles come from `BrandThemeExtension` (`context.brandTheme`) and reach
widgets through the `ColorScheme`:

| Role | Source | Notes |
|---|---|---|
| `accent` | `brand.accent` | Light-theme CTA fill, active tab, chips, links |
| `accentOnDark` | `brand.derived.accentOnDark` | **All dark scenes.** `colorScheme.primary` resolves to this under a dark theme |
| `onAccent` | `brand.derived.onAccent` | Text/icon on an accent fill |
| `accentPressed` | `brand.derived.accentPressed` | Press state |
| `premiumGold #D9A441` | `AppColorsV2.premiumGold` | **System token.** Premium badges, gates, tier affordances only |
| `ink #16130F` / `onInk #F3E9DA` | `AppColorsV2` | Mode-independent: photo scrims and ink surfaces |

Scale tokens (all already exact — keep):

- **Spacing** `AppSpacing` — 4 · 8 · 12 · 16 · 24 · 32 · 40 · 56
- **Radius** `AppRadius` — sm 8 · md 12 · lg 16 · xl 24
- **Elevation** `AppElevation` — 0 · 1 · 2 · 4
- **Motion** `AppMotion` — 150 press · 250 transition · 400 hero

### Checks

- [ ] No `Colors.<name>` or `Color(0x…)` in the widget, other than `Colors.transparent`
      or an `AppColorsV2.ink.withOpacity(…)` photo scrim.
- [ ] Mode-dependent colours read `context.semantic`, not `AppColorsV2.<lightValue>`.
      `AppColorsV2` still exposes light-mode aliases for compatibility; using them in a
      widget silently breaks dark mode.
- [ ] A surface that is dark in *both* themes reads `SemanticColors.dark.*` explicitly,
      or sits under `ForcedDarkTheme`.
- [ ] `premiumGold` appears only on premium affordances.
- [ ] Spacing/radius values come from the scales, not raw numbers.

---

## 2 · Typography

Roles (Handoff §1), applied in [app_theme.dart](frontend/lib/app/theme/app_theme.dart):

| Role | Family | Size |
|---|---|---|
| `headlineLarge` / `headlineMedium` | brand display | 40 / 30, w700 |
| `titleLarge` | brand display | 22, w600 |
| `bodyLarge` / `bodyMedium` | Figtree | 16 / 14 |
| `bodySmall` | Figtree | 12, `textSecondary` |
| `labelSmall` | Figtree | 11, `textSecondary` |
| `labelMedium` (data role) | JetBrains Mono | 11, `textSecondary` |

Font presets (design 13c) — the display family varies by brand, the UI family never does:

| `brand.font` | Display | Body |
|---|---|---|
| `serif` | Source Serif 4 | Figtree |
| `grotesque` | Golos Text | Figtree |
| `humanist` | Lora | Figtree |
| *(absent / invalid)* | Source Serif 4 | Figtree |

Body styles and `ThemeData.fontFamilyFallback` carry `AppFonts.bodyFallback`
(`['Golos Text']`) so Cyrillic glyphs always resolve.

### Checks

- [ ] Display/serif text uses `context.brandTheme.displayFontFamily`, never a literal
      family name.
- [ ] Numeric metadata (times, servings, counts, ids) uses the mono data role —
      `context.semantic.dataLabel` / `dataBody`, or `MetaChip(isData: true)`.
- [ ] No `TextStyle` hardcodes a colour that a token already provides.

---

## 3 · BrandConfig

Schema (13a) — validated at publish time in Creator Studio; the runtime trusts the
config and only ever consumes derived values.

**Required (7):** `name` (≤20), `creatorName` (≤16), `avatar` (square ≥512),
`accent`, `voice.greeting` (≤24), `voice.loginTitle` (≤28), `voice.paywallTitle` (≤28).

**Optional:** `voice.courseName` (≤36), `courseTag`, `font`, `heroPhotos`, `logo`.
`voice` is exactly 4 strings. `courseName` and `courseTag` must be supplied together.

Derivation rules (13b), computed at publish, never at runtime:

- `accentPressed` = −12% lightness (OKLCH)
- `onAccent` = ink if it holds ≥ 4.5:1, else white
- `accentOnDark` = accent lightened until ≥ 4.5:1 on ink
- Light-theme CTA fill gate = 3.0:1 (WCAG 1.4.11); failing that, `lightCtaMode`
  becomes `inkFill` and the CTA renders ink with an accent icon

Fallbacks (13j): optional fields degrade quietly (serif preset, gradient instead of
hero photo, monogram instead of a broken avatar, no course card). No config on first
launch → neutral White Povar theme; on a later launch → last valid cached config.

Persona boundary (12c) — the brand may only touch: header, greeting, accent, brand
photography, and the course/paywall/login copy. Permanently neutral: navigation and
routes, the camera flow, loading/empty/error states, spacing/radius, premium gold, and
success/warning/error.

### Checks

- [ ] The screen reads brand strings from `brand.voice.*`, never hardcoded copy.
- [ ] Nothing renders a brand value the config does not guarantee, without a fallback.
- [ ] No new `BrandConfig` field was introduced.

---

## 4 · Components

All shared primitives live in
[design_system.dart](frontend/lib/core/widgets/design_system.dart),
[premium.dart](frontend/lib/core/widgets/premium.dart) and
[recipe_card.dart](frontend/lib/features/recipes/presentation/widgets/recipe_card.dart).
A screen must compose these rather than defining a private equivalent.

| Component | Spec |
|---|---|
| `AppButton` primary | height 48–52 · radius 12–14 · padding H 24 · label 16/700 · fill accent, text `onAccent` · press 250ms darken · loading = spinner + label · disabled 0.38 |
| `AppButton` secondary/text | height 48 · radius 12–14 · border 1.5 `surfaceStrong` or accent · transparent fill |
| `AppTextField` | height 48–52 · radius 12–14 · padding H 16 · border 1 → 1.5 accent on focus · error border + helper 12 · leading/trailing icon 20 |
| `RecipeCard.grid` | radius 16–18 · 4:3 image · title serif 17–19 · `MetaChip` row |
| `RecipeCard.list` | 84×84 thumbnail row |
| `RecipeCard.featured` | editorial hero, ink gradient, gold "Рекомендоване" badge |
| `RecipeCard.skeleton` | shimmer 1.4s |
| `MetaChip` | icon 16 + label 12–13 `textSecondary`; boxed variant height ≥34, radius 8 |
| `AppChip` (filter) | height 34–36 · radius 8–18 · active fill accent/`onAccent`, idle surface + border |
| `FlowStepper` | 27px circles · done = `success` + check · active = accent + number · pending = `surfaceStrong` |
| `IngredientCard` | radius 12 · checkbox 22 in a 44 hit area · name 15/600 + confidence 12 · **< 60% → warning border + "підтвердіть" hint** · edit/delete hit-area 44 |
| `StateView` | icon 34–36 + title 18/700 + text + optional CTA, centred |
| `NavigationBar` | height 68–72 · active tab accent icon + label |
| `PremiumBadge` | gold `workspace_premium`; label variant radius 12 |
| `PremiumGateCard` | `ContentCard` + badge + centred title/message + full-width CTA |
| Snackbar / Dialog | snackbar 48 dark surface · dialog radius 22–24 · destructive action `error` |

Screen horizontal padding is 20 at mobile 390.

### Checks

- [ ] No private re-implementation of anything in the table above.
- [ ] Every interactive target is ≥ 44×44.
- [ ] Skeletons use `AppSkeleton`, which shimmers over `surfaceStrong` and degrades to
      a static block under reduced motion.

---

## 5 · Screens

Thirteen spec routes. Bottom navigation has exactly 4 tabs; the camera flow, recipe
detail and cooking mode sit outside the shell.

| Route | Screen | Shell | Guard |
|---|---|---|---|
| `/login` | Login | outside | public |
| `/home` | Home | tab 1 | public |
| `/search` | Discover | tab 2 | public |
| `/saved` | Saved | tab 3 | guest → sign-in CTA |
| `/profile` | Profile | tab 4 | guest → invitation |
| `/recipes/:id` | Recipe detail | outside | premium gate |
| `/recipes/:id/cook` | Cooking mode | outside | exit confirm |
| `/camera` | Capture | outside | dark, CTA from Home |
| `/camera/review` | Review | outside | — |
| `/camera/results` | Results | outside | — |
| `/subscription` | Paywall | outside | — |
| `/settings` | Settings | outside | — |

### Home `/home`

Sections top→bottom: brand header (avatar + `brand.name` + trailing user avatar →
Profile) · `brand.voice.greeting` · scan banner (primary CTA → `/camera`) · secondary
text CTA → `/search` · featured hero · course card · "Свіже від автора" feed.

Course card states (13g): **hidden** when `voice.courseName`/`courseTag` are absent ·
**locked** for guests and free users, rendered as `PremiumGateCard` → `/subscription` ·
**active** for premium.

> **Accepted divergence.** The active course card deep-links into the existing
> collection (`/collections/:id`, falling back to `/collections`) rather than
> `/search?tag=…`. The collection is a real, richer destination already in the app and
> needs no new route.

States: shimmer skeleton · empty · error + retry · pull-to-refresh.

### Discover `/search`

Search field with clear action; query fires at ≥2 chars or submit. Start state shows
recent searches and suggestions.

Structured filters expose **only** `cuisine`, `category`, `difficulty`, `maxTime`,
`isFeatured` — the arguments `RecipeRepository.getRecipes` already accepts. Cuisine and
category options are derived from the loaded catalogue, so no unpublished facet is ever
offered. Filters are progressive disclosure: a bottom sheet on mobile ("Усі фільтри"),
the rail on desktop. Active facets appear as removable chips above the results; reset
returns the full catalogue.

Retrieval: facets with an empty query browse via `getRecipes`; with a query, the text
search runs server-side and the facets narrow the result.

States: start hint · loading grid skeleton · no results + reset · error + retry.
Responsive grid: 1 column mobile, 3 columns ≥600.

### Recipe detail `/recipes/:id`

Immersive hero (image + ink gradient + safe back) · title · description ·
`MetaChip` metadata (total time / servings / difficulty) · ingredients with
amount/unit/notes · ordered instructions · video block **only** when `videoUrl` or
`videoFilePath` exists · sticky "Почати готувати" · save and AI secondary actions with
guest/premium gating. Locked → shared `PremiumGateCard`.

States: header + body skeleton · premium/guest gate · error. Invalid id is handled by
the router.

### Cooking mode `/recipes/:id/cook`

One step per screen · visible progress · Previous/Next → "Завершити" · large text ·
wakelock · exit confirmation · resume from stored progress. Renders on ink in both
themes via `ForcedDarkTheme`; step kicker and progress use the **brand accent**, and
only the premium gate uses gold.

### Camera flow `/camera`, `/camera/review`, `/camera/results`

Dark in both themes via `ForcedDarkTheme` — which also swaps `SemanticColors`, so
descendants reading `context.semantic` get the dark column.

`FlowStepper`: Зйомка → Перевірка → Результати.

Required states: preparing · uploading/analyzing · permission denied · detection error ·
no ingredients (→ manual entry) · no matches · API error. Review shows detected
ingredients with confirm/edit/delete and a confirmed count. Results show the used
ingredients, `RecipeCard`s, back-to-review and start-over.

### Saved `/saved`

Guest CTA → sign in · authenticated empty state → "знайти рецепт" · populated grid
using the same shared `RecipeCard` as Home and Discover · error state.

### Profile `/profile` and Settings `/settings`

Guest sees an invitation. Authenticated account summary shows **email as the primary
identifier** with a truncated user id beneath it in the mono data role. The avatar is
initials with **no accent ring** (13k: the accent ring belongs to the blogger avatar,
never the user). Explicit Subscription and Settings rows; Sign out is a separate,
confirmable action.

> **Accepted divergence.** The brief forbids inventing a display name, so the previous
> `full_name`/`name` metadata fallback was dropped in favour of email + id. Settings
> also keeps a real System/Light/Dark theme control, which exceeds the design's
> "coming soon" placeholder.

### Login `/login`

Dark in both themes. Single card: brand avatar 72 · `brand.voice.loginTitle` ·
email · password with show/hide · inline validation · Google and Apple (Apple hidden on
web) · guest continue · `brand.heroPhotos` background with a gradient fallback (13i/13d).
Max content width ~440. The extra reset-password mode is kept.

### Paywall `/subscription`

Dark in both themes. **The real store checkout is kept** — do not replace it with a
mock. Brand hero portrait + `creatorName` caption · `brand.voice.paywallTitle` ·
`check_circle` benefits · annual/monthly plan cards with trial and discount badge ·
active-status panel with a valid-until date · every `PaywallPhase`
(loading / catalogue / error / success / active).

---

## 6 · Forced-dark scenes

Camera flow, Login, Cooking mode and Paywall render dark regardless of `ThemeMode`.
They must obtain this through `ForcedDarkTheme`
([app_theme.dart](frontend/lib/app/theme/app_theme.dart)), which rebuilds the brand's
dark `ThemeData` — including the `SemanticColors` extension.

- [ ] The scene does not construct a dark theme by hand. A bare
      `colorScheme.copyWith(brightness: dark)` leaves `SemanticColors` on the light set
      and produces light cards inside a dark screen.
- [ ] Accent inside these scenes resolves to `accentOnDark`, i.e. via
      `Theme.of(context).colorScheme.primary`.

---

## 7 · Responsive

| Breakpoint | Rules |
|---|---|
| **390 mobile** | Baseline. Screen padding 20, single column. |
| **≥600 tablet** | `NavigationBar` → `NavigationRail` **with the blogger avatar at the top of the rail**. Content max-width 480, centred. Discover grid 3 columns. Home hero max-height 360. Paywall becomes a centred 560 dialog over a 45% ink scrim, same route. |
| **≥1024 desktop** | Two-column master–detail where specified (list 420 / detail). Login splits: hero photo left, form max 440. |

### Checks

- [ ] Layout switches on `MediaQuery.sizeOf(context).width`, not on a nested
      constraint — the navigation shell consumes rail width before the page is laid out.
- [ ] No desktop-only information architecture; the same routes and scenarios at every
      width.
- [ ] No horizontal overflow at 390 / 768 / 1280.

---

## 8 · Accessibility

- [ ] Touch targets ≥ 44×44.
- [ ] Contrast meets WCAG AA; accent fills in the light theme meet the 3.0:1
      non-text gate or fall back to `inkFill`.
- [ ] Layout survives 200% text scale.
- [ ] Animations respect `MediaQuery.disableAnimationsOf(context)`.
- [ ] Interactive and stateful elements carry `Semantics` labels; live regions
      (auth banners, voice status) announce.

---

## 9 · How to verify

```bash
# The CI gate — format, analyze, tests. Prod deploy is gated on this.
scripts/ci-local.sh frontend

# Goldens at 390 / 768 / 1280. Inspect the diffs; never blind-accept.
cd frontend && flutter test --update-goldens --tags golden

# Walk the app in both themes and at all three widths.
cd frontend && flutter run
```

Golden coverage lives in `frontend/test/goldens/` — home, search, recipe, cooking,
camera, paywall, profile, settings, saved and login, each at the three reference widths.

**Two gotchas when regenerating:**

1. The login goldens come from a test that early-returns unless the OAuth provider is
   enabled. Regenerate them with
   `flutter test --update-goldens --dart-define=GOOGLE_OAUTH_ENABLED=true test/login_page_test.dart`,
   otherwise they silently stay stale. (One non-golden test in that file asserts the
   provider is hidden and will fail under the flag; that is expected.)
2. Goldens render text as filled boxes because no real font is loaded in the test
   environment. Verify **colour, layout and state** from goldens — not glyphs. To check
   an exact colour, sample the pixel rather than eyeballing the thumbnail.

Manual brand fidelity: temporarily load a gold `BrandConfig` to confirm the system
reproduces the Chef's Table mockups, then revert. The shipping tenant is
`ohorodnik-oleksandr` (blue-grey `#5D7183`, `accentOnDark #6B8092`) and gold must not
become the default brand.
