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
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/saved/presentation/pages/saved_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/recipes/presentation/pages/cooking_mode_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import 'route_guards.dart';

class AppRoutePaths {
  static const root = '/';
  static const login = '/login';
  static const authCallback = '/auth/callback';

  static const home = '/home';
  static const search = '/search';
  static const camera = '/camera';
  static const saved = '/saved';
  static const subscription = '/subscription';
  static const profile = '/profile';

  static const cameraReview = '/camera/review';
  static const cameraResults = '/camera/results';
  static const settings = '/settings';

  static const recipeDetail = '/recipes/:id';
  static const cookingMode = '/recipes/:id/cook';

  static const tabLocations = <String>[
    home,
    search,
    saved,
    profile,
  ];
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutePaths.home,
    redirect: (context, state) {
      return RouteGuards.authRedirect(
        authState: authState,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.root,
        redirect: (context, state) => AppRoutePaths.home,
      ),
      GoRoute(
        path: AppRoutePaths.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutePaths.authCallback,
        builder: (context, state) => const AuthCallbackPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return _AppShellScaffold(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutePaths.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutePaths.search,
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: AppRoutePaths.camera,
            builder: (context, state) => const CameraCapturePage(),
          ),
          GoRoute(
            path: AppRoutePaths.saved,
            builder: (context, state) => const SavedPage(),
          ),
          GoRoute(
            path: AppRoutePaths.subscription,
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: AppRoutePaths.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: AppRoutePaths.cameraReview,
            builder: (context, state) {
              final image = state.extra;
              if (image is! XFile) {
                return const _RouteErrorScreen(
                  title: 'Photo missing',
                  subtitle: 'Capture a photo first to continue review.',
                );
              }
              return IngredientReviewPage(capturedImage: image);
            },
          ),
          GoRoute(
            path: AppRoutePaths.cameraResults,
            builder: (context, state) => const PhotoSearchResultsPage(),
          ),
          GoRoute(
            path: AppRoutePaths.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutePaths.recipeDetail,
            builder: (context, state) {
              final recipeId = state.pathParameters['id'];
              if (recipeId == null || recipeId.isEmpty) {
                return const _RouteErrorScreen(
                  title: 'Recipe not found',
                  subtitle: 'Invalid recipe id.',
                );
              }
              return RecipeDetailPage(recipeId: recipeId);
            },
          ),
          GoRoute(
            path: AppRoutePaths.cookingMode,
            builder: (context, state) {
              final recipeId = state.pathParameters['id'];
              if (recipeId == null || recipeId.isEmpty) {
                return const _RouteErrorScreen(
                  title: 'Recipe not found',
                  subtitle: 'Invalid recipe id.',
                );
              }
              return CookingModePage(recipeId: recipeId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return const _RouteErrorScreen(
        title: 'Route not found',
        subtitle: 'Please return to Home tab.',
      );
    },
  );
});

class _AppShellScaffold extends StatelessWidget {
  const _AppShellScaffold({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int _currentIndex() {
    if (location.startsWith('/recipes')) {
      return 0;
    }

    if (location.startsWith(AppRoutePaths.settings)) {
      return 3;
    }

    for (var i = 0; i < AppRoutePaths.tabLocations.length; i++) {
      if (location.startsWith(AppRoutePaths.tabLocations[i])) {
        return i;
      }
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _currentIndex();
    final showNavigation = !location.startsWith(AppRoutePaths.camera) &&
        !location.startsWith('/recipes/');

    return Scaffold(
      body: child,
      bottomNavigationBar: showNavigation
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                context.go(AppRoutePaths.tabLocations[index]);
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.search), label: 'Discover'),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border_rounded),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutePaths.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
