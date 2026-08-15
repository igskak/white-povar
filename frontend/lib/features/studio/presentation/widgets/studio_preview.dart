import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/presentation/widgets/login_scene.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/widgets/home_scene.dart';
import '../../../recipes/models/recipe.dart';
import '../../../subscription/purchase_adapter.dart';
import '../../../subscription/widgets/paywall_scene.dart';

/// Which consumer scene the Studio preview frame is showing.
enum StudioPreviewTab { home, login, paywall }

/// Which window the preview frame stands in for.
///
/// Home is laid out twice — the compact composition and, past
/// [AppLayout.contentDesktopBreakpoint], the desktop one — and a photo cropped
/// against the phone frame is not the crop a 1280 window shows. The editor
/// therefore offers both rather than implying the phone is the whole truth.
enum StudioPreviewViewport {
  phone(label: 'Телефон', window: Size(390, 720), page: Size(390, 720)),

  /// A 1280 window: the page keeps what the branded rail and the top bar leave
  /// it, and reads the *window* width for its gutters, exactly as in the app.
  desktop(
    label: 'Десктоп',
    window: Size(BrandMediaAspectRatio.desktopWindowWidth, 800),
    page: Size(
      BrandMediaAspectRatio.desktopWindowWidth - AppLayout.railWidth - 1,
      800 - _desktopTopBarHeight,
    ),
  );

  const StudioPreviewViewport({
    required this.label,
    required this.window,
    required this.page,
  });

  final String label;

  /// What `MediaQuery.sizeOf` reports inside the frame.
  final Size window;

  /// The area the shell leaves the page, which is what the frame draws.
  final Size page;
}

const double _desktopTopBarHeight = 60;

/// The design's preview frame (13m): «рендер тим самим кодом застосунку, без
/// скриншотів».
///
/// Every scene is composed from the widgets the consumer app itself renders, so
/// a brand change cannot look right here and wrong in the app. Optional fields
/// fall back exactly as 13j/13d describe: no heroPhotos → gradient login hero,
/// no courseName → no course card, unreachable avatar → monogram.
class StudioBrandPreview extends StatefulWidget {
  const StudioBrandPreview({
    super.key,
    required this.config,
    required this.tab,
    this.viewport = StudioPreviewViewport.phone,
  });

  final BrandConfig config;
  final StudioPreviewTab tab;
  final StudioPreviewViewport viewport;

  /// Login and the paywall are still composed inside their pages rather than
  /// in shared scene widgets, so the preview can only tell the truth about
  /// their compact layout. Home is offered at both widths.
  static bool supportsViewportChoice(StudioPreviewTab tab) =>
      tab == StudioPreviewTab.home;

  @override
  State<StudioBrandPreview> createState() => _StudioBrandPreviewState();
}

class _StudioBrandPreviewState extends State<StudioBrandPreview> {
  // The login scene is the app's real form, which owns real controllers. The
  // preview keeps them alive but inert (see the IgnorePointer/ExcludeFocus).
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.tab == StudioPreviewTab.home
        ? AppThemeV2.light(widget.config)
        // Login and paywall are dark scenes in both app themes.
        : AppThemeV2.dark(widget.config);
    final viewport = StudioBrandPreview.supportsViewportChoice(widget.tab)
        ? widget.viewport
        : StudioPreviewViewport.phone;

    return AspectRatio(
      aspectRatio: viewport.page.width / viewport.page.height,
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox.fromSize(
            size: viewport.page,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // The window, not the frame: page gutters are resolved from the
                // viewport width in the app, and the frame is only the slice
                // the shell leaves behind.
                size: viewport.window,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                textScaler: TextScaler.noScaling,
              ),
              child: Theme(
                data: theme,
                // The app's recipe cards carry their own save affordance, which
                // reads the session. The preview is a picture of the app as a
                // visitor meets it, so it answers "signed out" locally instead
                // of reaching for the editor's own account.
                child: ProviderScope(
                  overrides: [currentUserProvider.overrideWithValue(null)],
                  // A preview is a picture of the app, not a second copy of it:
                  // nothing here should steal focus or accept a tap.
                  child: IgnorePointer(
                    child: ExcludeFocus(
                      child: Builder(builder: _scene),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(BuildContext context) => switch (widget.tab) {
        StudioPreviewTab.home =>
          widget.viewport == StudioPreviewViewport.desktop
              ? _desktopHome(context)
              : _home(context),
        StudioPreviewTab.login => _login(context),
        StudioPreviewTab.paywall => _paywall(context),
      };

  /// The compact Home, section for section: the app's own [HomeIntro] and
  /// [HomeFeedSections], not a second arrangement of them. 13j/13d fallbacks
  /// (no Home photo → no banner, no courseName → no course card) come along
  /// with the widgets.
  Widget _home(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeIntro(
                brand: widget.config.brand,
                userName: null,
                onProfileTap: () {},
                onScanTap: () {},
                onTypeTap: () {},
              ),
              HomeFeedSections(
                brand: widget.config.brand,
                recipes: _sampleRecipes,
                courseLocked: true,
                onOpenRecipe: (_) {},
                onCollectionTap: () {},
                onUnlockCourse: () {},
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      );

  /// Home as a 1280 window draws it: the shell owns the brand header and the
  /// capture entry point, the page opens on the photo, and the banner takes
  /// the crop a wide column gives it — which is not the phone's crop.
  Widget _desktopHome(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: HomeDesktopSections.pagePadding,
          child: HomeDesktopSections(
            brand: widget.config.brand,
            recipes: _sampleRecipes,
            courseLocked: true,
            onOpenRecipe: (_) {},
            onSeeAll: () {},
            onCollectionTap: () {},
            onUnlockCourse: () {},
          ),
        ),
      );

  Widget _login(BuildContext context) {
    final brand = widget.config.brand;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoginHero(brand: brand, compact: true),
            const SizedBox(height: AppSpacing.md),
            LoginForm(
              brandName: brand.name,
              loginTitle: brand.voice.loginTitle,
              avatar: BrandAvatar(brand: brand, radius: 36),
              mode: LoginMode.signIn,
              formKey: _formKey,
              emailController: _email,
              passwordController: _password,
              emailFocus: _emailFocus,
              passwordFocus: _passwordFocus,
              obscurePassword: true,
              resetSent: false,
              verificationPending: false,
              isLoading: false,
              error: null,
              onSubmit: () {},
              onTogglePassword: () {},
              onModeChanged: (_) {},
              onProviderPressed: (_) {},
              onGuestPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _paywall(BuildContext context) {
    final brand = widget.config.brand;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(22, AppSpacing.md, 22, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              AppIconButton(
                  icon: Icons.close, tooltip: 'Закрити', onPressed: () {}),
              const Spacer(),
              Text('ПІДПИСКА',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.brandTheme.accentOnDark,
                      letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 10),
            PaywallPitch(brand: brand),
            const SizedBox(height: 14),
            PaywallPlans(
              products: _sampleProducts,
              selectedId: _sampleProducts.first.id,
              onSelect: (_) {},
              ctaLabel: 'Спробувати 7 днів безкоштовно',
              footnote: 'Далі 1499 ₴/рік · скасувати будь-коли',
              onPurchase: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Відновити покупку',
              variant: AppButtonVariant.text,
              expand: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// A neutral stand-in for the tenant's own feed. The cards carry no image so
/// the preview shows the app's honest image fallback rather than borrowed
/// stock, and there are enough of them for the desktop grid to read as a grid.
final List<Recipe> _sampleRecipes = [
  _sampleRecipe(
    id: 'studio-preview',
    title: 'Лосось із зеленою сальсою',
    featured: true,
  ),
  for (var index = 1; index < 5; index++)
    _sampleRecipe(
      id: 'studio-preview-$index',
      title: 'Приклад рецепта $index',
    ),
];

Recipe _sampleRecipe({
  required String id,
  required String title,
  bool featured = false,
}) =>
    Recipe(
      id: id,
      title: title,
      description: 'Приклад картки рецепта у вашому бренді.',
      chefId: 'studio-preview',
      cuisine: 'Вечеря',
      category: 'Основні страви',
      difficulty: 2,
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      servings: 2,
      ingredients: const [],
      instructions: const [],
      images: const [],
      tags: const [],
      isFeatured: featured,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// Example store prices (13m: «ціни-приклад зі стора»). Real prices come from
/// App Store / Google Play at runtime, never from BrandConfig.
const List<PurchaseProduct> _sampleProducts = [
  PurchaseProduct(
    id: 'studio.preview.annual',
    title: 'Річний',
    price: '1499 ₴',
    detail: '125 ₴/міс · 7 днів безкоштовно',
    badge: '−37%',
  ),
  PurchaseProduct(
    id: 'studio.preview.monthly',
    title: 'Місячний',
    price: '199 ₴',
  ),
];
