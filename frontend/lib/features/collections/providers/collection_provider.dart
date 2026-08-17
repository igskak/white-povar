import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/branding/brand_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/collection.dart';
import '../services/collection_service.dart';

final collectionServiceProvider = Provider<CollectionService>(
  (ref) => CollectionService(ref.watch(apiClientProvider)),
);

final collectionListProvider = FutureProvider<List<ContentCollection>>((ref) {
  // Re-fetch access projections once a persisted session is restored. The API
  // intentionally returns locked collection teasers to anonymous requests.
  ref.watch(currentUserProvider);
  return ref.watch(collectionServiceProvider).getCollections();
});

final collectionDetailProvider =
    FutureProvider.family<ContentCollection, String>((ref, id) {
  ref.watch(currentUserProvider);
  return ref.watch(collectionServiceProvider).getCollection(id);
});

/// The id of the collection the brand publishes as its course, or null when the
/// brand names no course, the list has not arrived yet, or `courseTag` matches
/// no published collection.
///
/// `courseTag` names that collection by slug. Every surface that offers the
/// course resolves it here, so they cannot disagree about which collection it
/// is — or about what to do when the tag matches nothing.
final courseCollectionIdProvider = Provider<String?>((ref) {
  final courseTag =
      ref.watch(tenantBootstrapProvider).brandConfig.brand.courseTag;
  if (courseTag == null) return null;
  return ref
      .watch(collectionListProvider)
      .valueOrNull
      ?.where((collection) => collection.slug == courseTag)
      .map((collection) => collection.id)
      .firstOrNull;
});
