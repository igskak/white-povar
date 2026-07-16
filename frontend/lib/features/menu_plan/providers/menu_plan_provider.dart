import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/menu_plan.dart';
import '../services/menu_plan_service.dart';

final menuPlanServiceProvider =
    Provider((ref) => MenuPlanService(ref.watch(apiClientProvider)));
final menuPlanWeekProvider = FutureProvider.family<MenuPlanWeek, DateTime>(
    (ref, monday) => ref.watch(menuPlanServiceProvider).week(monday));
