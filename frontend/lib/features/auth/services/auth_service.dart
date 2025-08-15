import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();
  User? _currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _authStateController.stream;

  // Current user
  User? get currentUser => _currentUser ?? _supabase.auth.currentUser;

  // Initialize auth state
  void initialize() {
    _currentUser = _supabase.auth.currentUser;
    _authStateController.add(_currentUser);
    
    // Listen to Supabase auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      _authStateController.add(_currentUser);
    });
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        _currentUser = response.user;
        _authStateController.add(response.user);
        
        // Sync with backend
        await _syncUserWithBackend(response.user!);
      }
      
      return response;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        _currentUser = response.user;
        _authStateController.add(response.user);
        
        // Sync with backend
        await _syncUserWithBackend(response.user!);
      }
      
      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.cookingapp://login-callback',
      );
      
      // For OAuth, we need to wait for the redirect to complete
      // The user will be updated via the auth state listener
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  // Sign in with Apple (iOS only)
  Future<void> signInWithApple() async {
    if (kIsWeb) {
      throw Exception('Apple sign in is not available on web');
    }

    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.cookingapp://login-callback',
      );
      
      // For OAuth, we need to wait for the redirect to complete
      // The user will be updated via the auth state listener
    } catch (e) {
      throw Exception('Apple sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _authStateController.add(null);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Get ID token for API calls
  Future<String?> getIdToken() async {
    try {
      final session = _supabase.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      return null;
    }
  }

  // Sync user with backend
  Future<void> _syncUserWithBackend(User user) async {
    try {
      final token = await getIdToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.authEndpoint}/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': user.id,
          'email': user.email,
          'display_name': user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
          'avatar_url': user.userMetadata?['avatar_url'],
        }),
      );

      if (response.statusCode != 200) {
        // Log warning for debugging
        debugPrint('Warning: Failed to sync user with backend: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('Warning: Failed to sync user with backend: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
