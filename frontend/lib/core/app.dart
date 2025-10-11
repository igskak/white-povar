import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/router/app_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/subscription/providers/subscription_provider.dart';

class CookingApp extends ConsumerWidget {
  const CookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(themeProvider);

    // Listen to auth state changes and load subscription when user logs in
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          (previous == null || !previous.isAuthenticated)) {
        // User just logged in, load subscription status
        ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
      }
    });

    return MaterialApp.router(
      title: 'White-Label Cooking App',
      theme: theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
