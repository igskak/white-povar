import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_state.dart';
import '../services/auth_service.dart';

class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AppAuthState.initial()) {
    // Initialize auth service
    _authService.initialize();
    
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) {
      if (user != null) {
        state = AppAuthState.authenticated(user);
      } else {
        state = const AppAuthState.unauthenticated();
      }
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithEmail(email, password);
      // State will be updated by the auth state listener
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      await _authService.signUpWithEmail(email, password);
      // State will be updated by the auth state listener
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithGoogle();
      // State will be updated by the auth state listener
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = const AppAuthState.loading();
    try {
      await _authService.signInWithApple();
      // State will be updated by the auth state listener
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      // State will be updated by the auth state listener
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  void clearError() {
    if (state.hasError) {
      state = const AppAuthState.unauthenticated();
    }
  }
}

// Providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience provider for current user
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});
