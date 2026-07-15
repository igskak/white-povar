# QA-DS design matrix

This is the design-system release gate for UI-01 through UI-07. It records
which stable Flutter checks own each handoff requirement, so a new product
package cannot silently remove a design state already covered by the UI work.

## Matrix

| Dimension | Automated coverage | Expected result |
| --- | --- | --- |
| Brands | `test/qa_design_matrix_test.dart`: pilot plus three reference configs | All use the published token contract; no generic White Povar fallback. |
| Themes | `qa_design_matrix_test.dart`, `brand_theme_test.dart`, `design_system_primitives_test.dart` | Light and dark surfaces retain their brand roles and contrast. |
| 390 / 768 / 1280 | `adaptive_navigation_shell_test.dart`, screen tests, and `qa_design_matrix_test.dart` | Mobile, tablet and desktop compositions build without overflow or exceptions. |
| Home / detail / search / camera | `smoke_user_journeys_test.dart`, `recipe_detail_page_test.dart`, `search_page_test.dart`, `ui_07_camera_test.dart` | Loading, empty, error/offline or locked presentation is owned by the relevant screen test. |
| Login / paywall | `login_page_test.dart`, `subscription_screen_test.dart` | Auth and paywall visual states, including 200% scale, remain covered. |
| Semantics / keyboard | `design_system_primitives_test.dart`, `qa_design_matrix_test.dart` | Interactive controls have labels, 44px targets, and text fields accept a keyboard submit action. |
| 200% scale / reduced motion | `login_page_test.dart`, `subscription_screen_test.dart`, `brand_theme_test.dart`, `qa_design_matrix_test.dart` | No layout exception; `MediaQuery.disableAnimations` and `accessibleNavigation` are safe. |

## Golden policy and rendering tolerances

The checked-in goldens intentionally cover the pilot at 390, 768 and 1280 for
login, paywall, profile, camera permission recovery and shared primitives.
The reference-brand matrix is structural/token validation rather than a
repository of 72 platform-sensitive image snapshots: every reference brand is
rendered in both themes and every breakpoint by `qa_design_matrix_test.dart`.

Golden comparisons run at device-pixel-ratio 1 using the Flutter test host.
They are authoritative for layout, typography hierarchy, visible controls and
brand-token placement. Platform glyph rasterization, font hinting, antialiasing
at curved edges, and native video/camera pixels are not product regressions;
these areas must be asserted through semantics, layout and state tests instead.

No handoff deviation remains open for UI-01…UI-07. Missing real hero imagery is
an approved BrandConfig fallback state, not a visual exception: the design
tests exercise the gradient/monogram fallback until approved assets are
published.
