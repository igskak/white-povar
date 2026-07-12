class SubscriptionEntity {
  const SubscriptionEntity({
    required this.plan,
    required this.isActive,
  });

  final String plan;
  final bool isActive;
}
