import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  StreamSubscription<AuthState>? _authStateSubscription;
  User? _currentUser;
  bool _isInitialized = false;

  Stream<User?> get authStateChanges => _authStateController.stream;

  User? get currentUser => _currentUser ?? _supabase.auth.currentUser;

  void initialize() {
    if (_isInitialized) {
      _authStateController.add(currentUser);
      return;
    }

    _isInitialized = true;
    _currentUser = _supabase.auth.currentUser;
    _authStateController.add(_currentUser);

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      _authStateController.add(_currentUser);
    });
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = response.user;
        _authStateController.add(response.user);
        await _syncUserWithBackend(response.user!);
      }

      return response;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? AppConfig.webAuthCallbackUrl : null,
      );

      if (response.user != null) {
        _currentUser = response.user;
        _authStateController.add(response.user);
        await _syncUserWithBackend(response.user!);
      }

      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final didOpen = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? AppConfig.webAuthCallbackUrl
            : 'io.supabase.cookingapp://login-callback',
      );
      if (!didOpen) {
        throw Exception('Google sign in was not opened');
      }
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<void> signInWithApple() async {
    if (kIsWeb) {
      throw Exception('Apple sign in is not available on web');
    }

    try {
      final didOpen = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.cookingapp://login-callback',
      );
      if (!didOpen) {
        throw Exception('Apple sign in was not opened');
      }
    } catch (e) {
      throw Exception('Apple sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _authStateController.add(null);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? AppConfig.webAuthCallbackUrl : null,
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<String?> getIdToken() async {
    try {
      return _supabase.auth.currentSession?.accessToken;
    } catch (e) {
      debugPrint('AuthService token error: $e');
      return null;
    }
  }

  Future<void> _syncUserWithBackend(User user) async {
    try {
      final token = await getIdToken();
      if (token == null) {
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.authEndpoint}/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': user.id,
          'email': user.email,
          'display_name':
              user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
          'avatar_url': user.userMetadata?['avatar_url'],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('AuthService sync warning: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AuthService sync warning: $e');
    }
  }

  void dispose() {
    _authStateSubscription?.cancel();
    _authStateController.close();
  }
}
