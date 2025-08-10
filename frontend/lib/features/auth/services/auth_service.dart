import 'dart:async';
import 'package:flutter/foundation.dart';

// Mock User class to replace Firebase User
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });
}

// Mock UserCredential class
class MockUserCredential {
  final MockUser user;

  MockUserCredential({required this.user});
}

class AuthService {
  final StreamController<MockUser?> _authStateController =
      StreamController<MockUser?>.broadcast();
  MockUser? _currentUser;

  // Stream of auth state changes
  Stream<MockUser?> get authStateChanges => _authStateController.stream;

  // Current user
  MockUser? get currentUser => _currentUser;

  // Sign in with email and password
  Future<MockUserCredential> signInWithEmail(
      String email, String password) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Mock validation
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      if (!email.contains('@')) {
        throw Exception('Invalid email address');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Create mock user
      final user = MockUser(
        uid: 'mock_${email.hashCode}',
        email: email,
        displayName: email.split('@')[0],
      );

      _currentUser = user;
      _authStateController.add(user);

      return MockUserCredential(user: user);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign up with email and password
  Future<MockUserCredential> signUpWithEmail(
      String email, String password) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Mock validation
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      if (!email.contains('@')) {
        throw Exception('Invalid email address');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Create mock user
      final user = MockUser(
        uid: 'mock_${email.hashCode}',
        email: email,
        displayName: email.split('@')[0],
      );

      _currentUser = user;
      _authStateController.add(user);

      return MockUserCredential(user: user);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign in with Google
  Future<MockUserCredential> signInWithGoogle() async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Create mock Google user
      final user = MockUser(
        uid: 'google_mock_user',
        email: 'user@gmail.com',
        displayName: 'Google User',
        photoURL: 'https://via.placeholder.com/150',
      );

      _currentUser = user;
      _authStateController.add(user);

      return MockUserCredential(user: user);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  // Sign in with Apple (iOS only)
  Future<MockUserCredential> signInWithApple() async {
    if (kIsWeb) {
      throw Exception('Apple sign in is not available on web');
    }

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Create mock Apple user
      final user = MockUser(
        uid: 'apple_mock_user',
        email: 'user@privaterelay.appleid.com',
        displayName: 'Apple User',
      );

      _currentUser = user;
      _authStateController.add(user);

      return MockUserCredential(user: user);
    } catch (e) {
      throw Exception('Apple sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Invalid email address');
    }

    // Mock success - in real app this would send an email
  }

  // Get mock ID token for API calls
  Future<String?> getIdToken() async {
    final user = currentUser;
    if (user != null) {
      return 'mock_token_${user.uid}';
    }
    return null;
  }

  // Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
