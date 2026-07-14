import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class WhitePovarAppV2 extends ConsumerWidget {
  const WhitePovarAppV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppThemeV2.light(),
      darkTheme: AppThemeV2.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
