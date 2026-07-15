import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/preference_profile.dart';
import '../services/preference_service.dart';

final preferenceServiceProvider = Provider<PreferenceService>(
  (ref) => PreferenceService(ref.watch(apiClientProvider)),
);

final preferenceProfileProvider = FutureProvider<PreferenceProfile>(
  (ref) => ref.watch(preferenceServiceProvider).get(),
);
