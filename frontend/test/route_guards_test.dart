import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/route_guards.dart';
import 'package:frontend/features/auth/models/auth_state.dart';

void main() {
  group('RouteGuards', () {
    test('guest users can browse public recipe routes', () {
      const authState = AppAuthState.unauthenticated();

      expect(
        RouteGuards.authRedirect(
          authState: authState,
          location: '/home',
        ),
        isNull,
      );
      expect(
        RouteGuards.authRedirect(
          authState: authState,
          location: '/recipes/recipe-1',
        ),
        isNull,
      );
    });
  });
}
