import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/features/auth/models/auth_state.dart';

void main() {
  const user = User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: null,
    aud: 'authenticated',
    createdAt: '2026-07-15T00:00:00Z',
  );

  group('AppAuthState.error', () {
    test('without a user presents an unauthenticated failure', () {
      const state = AppAuthState.error('Sign in failed');

      expect(state.hasError, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    test('with a live session keeps the authenticated presentation', () {
      // A failed sign-out must not flip the UI to guest while the persisted
      // session survives — that produced the "logged back in after page
      // reload" loop.
      const state = AppAuthState.error('Sign out failed', user: user);

      expect(state.hasError, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(state.user, same(user));
    });
  });
}
