import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/app/router/route_guards.dart';
import 'package:frontend/app/router/route_models.dart';
import 'package:frontend/features/auth/models/auth_state.dart';

void main() {
  group('RouteGuards', () {
    test('guest users can browse public recipe routes', () {
      const authState = AppAuthState.unauthenticated();

      expect(
        RouteGuards.authRedirect(
          authState: authState,
          uri: Uri.parse('/home'),
        ),
        isNull,
      );
      expect(
        RouteGuards.authRedirect(
          authState: authState,
          uri: Uri.parse('/recipes/recipe-1'),
        ),
        isNull,
      );
    });

    test('guest premium offer redirects to login and retains origin', () {
      const authState = AppAuthState.unauthenticated();

      expect(
        RouteGuards.authRedirect(
          authState: authState,
          uri: Uri.parse('/offers/maisternia?returnTo=%2Fcollections%2Fspring'),
        ),
        '/login?returnTo=%2Foffers%2Fmaisternia%3FreturnTo%3D%252Fcollections%252Fspring',
      );
    });

    test('authenticated user returns to safe origin after login', () {
      const signedIn = AppAuthState.authenticated(
        User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: null,
          aud: 'authenticated',
          createdAt: '2026-07-15T00:00:00Z',
        ),
      );
      expect(
        RouteGuards.authRedirect(
          authState: signedIn,
          uri: Uri.parse('/login?returnTo=%2Fsettings'),
        ),
        '/settings',
      );
    });

    test('search, content, collection and offer links retain typed values', () {
      final search = SearchRouteLocation.fromUri(
        Uri.parse('/search?q=борщ&tag=maisternia-oleksandra'),
      );
      final offer = OfferRouteLocation.fromUri(
        Uri.parse('/offers/maisternia?returnTo=%2Fcollections%2Fspring'),
      );

      expect(search.query, 'борщ');
      expect(search.tag, 'maisternia-oleksandra');
      expect(search.toUri().toString(),
          '/search?q=%D0%B1%D0%BE%D1%80%D1%89&tag=maisternia-oleksandra');
      expect(offer.offerId, 'maisternia');
      expect(offer.returnTo, '/collections/spring');
      expect(OfferRouteLocation.safeReturnPath('https://other.test'), isNull);
      expect(OfferRouteLocation.safeReturnPath('/login'), isNull);
    });
  });
}
