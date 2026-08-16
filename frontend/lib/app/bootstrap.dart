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
    publishableKey: AppConfig.supabaseAnonKey,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  final bootstrapper = BrandBootstrapper(
    tenantSlug: AppConfig.tenantSlug,
    storage: const SharedPreferencesBrandBootstrapStorage(),
    remoteLoader: HttpBrandBootstrapRemoteLoader(),
  );

  // Null only for the instant before the controller exists; the late arrival
  // cannot fire before then, and dropping it would be harmless anyway.
  TenantBrandController? brand;
  final tenantBootstrap = await bootstrapper.load(
    // A wake-up that outran the startup budget still applies to this session.
    onLateArrival: (arrived) => brand?.adopt(arrived),
  );
  final controller = TenantBrandController(
    initial: tenantBootstrap,
    refresher: bootstrapper.refresh,
  );
  brand = controller;

  runApp(
    ProviderScope(
      overrides: [
        tenantBrandControllerProvider.overrideWith((ref) => controller),
      ],
      child: const WhitePovarAppV2(),
    ),
  );
}
