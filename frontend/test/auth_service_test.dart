import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('resolveAuthUser', () {
    final user = User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2026).toIso8601String(),
    );

    test('retains the active client user for a sessionless lifecycle event',
        () {
      expect(
        resolveAuthUser(
          event: AuthChangeEvent.initialSession,
          sessionUser: null,
          currentUser: user,
        ),
        same(user),
      );
    });

    test('uses the user carried by an authenticated event', () {
      expect(
        resolveAuthUser(
          event: AuthChangeEvent.signedIn,
          sessionUser: user,
          currentUser: null,
        ),
        same(user),
      );
    });

    test('clears the user only for an explicit sign out', () {
      expect(
        resolveAuthUser(
          event: AuthChangeEvent.signedOut,
          sessionUser: null,
          currentUser: user,
        ),
        isNull,
      );
    });
  });
}
