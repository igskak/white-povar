import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/tokens/app_tokens.dart';
import '../../core/branding/brand_assets.dart';
import '../../core/branding/brand_config.dart';
import '../../core/branding/brand_providers.dart';
import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/camera/presentation/pages/camera_capture_page.dart';
import '../../features/camera/presentation/pages/ingredient_review_page.dart';
import '../../features/camera/presentation/pages/photo_search_results_page.dart';
import '../../features/collections/presentation/pages/collection_detail_page.dart';
import '../../features/collections/presentation/pages/collection_list_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/menu_plan/presentation/pages/menu_plan_page.dart';
import '../../features/pantry/presentation/pages/pantry_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/preferences_page.dart';
import '../../features/profile/presentation/pages/notification_preferences_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/recipes/presentation/pages/cooking_mode_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/saved/presentation/pages/saved_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import '../../features/studio/presentation/pages/studio_brand_page.dart';
import '../../features/studio/presentation/pages/studio_content_page.dart';
import '../../features/studio/presentation/pages/studio_collection_editor_page.dart';
import '../../features/studio/presentation/pages/studio_recipe_editor_page.dart';
import 'route_guards.dart';
import 'route_models.dart';

class AppRoutePaths {
  static const root = '/';
  static const login = '/login';
  static const authCallback = '/auth/callback';
  static const home = '/home';
  static const search = '/search';
  static const saved = '/saved';
  static const profile = '/profile';
  static const settings = '/settings';
  static const preferences = '/preferences';
  static const notificationPreferences = '/notification-preferences';
  static const pantry = '/pantry';
  static const menuPlan = '/menu-plan';
  static const camera = '/camera';
  static const cameraReview = '/camera/review';
  static const cameraResults = '/camera/results';
  static const recipeDetail = '/recipes/:id';
  static const contentDetail = '/content/:id';
  static const collections = '/collections';
  static const cookingMode = '/recipes/:id/cook';
  static const collectionDetail = '/collections/:id';
  static const offer = '/offers/:offerId';
  static const legacySubscription = '/subscription';
  static const studioBrand = '/studio/brand';
  static const studioContent = '/studio/content';
  static const studioRecipeNew = '/studio/content/new';
  static const studioRecipeEdit = '/studio/content/:id/edit';
  static const studioCollectionNew = '/studio/collections/new';
  static const studioCollectionEdit = '/studio/collections/:id/edit';

  static const tabLocations = <String>[home, search, saved, profile];
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // The router instance must stay stable across auth transitions: recreating
  // GoRouter mid-login resets navigation to initialLocation, which both loses
  // the pending `returnTo` target and dumps the user on Home after sign-in.
  // Auth changes only re-run `redirect` via refreshListenable.
  final authRefresh = ValueNotifier(0);
  ref
    ..onDispose(authRefresh.dispose)
    ..listen(authProvider, (_, __) => authRefresh.value++);

  return GoRouter(
    initialLocation: AppRoutePaths.home,
    refreshListenable: authRefresh,
    redirect: (context, state) => RouteGuards.authRedirect(
      authState: ref.read(authProvider),
      uri: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoutePaths.root,
        redirect: (_, __) => AppRoutePaths.home,
      ),
      GoRoute(
        path: AppRoutePaths.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutePaths.authCallback,
        builder: (_, __) => const AuthCallbackPage(),
      ),
      GoRoute(
        path: AppRoutePaths.studioBrand,
        builder: (_, __) => const StudioBrandPage(),
      ),
      GoRoute(
        path: AppRoutePaths.studioContent,
        builder: (_, __) => const StudioContentPage(),
      ),
      GoRoute(
        path: AppRoutePaths.studioRecipeNew,
        builder: (_, __) => const StudioRecipeEditorPage(),
      ),
      GoRoute(
        path: AppRoutePaths.studioRecipeEdit,
        builder: (_, state) => StudioRecipeEditorPage(
          recipeId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutePaths.studioCollectionNew,
        builder: (_, __) => const StudioCollectionEditorPage(),
      ),
      GoRoute(
        path: AppRoutePaths.studioCollectionEdit,
        builder: (_, state) => StudioCollectionEditorPage(
          collectionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutePaths.legacySubscription,
        redirect: (_, __) => OfferRouteLocation.subscription().location,
      ),
      GoRoute(
        path: AppRoutePaths.preferences,
        builder: (_, __) => const PreferencesPage(),
      ),
      GoRoute(
        path: AppRoutePaths.notificationPreferences,
        builder: (_, __) => const NotificationPreferencesPage(),
      ),
      GoRoute(
          path: AppRoutePaths.pantry, builder: (_, __) => const PantryPage()),
      GoRoute(
          path: AppRoutePaths.menuPlan,
          builder: (_, __) => const MenuPlanPage()),
      GoRoute(
        path: AppRoutePaths.offer,
        builder: (_, state) => SubscriptionScreen(
          key: state.pageKey,
          returnTo: OfferRouteLocation.fromUri(state.uri).returnTo,
        ),
      ),
      GoRoute(
        path: AppRoutePaths.recipeDetail,
        builder: (_, state) => _recipeDetail(state),
      ),
      GoRoute(
        path: AppRoutePaths.contentDetail,
        builder: (_, state) => _recipeDetail(state),
      ),
      GoRoute(
        path: AppRoutePaths.cookingMode,
        builder: (_, state) {
          final recipeId = state.pathParameters['id'];
          return recipeId == null || recipeId.isEmpty
              ? const _RouteErrorScreen(
                  title: 'Рецепт не знайдено',
                  subtitle: 'Некоректний ідентифікатор рецепта.',
                )
              : CookingModePage(
                  recipeId: recipeId,
                  collectionId: PreviewGrant.fromUri(state.uri),
                );
        },
      ),
      GoRoute(
        path: AppRoutePaths.camera,
        builder: (_, __) => const CameraCapturePage(),
        routes: [
          GoRoute(
            path: 'review',
            builder: (_, state) {
              final image = state.extra;
              return image is XFile
                  ? IngredientReviewPage(capturedImage: image)
                  : const _RouteErrorScreen(
                      title: 'Фото не знайдено',
                      subtitle:
                          'Спочатку зробіть фото, щоб перейти до перевірки.',
                    );
            },
          ),
          GoRoute(
            path: 'results',
            builder: (_, __) => const PhotoSearchResultsPage(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AdaptiveNavigationShell(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          child: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.home,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomePage(),
                ),
              ),
              GoRoute(
                path: AppRoutePaths.collections,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const CollectionListPage(),
                ),
              ),
              GoRoute(
                path: AppRoutePaths.collectionDetail,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: CollectionDetailPage(
                    collectionId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.search,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: SearchPage(
                    initialRoute: SearchRouteLocation.fromUri(state.uri),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.saved,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SavedPage(embeddedInDesktopShell: true),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.profile,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ProfilePage(embeddedInDesktopShell: true),
                ),
              ),
              GoRoute(
                path: AppRoutePaths.settings,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SettingsPage(embeddedInDesktopShell: true),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, __) => const _RouteErrorScreen(
      title: 'Сторінку не знайдено',
      subtitle: 'Поверніться на головний екран.',
    ),
  );
});

Widget _recipeDetail(GoRouterState state) {
  final recipeId = state.pathParameters['id'];
  return recipeId == null || recipeId.isEmpty
      ? const _RouteErrorScreen(
          title: 'Рецепт не знайдено',
          subtitle: 'Некоректний ідентифікатор рецепта.',
        )
      : RecipeDetailPage(
          recipeId: recipeId,
          collectionId: PreviewGrant.fromUri(state.uri),
        );
}

class AdaptiveNavigationShell extends ConsumerWidget {
  const AdaptiveNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          final isDesktop = constraints.maxWidth >= AppLayout.desktopBreakpoint;
          if (isDesktop) {
            return _DesktopNavigationShell(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              brand: ref.watch(tenantBootstrapProvider).brandConfig.brand,
              child: child,
            );
          }
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: false,
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: onDestinationSelected,
                  // 13f: the blogger avatar sits at the top of the rail.
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: BrandAvatar(
                      brand:
                          ref.watch(tenantBootstrapProvider).brandConfig.brand,
                      radius: 20,
                    ),
                  ),
                  destinations: _navigationRailDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: _navigationDestinations,
          ),
        );
      },
    );
  }
}

/// Editorial desktop chrome: one compact header carries the brand and primary
/// navigation so the content can use the full canvas below it.
class _DesktopNavigationShell extends StatelessWidget {
  const _DesktopNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    required this.brand,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final BrandDetails brand;

  static const _labels = <String>['Головна', 'Рецепти', 'Збережене', 'Профіль'];

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;

    return Scaffold(
      body: Column(
        children: [
          _DesktopTopBar(
            dividerColor: dividerColor,
            brand: brand,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Compact wordmark, text navigation and utility actions in one line.
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.dividerColor,
    required this.brand,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Color dividerColor;
  final BrandDetails brand;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double height = 68;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.gutter(MediaQuery.sizeOf(context).width),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 208,
              child: BrandLogo(brand: brand, height: 24),
            ),
            Row(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  _DesktopTopDestination(
                    label: _DesktopNavigationShell._labels[index],
                    selected: selectedIndex == index,
                    onPressed: () => onDestinationSelected(index),
                  ),
                  if (index < 2) const SizedBox(width: AppSpacing.xxs),
                ],
              ],
            ),
            const Spacer(),
            _DesktopScanButton(
              onPressed: () => context.push(AppRoutePaths.camera),
            ),
            const SizedBox(width: AppSpacing.xs),
            _DesktopProfileButton(
              brand: brand,
              selected: selectedIndex == 3,
              onPressed: () => onDestinationSelected(3),
            ),
          ],
        ),
      );
}

class _DesktopTopDestination extends StatefulWidget {
  const _DesktopTopDestination({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_DesktopTopDestination> createState() => _DesktopTopDestinationState();
}

class _DesktopTopDestinationState extends State<_DesktopTopDestination> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final accent = theme.colorScheme.secondary;
    final foreground = widget.selected ? accent : context.semantic.textPrimary;

    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.lg,
          child: InkWell(
            onTap: widget.onPressed,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: AppRadius.lg,
            child: SizedBox(
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  key: ValueKey('desktop-nav-${widget.label}'),
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 36,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? accent.withOpacity(.08)
                        : _hovered
                            ? context.semantic.surfaceRaised
                            : Colors.transparent,
                    borderRadius: AppRadius.md,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: AnimatedDefaultTextStyle(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 140),
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: foreground,
                            fontWeight: widget.selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          child: Text(widget.label),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: widget.selected ? 18 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: AppRadius.sm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopScanButton extends StatelessWidget {
  const _DesktopScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    return OutlinedButton.icon(
      key: const ValueKey('desktop-scan-button'),
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.xl),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: accent.withOpacity(.42)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? theme.colorScheme.onPrimary
              : accent,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? accent
              : accent.withOpacity(.04),
        ),
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      icon: const Icon(Icons.center_focus_strong_rounded, size: 17),
      label: const Text('Сканувати'),
    );
  }
}

class _DesktopProfileButton extends StatefulWidget {
  const _DesktopProfileButton({
    required this.brand,
    required this.selected,
    required this.onPressed,
  });

  final BrandDetails brand;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_DesktopProfileButton> createState() => _DesktopProfileButtonState();
}

class _DesktopProfileButtonState extends State<_DesktopProfileButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: 'Профіль',
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: 'Профіль',
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onPressed,
              customBorder: const CircleBorder(),
              mouseCursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    key: const ValueKey('desktop-profile-button'),
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hovered
                          ? context.semantic.surfaceRaised
                          : context.semantic.surface,
                      border: Border.all(
                        color: widget.selected || _hovered
                            ? theme.colorScheme.primary
                            : context.semantic.outlineVariant,
                        width: widget.selected ? 2 : 1,
                      ),
                    ),
                    child: BrandAvatar(brand: widget.brand, radius: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _navigationRailDestinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: Text('Головна'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.search_outlined),
    selectedIcon: Icon(Icons.search),
    label: Text('Пошук'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.bookmark_border_rounded),
    selectedIcon: Icon(Icons.bookmark_rounded),
    label: Text('Збережене'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person_rounded),
    label: Text('Профіль'),
  ),
];

const _navigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: 'Головна',
  ),
  NavigationDestination(
    icon: Icon(Icons.search_outlined),
    selectedIcon: Icon(Icons.search),
    label: 'Пошук',
  ),
  NavigationDestination(
    icon: Icon(Icons.bookmark_border_rounded),
    selectedIcon: Icon(Icons.bookmark_rounded),
    label: 'Збережене',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person_rounded),
    label: 'Профіль',
  ),
];

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppRoutePaths.home),
                  child: const Text('На головну'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
