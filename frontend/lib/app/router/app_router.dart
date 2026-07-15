import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/camera/presentation/pages/camera_capture_page.dart';
import '../../features/camera/presentation/pages/ingredient_review_page.dart';
import '../../features/camera/presentation/pages/photo_search_results_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/pantry/presentation/pages/pantry_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/preferences_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/recipes/presentation/pages/cooking_mode_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/saved/presentation/pages/saved_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/subscription/screens/subscription_screen.dart';
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
  static const pantry = '/pantry';
  static const camera = '/camera';
  static const cameraReview = '/camera/review';
  static const cameraResults = '/camera/results';
  static const recipeDetail = '/recipes/:id';
  static const contentDetail = '/content/:id';
  static const cookingMode = '/recipes/:id/cook';
  static const collectionDetail = '/collections/:id';
  static const offer = '/offers/:offerId';
  static const legacySubscription = '/subscription';

  static const tabLocations = <String>[home, search, saved, profile];
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutePaths.home,
    redirect: (context, state) => RouteGuards.authRedirect(
      authState: authState,
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
          path: AppRoutePaths.pantry, builder: (_, __) => const PantryPage()),
      GoRoute(
        path: AppRoutePaths.offer,
        builder: (_, state) => SubscriptionScreen(
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: AppRoutePaths.collectionDetail,
        builder: (_, state) => _CollectionRoutePage(
          collectionId: state.pathParameters['id']!,
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

class AdaptiveNavigationShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          final isDesktop = constraints.maxWidth >= 1024;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: isDesktop,
                  selectedIndex: selectedIndex,
                  labelType: isDesktop ? null : NavigationRailLabelType.all,
                  onDestinationSelected: onDestinationSelected,
                  destinations: _navigationRailDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: isDesktop
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: child,
                          ),
                        )
                      : child,
                ),
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

class _CollectionRoutePage extends StatelessWidget {
  const _CollectionRoutePage({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context) => _RouteErrorScreen(
        title: 'Колекція готується',
        subtitle:
            'Колекція $collectionId стане доступною після оновлення каталогу.',
      );
}

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
