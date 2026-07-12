import '../../features/auth/models/auth_state.dart';

class RouteGuards {
  static const String _loginPath = '/login';
  static const String _authCallbackPath = '/auth/callback';
  static const String _homePath = '/home';

  static String? authRedirect({
    required AppAuthState authState,
    required String location,
  }) {
    final isAuthRoute =
        location == _loginPath || location.startsWith(_authCallbackPath);

    if (authState.isLoading) {
      return null;
    }

    if (authState.isAuthenticated && isAuthRoute) {
      return _homePath;
    }

    return null;
  }
}
