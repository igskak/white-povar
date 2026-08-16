import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/brand_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class WhitePovarAppV2 extends ConsumerStatefulWidget {
  const WhitePovarAppV2({super.key});

  @override
  ConsumerState<WhitePovarAppV2> createState() => _WhitePovarAppV2State();
}

class _WhitePovarAppV2State extends ConsumerState<WhitePovarAppV2>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is the moment a reader is most likely to meet a
  /// brand that changed while they were away. The controller throttles this,
  /// so a user switching apps all afternoon still costs one request.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(tenantBrandControllerProvider.notifier).refreshIfStale();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final tenantBootstrap = ref.watch(tenantBootstrapProvider);

    return MaterialApp.router(
      title: tenantBootstrap.brandConfig.brand.name,
      debugShowCheckedModeBanner: false,
      theme: AppThemeV2.light(tenantBootstrap.brandConfig),
      darkTheme: AppThemeV2.dark(tenantBootstrap.brandConfig),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
