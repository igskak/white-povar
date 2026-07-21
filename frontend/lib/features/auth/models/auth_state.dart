import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthState extends Equatable {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final String? error;
  final bool needsEmailVerification;

  const AppAuthState._({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.error,
    this.needsEmailVerification = false,
  });

  const AppAuthState.initial()
      : this._(
          isLoading: false,
          isAuthenticated: false,
        );

  const AppAuthState.loading()
      : this._(
          isLoading: true,
          isAuthenticated: false,
        );

  const AppAuthState.authenticated(User user)
      : this._(
          isLoading: false,
          isAuthenticated: true,
          user: user,
        );

  const AppAuthState.unauthenticated()
      : this._(
          isLoading: false,
          isAuthenticated: false,
        );

  const AppAuthState.verificationPending()
      : this._(
          isLoading: false,
          isAuthenticated: false,
          needsEmailVerification: true,
        );

  /// A failed action must not pretend the session is gone: pass [user] when
  /// the client still holds a live session so guarded UI stays signed in.
  const AppAuthState.error(String error, {User? user})
      : this._(
          isLoading: false,
          isAuthenticated: user != null,
          user: user,
          error: error,
        );

  bool get hasError => error != null;

  @override
  List<Object?> get props =>
      [isLoading, isAuthenticated, user, error, needsEmailVerification];
}
