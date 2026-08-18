import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../recipes/providers/recipe_provider.dart';
import '../models/profile_stats.dart';
import '../services/profile_stats_service.dart';

final profileStatsServiceProvider = Provider<ProfileStatsService>(
  (ref) => ProfileStatsService(ref.watch(apiClientProvider)),
);

/// The counters shown on the profile.
///
/// Watching the session rebuilds them when the account changes, so one user's
/// totals can never survive into the next session. Watching the saved set
/// re-counts them the moment a recipe is saved or unsaved, which is the one
/// case where the profile and the Saved page would otherwise disagree in front
/// of the user. Cooking and scanning invalidate this provider at their own
/// call sites.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const ProfileStats(saved: 0, cooked: 0, scans: 0);
  ref.watch(favoriteIdsProvider);
  return ref.watch(profileStatsServiceProvider).get();
});
