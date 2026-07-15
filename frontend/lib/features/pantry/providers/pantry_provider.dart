import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/pantry_models.dart';
import '../services/pantry_service.dart';

final pantryServiceProvider =
    Provider((ref) => PantryService(ref.watch(apiClientProvider)));
final pantryProvider = FutureProvider<List<PantryItem>>(
    (ref) => ref.watch(pantryServiceProvider).pantry());
final shoppingProvider = FutureProvider<List<ShoppingItem>>(
    (ref) => ref.watch(pantryServiceProvider).shopping());
