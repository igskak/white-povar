import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/recipes/presentation/pages/recipe_list_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../../features/camera/presentation/pages/camera_capture_page.dart';
import '../../features/camera/presentation/pages/ingredient_review_page.dart';
import '../../features/camera/presentation/pages/photo_search_results_page.dart';

// Route names
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipes/:id';
  static const String search = '/search';
  static const String authCallback = '/auth/callback';
  static const String camera = '/camera';
  static const String cameraReview = '/camera/review';
  static const String cameraResults = '/camera/results';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // If not logged in and not on login page, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      // If logged in and on login page, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home;
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        name: 'auth-callback',
        builder: (context, state) => const AuthCallbackPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const RecipeListPage(),
        routes: [
          GoRoute(
            path: 'search',
            name: 'search',
            builder: (context, state) => const SearchPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/recipes/:id',
        name: 'recipe-detail',
        builder: (context, state) {
          final recipeId = state.pathParameters['id']!;
          return RecipeDetailPage(recipeId: recipeId);
        },
      ),
      GoRoute(
        path: AppRoutes.camera,
        name: 'camera',
        builder: (context, state) => const CameraCaptureePage(),
        routes: [
          GoRoute(
            path: 'review',
            name: 'camera-review',
            builder: (context, state) {
              final capturedImage = state.extra as XFile?;
              if (capturedImage == null) {
                // Redirect back to camera if no image
                return const CameraCaptureePage();
              }
              return IngredientReviewPage(capturedImage: capturedImage);
            },
          ),
          GoRoute(
            path: 'results',
            name: 'camera-results',
            builder: (context, state) => const PhotoSearchResultsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found: ${state.matchedLocation}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
