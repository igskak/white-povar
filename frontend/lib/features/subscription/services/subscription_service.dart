import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final String baseUrl = '${AppConfig.apiBaseUrl}/api/v1/subscription';

  /// Get current user's subscription status
  Future<SubscriptionStatusResponse> getSubscriptionStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SubscriptionStatusResponse.fromJson(data);
      } else {
        throw Exception(
            'Failed to get subscription status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      rethrow;
    }
  }

  /// Check if user has premium access for a specific feature
  Future<PremiumAccessCheck> checkPremiumAccess(
    String token, {
    String? feature,
  }) async {
    try {
      final uri = feature != null
          ? Uri.parse('$baseUrl/check-access?feature=$feature')
          : Uri.parse('$baseUrl/check-access');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PremiumAccessCheck.fromJson(data);
      } else {
        throw Exception(
            'Failed to check premium access: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking premium access: $e');
      rethrow;
    }
  }

  /// Get available features for current user
  Future<Map<String, dynamic>> getAvailableFeatures(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/features'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to get available features: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting available features: $e');
      rethrow;
    }
  }

  /// Get upgrade prompt for a specific feature type
  Future<UpgradePrompt> getUpgradePrompt(String promptType) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/upgrade-prompts/$promptType'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpgradePrompt.fromJson(data);
      } else {
        throw Exception('Failed to get upgrade prompt: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting upgrade prompt: $e');
      rethrow;
    }
  }

  /// Get subscription tiers information
  Future<Map<String, dynamic>> getSubscriptionTiers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tiers'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to get subscription tiers: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting subscription tiers: $e');
      rethrow;
    }
  }

  /// Grant premium access (for testing)
  Future<void> grantPremiumAccess(String token, {int durationDays = 30}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/grant-premium?duration_days=$durationDays'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to grant premium access: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error granting premium access: $e');
      rethrow;
    }
  }

  /// Revoke premium access (for testing)
  Future<void> revokePremiumAccess(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/revoke-premium'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to revoke premium access: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error revoking premium access: $e');
      rethrow;
    }
  }

  /// Update subscription (for admin/testing)
  Future<void> updateSubscription(
    String token, {
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? endDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (tier != null) body['tier'] = tier.name;
      if (status != null) body['status'] = status.name;
      if (endDate != null) body['end_date'] = endDate.toIso8601String();

      final response = await http.put(
        Uri.parse('$baseUrl/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update subscription: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating subscription: $e');
      rethrow;
    }
  }
}
