import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_state.dart';
import '../services/auth_service.dart';

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier(this._authService) : super(const AppAuthState.loading()) {
    _authService.initialize();

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

  final AuthService _authService;
  StreamSubscription<User?>? _subscription;
  static const Duration _oauthCallbackTimeout = Duration(seconds: 45);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      await _authService.signUpWithEmail(email, password);
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithGoogle();
      await _waitForOAuthCallback();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithApple();
      await _waitForOAuthCallback();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  void clearError() {
    if (state.hasError) {
      final user = _authService.currentUser;
      state = user == null
          ? const AppAuthState.unauthenticated()
          : AppAuthState.authenticated(user);
    }
  }

  Future<void> _waitForOAuthCallback() async {
    if (_authService.currentUser != null) {
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
