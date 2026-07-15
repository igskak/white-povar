import '../../features/auth/models/auth_state.dart';
import 'route_models.dart';

class RouteGuards {
  static const _loginPath = '/login';
  static const _authCallbackPath = '/auth/callback';
  static const _homePath = '/home';

  static String? authRedirect({
    required AppAuthState authState,
    required Uri uri,
  }) {
    final path = uri.path;
    final isAuthRoute =
        path == _loginPath || path.startsWith(_authCallbackPath);

    if (authState.isLoading) return null;

    if (authState.isAuthenticated && isAuthRoute) {
      return OfferRouteLocation.safeReturnPath(
              uri.queryParameters['returnTo']) ??
          _homePath;
    }

    if (!authState.isAuthenticated && _requiresAuthentication(path)) {
      return Uri(
        path: _loginPath,
        queryParameters: {'returnTo': uri.toString()},
      ).toString();
    }

    return null;
  }

  static bool _requiresAuthentication(String path) =>
      path == '/settings' ||
      path == '/preferences' ||
      path.startsWith('/offers/');
}
