import 'package:equatable/equatable.dart';

/// Subscription tier enumeration
enum SubscriptionTier {
  free,
  premium;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  static SubscriptionTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }
}

/// Subscription status enumeration
enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  trial;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.trial:
        return 'Trial';
    }
  }

  static SubscriptionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'trial':
        return SubscriptionStatus.trial;
      default:
        return SubscriptionStatus.active;
    }
  }
}

/// User subscription information
class UserSubscriptionInfo extends Equatable {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  const UserSubscriptionInfo({
    required this.tier,
    required this.status,
    this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory UserSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionInfo(
      tier: SubscriptionTier.fromString(json['tier'] ?? 'free'),
      status: SubscriptionStatus.fromString(json['status'] ?? 'active'),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'status': status.name,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
    };
  }

  bool get isPremium => tier == SubscriptionTier.premium && isActive;
  bool get isFree => tier == SubscriptionTier.free;

  @override
  List<Object?> get props => [tier, status, startDate, endDate, isActive];
}

/// Subscription features
class SubscriptionFeatures extends Equatable {
  final bool aiRecipeGeneration;
  final bool aiCookingTips;
  final bool aiSubstitutions;
  final bool aiNutritionAnalysis;
  final bool premiumRecipes;
  final bool advancedSearch;
  final bool basicRecipes;
  final bool basicSearch;
  final bool favorites;

  const SubscriptionFeatures({
    required this.aiRecipeGeneration,
    required this.aiCookingTips,
    required this.aiSubstitutions,
    required this.aiNutritionAnalysis,
    required this.premiumRecipes,
    required this.advancedSearch,
    required this.basicRecipes,
    required this.basicSearch,
    required this.favorites,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeatures(
      aiRecipeGeneration: json['ai_recipe_generation'] == true,
      aiCookingTips: json['ai_cooking_tips'] == true,
      aiSubstitutions: json['ai_substitutions'] == true,
      aiNutritionAnalysis: json['ai_nutrition_analysis'] == true,
      premiumRecipes: json['premium_recipes'] == true,
      advancedSearch: json['advanced_search'] == true,
      basicRecipes: json['basic_recipes'] == true,
      basicSearch: json['basic_search'] == true,
      favorites: json['favorites'] == true,
    );
  }

  factory SubscriptionFeatures.free() {
    return const SubscriptionFeatures(
      aiRecipeGeneration: false,
      aiCookingTips: false,
      aiSubstitutions: false,
      aiNutritionAnalysis: false,
      premiumRecipes: false,
      advancedSearch: false,
      basicRecipes: true,
      basicSearch: true,
      favorites: true,
    );
  }

  factory SubscriptionFeatures.premium() {
    return const SubscriptionFeatures(
      aiRecipeGeneration: true,
      aiCookingTips: true,
      aiSubstitutions: true,
      aiNutritionAnalysis: true,
      premiumRecipes: true,
      advancedSearch: true,
      basicRecipes: true,
      basicSearch: true,
      favorites: true,
    );
  }

  @override
  List<Object?> get props => [
        aiRecipeGeneration,
        aiCookingTips,
        aiSubstitutions,
        aiNutritionAnalysis,
        premiumRecipes,
        advancedSearch,
        basicRecipes,
        basicSearch,
        favorites,
      ];
}

/// Complete subscription status response
class SubscriptionStatusResponse extends Equatable {
  final String userId;
  final UserSubscriptionInfo subscription;
  final bool hasPremiumAccess;
  final SubscriptionFeatures features;

  const SubscriptionStatusResponse({
    required this.userId,
    required this.subscription,
    required this.hasPremiumAccess,
    required this.features,
  });

  factory SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusResponse(
      userId: json['user_id']?.toString() ?? '',
      subscription: UserSubscriptionInfo.fromJson(json['subscription'] ?? {}),
      hasPremiumAccess: json['has_premium_access'] == true,
      features: SubscriptionFeatures.fromJson(json['features'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [userId, subscription, hasPremiumAccess, features];
}

/// Upgrade prompt for premium features
class UpgradePrompt extends Equatable {
  final String title;
  final String message;
  final List<String> features;
  final String ctaText;
  final String ctaAction;

  const UpgradePrompt({
    required this.title,
    required this.message,
    required this.features,
    required this.ctaText,
    required this.ctaAction,
  });

  factory UpgradePrompt.fromJson(Map<String, dynamic> json) {
    return UpgradePrompt(
      title: json['title']?.toString() ?? 'Upgrade to Premium',
      message: json['message']?.toString() ?? '',
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ctaText: json['cta_text']?.toString() ?? 'Upgrade Now',
      ctaAction: json['cta_action']?.toString() ?? 'navigate_to_subscription',
    );
  }

  @override
  List<Object?> get props => [title, message, features, ctaText, ctaAction];
}

/// Premium access check result
class PremiumAccessCheck extends Equatable {
  final bool hasAccess;
  final SubscriptionTier tier;
  final String? reason;
  final bool upgradeRequired;

  const PremiumAccessCheck({
    required this.hasAccess,
    required this.tier,
    this.reason,
    required this.upgradeRequired,
  });

  factory PremiumAccessCheck.fromJson(Map<String, dynamic> json) {
    return PremiumAccessCheck(
      hasAccess: json['has_access'] == true,
      tier: SubscriptionTier.fromString(json['tier'] ?? 'free'),
      reason: json['reason']?.toString(),
      upgradeRequired: json['upgrade_required'] == true,
    );
  }

  @override
  List<Object?> get props => [hasAccess, tier, reason, upgradeRequired];
}
