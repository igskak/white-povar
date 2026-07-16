import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/notification_preferences.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);

final notificationPreferencesProvider = FutureProvider<NotificationPreferences>(
  (ref) => ref.watch(notificationServiceProvider).get(),
);
