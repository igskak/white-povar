import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/auth/services/auth_diagnostics.dart';

String _jwt(Map<String, Object?> payload) {
  String b64(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.c2ln';
}

void main() {
  group('decodeJwtTimingClaims', () {
    test('extracts iat, exp and session_id', () {
      final jwt = _jwt({
        'iat': 1000,
        'exp': 4600,
        'session_id': 'abc-123',
        'email': 'secret@example.com',
      });

      final claims = decodeJwtTimingClaims(jwt);

      expect(claims['iat'], 1000);
      expect(claims['exp'], 4600);
      expect(claims['session_id'], 'abc-123');
      expect(claims.containsKey('email'), isFalse);
    });

    test('returns empty map for malformed tokens', () {
      expect(decodeJwtTimingClaims('not-a-jwt'), isEmpty);
      expect(decodeJwtTimingClaims('a.###.c'), isEmpty);
    });
  });

  group('describeAuthSession', () {
    test('reports no session', () {
      expect(describeAuthSession(null), 'session=none');
    });

    test('reports expiry, skew and session id without token material', () {
      final now = DateTime.fromMillisecondsSinceEpoch(2000 * 1000);
      final accessToken = _jwt({
        'iat': 1990,
        'exp': 2030,
        'session_id': 'sess-1',
      });
      final session = Session.fromJson({
        'access_token': accessToken,
        'token_type': 'bearer',
        'expires_in': 30,
        'refresh_token': 'rt-1',
        'user': {
          'id': 'user-1',
          'aud': 'authenticated',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-07-01T00:00:00Z',
        },
      });

      final described = describeAuthSession(session, now: now);

      expect(described, contains('expiresInSec: 30'));
      expect(described, contains('clockSkewSec: -10'));
      expect(described, contains('sessionId: sess-1'));
      expect(described, contains('hasRefreshToken: true'));
      expect(described.contains(accessToken), isFalse);
      expect(described.contains('rt-1'), isFalse);
    });
  });

  group('scrubJwtTokens', () {
    test('masks JWT-shaped substrings inside error text', () {
      final jwt = _jwt({'exp': 1});
      expect(
        scrubJwtTokens('AuthApiException(message: bad, token: $jwt)'),
        'AuthApiException(message: bad, token: <jwt>)',
      );
    });

    test('keeps ordinary text untouched', () {
      expect(scrubJwtTokens('invalid refresh token'), 'invalid refresh token');
    });
  });
}
