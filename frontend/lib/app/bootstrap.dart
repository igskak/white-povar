import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/branding/brand_bootstrapper.dart';
import '../core/branding/brand_providers.dart';
import '../firebase_options.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validateRequiredConfig();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  final tenantBootstrap = await BrandBootstrapper(
    tenantSlug: AppConfig.tenantSlug,
    storage: const SharedPreferencesBrandBootstrapStorage(),
    remoteLoader: HttpBrandBootstrapRemoteLoader(),
  ).load();

  runApp(
    ProviderScope(
      overrides: [tenantBootstrapProvider.overrideWithValue(tenantBootstrap)],
      child: const WhitePovarAppV2(),
    ),
  );
}
