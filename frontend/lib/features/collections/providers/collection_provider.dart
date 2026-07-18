import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
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
