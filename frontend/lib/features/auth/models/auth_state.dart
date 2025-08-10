import 'package:equatable/equatable.dart';
import '../services/auth_service.dart';

class AuthState extends Equatable {
  final bool isLoading;
  final bool isAuthenticated;
  final MockUser? user;
  final String? error;

  const AuthState._({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.error,
  });

  const AuthState.initial()
      : this._(
          isLoading: false,
          isAuthenticated: false,
        );

  const AuthState.loading()
      : this._(
          isLoading: true,
          isAuthenticated: false,
        );

  const AuthState.authenticated(MockUser user)
      : this._(
          isLoading: false,
          isAuthenticated: true,
          user: user,
        );

  const AuthState.unauthenticated()
      : this._(
          isLoading: false,
          isAuthenticated: false,
        );

  const AuthState.error(String error)
      : this._(
          isLoading: false,
          isAuthenticated: false,
          error: error,
        );

  bool get hasError => error != null;

  @override
  List<Object?> get props => [isLoading, isAuthenticated, user, error];
}
