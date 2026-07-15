import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/collection.dart';
import '../services/collection_service.dart';

final collectionServiceProvider = Provider<CollectionService>(
  (ref) => CollectionService(ref.watch(apiClientProvider)),
);

final collectionListProvider = FutureProvider<List<ContentCollection>>(
  (ref) => ref.watch(collectionServiceProvider).getCollections(),
);

final collectionDetailProvider =
    FutureProvider.family<ContentCollection, String>(
  (ref, id) => ref.watch(collectionServiceProvider).getCollection(id),
);
