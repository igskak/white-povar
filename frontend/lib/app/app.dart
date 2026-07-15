import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/brand_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class WhitePovarAppV2 extends ConsumerWidget {
  const WhitePovarAppV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final tenantBootstrap = ref.watch(tenantBootstrapProvider);

    return MaterialApp.router(
      title: tenantBootstrap.brandConfig.brand.name,
      debugShowCheckedModeBanner: false,
      theme: AppThemeV2.light(),
      darkTheme: AppThemeV2.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
