import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/brand_theme.dart';
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
        path: AppRoutePaths.legacySubscription,
        redirect: (_, __) => OfferRouteLocation.subscription().location,
      ),
      GoRoute(
        path: AppRoutePaths.settings,
        builder: (_, __) => const SettingsPage(),
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
        path: AppRoutePaths.collections,
        builder: (_, __) => const CollectionListPage(),
      ),
      GoRoute(
        path: AppRoutePaths.collectionDetail,
        builder: (_, state) =>
            CollectionDetailPage(collectionId: state.pathParameters['id']!),
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
              : CookingModePage(recipeId: recipeId);
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
                  child: const SavedPage(),
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
                  child: const ProfilePage(),
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
      : RecipeDetailPage(recipeId: recipeId);
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
          final isDesktop = constraints.maxWidth >= 1024;
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

/// Desktop navigation follows the product handoff rather than stretching the
/// Material rail: a compact branded rail owns navigation while the top bar
/// owns global search and the camera entry point.
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

  static const _items = <({String label, IconData icon, IconData selected})>[
    (label: 'Головна', icon: Icons.home_outlined, selected: Icons.home_rounded),
    (label: 'Пошук', icon: Icons.search_outlined, selected: Icons.search),
    (
      label: 'Збережене',
      icon: Icons.bookmark_border_rounded,
      selected: Icons.bookmark_rounded,
    ),
    (
      label: 'Профіль',
      icon: Icons.person_outline,
      selected: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final railColor = dark ? const Color(0xFF221D16) : scheme.surface;
    final dividerColor = dark ? const Color(0xFF2E2820) : scheme.outlineVariant;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 92,
            child: ColoredBox(
              color: railColor,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Semantics(
                    label: brand.name,
                    image: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: BrandAvatar(brand: brand, radius: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < _items.length; index++)
                    _DesktopRailDestination(
                      label: _items[index].label,
                      icon: _items[index].icon,
                      selectedIcon: _items[index].selected,
                      selected: selectedIndex == index,
                      onPressed: () => onDestinationSelected(index),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Налаштування',
                    onPressed: () => context.push(AppRoutePaths.settings),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: dividerColor),
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(dividerColor: dividerColor, brand: brand),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopRailDestination extends StatelessWidget {
  const _DesktopRailDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.extension<BrandThemeExtension>()?.accent ??
        theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon,
                    color: selected ? accent : null),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? accent : null,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.dividerColor, required this.brand});

  final Color dividerColor;
  final BrandDetails brand;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: BrandLogo(
                brand: brand,
                height: 30,
              ),
            ),
            SizedBox(
              width: 320,
              child: OutlinedButton.icon(
                onPressed: () => context.go(AppRoutePaths.search),
                icon: const Icon(Icons.search),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Назва, інгредієнт або кухня'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutePaths.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Сканувати'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Профіль',
              onPressed: () => context.go(AppRoutePaths.profile),
              icon: const Icon(Icons.account_circle_outlined, size: 32),
            ),
          ],
        ),
      );
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
