import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../models/subscription.dart';
import '../models/subscription_state.dart';
import '../services/subscription_service.dart';

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionService _subscriptionService;
  final AuthService _authService;

  SubscriptionNotifier(this._subscriptionService, this._authService)
      : super(const SubscriptionState.initial());

  /// Load subscription status
  Future<void> loadSubscriptionStatus() async {
    state = const SubscriptionState.loading();
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        state = const SubscriptionState.error('Not authenticated');
        return;
      }

      final status = await _subscriptionService.getSubscriptionStatus(token);
      state = SubscriptionState.loaded(status);
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
      state = SubscriptionState.error(e.toString());
    }
  }

  /// Refresh subscription status
  Future<void> refresh() async {
    await loadSubscriptionStatus();
  }

  /// Check if user has premium access for a specific feature
  Future<PremiumAccessCheck> checkPremiumAccess({String? feature}) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      return await _subscriptionService.checkPremiumAccess(
        token,
        feature: feature,
      );
    } catch (e) {
      debugPrint('Error checking premium access: $e');
      rethrow;
    }
  }

  /// Get upgrade prompt for a specific feature type
  Future<UpgradePrompt> getUpgradePrompt(String promptType) async {
    try {
      return await _subscriptionService.getUpgradePrompt(promptType);
    } catch (e) {
      debugPrint('Error getting upgrade prompt: $e');
      rethrow;
    }
  }

  /// Grant premium access (for testing)
  Future<void> grantPremiumAccess({int durationDays = 30}) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _subscriptionService.grantPremiumAccess(
        token,
        durationDays: durationDays,
      );

      // Refresh subscription status
      await loadSubscriptionStatus();
    } catch (e) {
      debugPrint('Error granting premium access: $e');
      rethrow;
    }
  }

  /// Revoke premium access (for testing)
  Future<void> revokePremiumAccess() async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await _subscriptionService.revokePremiumAccess(token);

      // Refresh subscription status
      await loadSubscriptionStatus();
    } catch (e) {
      debugPrint('Error revoking premium access: $e');
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    if (state.hasError) {
      state = const SubscriptionState.initial();
    }
  }
}

// Providers
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return SubscriptionNotifier(subscriptionService, authService);
});

// Convenience providers
final isPremiumProvider = Provider<bool>((ref) {
  final subscriptionState = ref.watch(subscriptionProvider);
  return subscriptionState.isPremium;
});

final subscriptionFeaturesProvider = Provider<SubscriptionFeatures>((ref) {
  final subscriptionState = ref.watch(subscriptionProvider);
  return subscriptionState.features;
});

final subscriptionTierProvider = Provider<SubscriptionTier>((ref) {
  final subscriptionState = ref.watch(subscriptionProvider);
  return subscriptionState.status?.subscription.tier ?? SubscriptionTier.free;
});
