import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/presentation/widgets/login_scene.dart';
import '../../../home/presentation/widgets/home_scene.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../../subscription/purchase_adapter.dart';
import '../../../subscription/widgets/paywall_scene.dart';

/// Which consumer scene the Studio preview frame is showing.
enum StudioPreviewTab { home, login, paywall }

/// The design's 390-wide preview frame (13m): «рендер тим самим кодом
/// застосунку, без скриншотів».
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
  });

  final BrandConfig config;
  final StudioPreviewTab tab;

  /// Design frame: 390 logical px wide, scaled down to the editor column.
  static const Size frame = Size(390, 720);

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

    return AspectRatio(
      aspectRatio:
          StudioBrandPreview.frame.width / StudioBrandPreview.frame.height,
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox.fromSize(
            size: StudioBrandPreview.frame,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: StudioBrandPreview.frame,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                textScaler: TextScaler.noScaling,
              ),
              child: Theme(
                data: theme,
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
    );
  }

  Widget _scene(BuildContext context) => switch (widget.tab) {
        StudioPreviewTab.home => _home(context),
        StudioPreviewTab.login => _login(context),
        StudioPreviewTab.paywall => _paywall(context),
      };

  Widget _home(BuildContext context) {
    final brand = widget.config.brand;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandHeader(
              brand: brand,
              trailing: const UserAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              brand.voice.greeting,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFamily: context.brandTheme.displayFontFamily,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ScanBanner(onTap: () {}),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Ввести вручну',
                icon: Icons.keyboard_alt_outlined,
                variant: AppButtonVariant.text,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RecipeCard.featured(recipe: _sampleRecipe, compact: true),
            // 13g/13j: no courseName published → no course card at all.
            if (brand.voice.courseName != null && brand.courseTag != null) ...[
              const SizedBox(height: AppSpacing.md),
              BrandCourseCard(
                courseName: brand.voice.courseName!,
                locked: true,
                onOpen: () {},
                onUnlock: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }

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

/// A neutral stand-in for the tenant's own feed. It carries no image so the
/// preview shows the app's honest image fallback rather than borrowed stock.
final Recipe _sampleRecipe = Recipe(
  id: 'studio-preview',
  title: 'Лосось із зеленою сальсою',
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
  isFeatured: true,
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
