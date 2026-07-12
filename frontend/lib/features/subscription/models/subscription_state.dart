import 'package:equatable/equatable.dart';
import 'subscription.dart';

/// Subscription state for the app
class SubscriptionState extends Equatable {
  final bool isLoading;
  final SubscriptionStatusResponse? status;
  final String? error;

  const SubscriptionState._({
    required this.isLoading,
    this.status,
    this.error,
  });

  const SubscriptionState.initial()
      : this._(
          isLoading: false,
        );

  const SubscriptionState.loading()
      : this._(
          isLoading: true,
        );

  const SubscriptionState.loaded(SubscriptionStatusResponse status)
      : this._(
          isLoading: false,
          status: status,
        );

  const SubscriptionState.error(String error)
      : this._(
          isLoading: false,
          error: error,
        );

  bool get hasError => error != null;
  bool get hasStatus => status != null;
  bool get isPremium => status?.hasPremiumAccess ?? false;
  bool get isFree => !isPremium;

  SubscriptionFeatures get features =>
      status?.features ?? SubscriptionFeatures.free();

  @override
  List<Object?> get props => [isLoading, status, error];
}
