import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthState extends Equatable {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final String? error;

  const AppAuthState._({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.error,
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

  const AppAuthState.error(String error)
      : this._(
          isLoading: false,
          isAuthenticated: false,
          error: error,
        );

  bool get hasError => error != null;

  @override
  List<Object?> get props => [isLoading, isAuthenticated, user, error];
}
