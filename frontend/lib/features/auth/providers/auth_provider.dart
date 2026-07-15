import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_state.dart';
import '../services/auth_service.dart';
import '../../recipes/services/cooking_progress_store.dart';
import '../../collections/services/collection_resume_store.dart';

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier(this._authService) : super(const AppAuthState.loading()) {
    _authService!.initialize();

    final existingUser = _authService.currentUser;
    if (existingUser != null) {
      state = AppAuthState.authenticated(existingUser);
    } else {
      state = const AppAuthState.unauthenticated();
    }

    _subscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        state = AppAuthState.authenticated(user);
      } else {
        state = const AppAuthState.unauthenticated();
      }
    });
  }

  /// Keeps login presentation tests independent of the Supabase singleton.
  AuthNotifier.testing([
    super.initial = const AppAuthState.unauthenticated(),
  ]) : _authService = null;

  final AuthService? _authService;
  StreamSubscription<User?>? _subscription;
  static const Duration _oauthCallbackTimeout = Duration(seconds: 45);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      await _authService!.signInWithEmail(email, password);
      if (_authService.currentUser == null) {
        state = const AppAuthState.unauthenticated();
      }
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      final response = await _authService!.signUpWithEmail(email, password);
      if (response.session == null && response.user != null) {
        state = const AppAuthState.verificationPending();
        return;
      }
      if (_authService.currentUser == null) {
        state = const AppAuthState.unauthenticated();
      }
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AppAuthState.loading();
    try {
      if (!await _authService!.signInWithGoogle()) {
        state = const AppAuthState.unauthenticated();
        return;
      }
      await _waitForOAuthCallback();
    } catch (e) {
      state = _isUserCancelledOAuth(e)
          ? const AppAuthState.unauthenticated()
          : AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = const AppAuthState.loading();
    try {
      if (!await _authService!.signInWithApple()) {
        state = const AppAuthState.unauthenticated();
        return;
      }
      await _waitForOAuthCallback();
    } catch (e) {
      state = _isUserCancelledOAuth(e)
          ? const AppAuthState.unauthenticated()
          : AppAuthState.error(e.toString());
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AppAuthState.loading();
    try {
      await _authService!.sendPasswordResetEmail(email);
      state = const AppAuthState.unauthenticated();
    } catch (e) {
      // The reset screen intentionally presents the same sent state on a
      // failed request, so it cannot disclose whether an account exists.
      state = const AppAuthState.unauthenticated();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService!.signOut();
      await CookingProgressStore().clearPrivateData();
      await CollectionResumeStore().clearPrivateData();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> linkIdentity(OAuthProvider provider) async {
    state = const AppAuthState.loading();
    try {
      if (!await _authService!.linkIdentity(provider)) {
        final user = _authService.currentUser;
        state = user == null
            ? const AppAuthState.unauthenticated()
            : AppAuthState.authenticated(user);
      }
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> deleteAccount() async {
    state = const AppAuthState.loading();
    try {
      await _authService!.deleteAccount();
      await CookingProgressStore().clearPrivateData();
      state = const AppAuthState.unauthenticated();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  void clearError() {
    if (state.hasError) {
      final user = _authService?.currentUser;
      state = user == null
          ? const AppAuthState.unauthenticated()
          : AppAuthState.authenticated(user);
    }
  }

  Future<void> _waitForOAuthCallback() async {
    if (_authService!.currentUser != null) {
      state = AppAuthState.authenticated(_authService.currentUser!);
      return;
    }

    final user = await _authService.authStateChanges
        .where((user) => user != null)
        .cast<User>()
        .first
        .timeout(_oauthCallbackTimeout, onTimeout: () {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        return currentUser;
      }
      throw TimeoutException(
        'Не вдалося завершити вхід. Перевірте Google redirect URL і спробуйте ще раз.',
      );
    });

    state = AppAuthState.authenticated(user);
  }

  static bool _isUserCancelledOAuth(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('cancelled') ||
        message.contains('canceled') ||
        message.contains('user_cancelled');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});
