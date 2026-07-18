import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Token-free auth lifecycle telemetry for the production session-loss P1.
///
/// Logs only lifecycle facts to the browser console: event name, sign-out
/// reason, whether the event came from another tab, access-token expiry
/// timing and the client/server clock delta. One owner-run login in the
/// production browser is enough to tell apart the candidate causes
/// (short-lived JWT, rejected refresh, clock skew, cross-tab sign-out)
/// without ever exposing credentials or token material.
class AuthDiagnostics {
  AuthDiagnostics._();

  static bool _started = false;

  static void start(GoTrueClient auth) {
    if (_started) return;
    _started = true;
    _log('start ${describeAuthSession(auth.currentSession)}');
    auth.onAuthStateChange.listen(
      (state) {
        final reason = state.signOutReason == null
            ? ''
            : ' signOutReason=${state.signOutReason!.name}';
        final origin = state.fromBroadcast ? ' fromBroadcast=true' : '';
        _log('event=${state.event.name}$reason$origin '
            '${describeAuthSession(state.session)}');
      },
      onError: (Object error, StackTrace _) {
        _log('authStreamError ${scrubJwtTokens(error.toString())}');
      },
    );
  }

  static void _log(String message) {
    // debugPrint survives release web builds, so the trail lands in the
    // production browser console where the owner can copy it verbatim.
    debugPrint('[auth-diag] $message');
  }
}

/// Extracts non-sensitive claims from a JWT payload: issue/expiry times and
/// the server-side session id. Returns an empty map for malformed input.
Map<String, Object?> decodeJwtTimingClaims(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return const {};
  try {
    final payload = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return const {};
    return {
      'iat': payload['iat'],
      'exp': payload['exp'],
      'session_id': payload['session_id'],
    };
  } on FormatException {
    return const {};
  }
}

/// Renders session timing facts for the diagnostic log.
///
/// `expiresInSec` under ~30 right after login means the client will refresh
/// immediately (gotrue refreshes when less than three 10s ticks remain), so
/// a rejected refresh logs the user out within seconds. `clockSkewSec` is
/// roughly `server issued-at minus client now`: strongly negative values
/// mean the client clock runs ahead and fresh tokens already look expired.
String describeAuthSession(Session? session, {DateTime? now}) {
  if (session == null) return 'session=none';
  final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final claims = decodeJwtTimingClaims(session.accessToken);
  final exp = claims['exp'] as int? ?? session.expiresAt;
  final iat = claims['iat'] as int?;
  return 'session={expiresInSec: ${exp == null ? 'unknown' : exp - nowSec}, '
      'clockSkewSec: ${iat == null ? 'unknown' : iat - nowSec}, '
      'sessionId: ${claims['session_id'] ?? 'unknown'}, '
      'hasRefreshToken: ${session.refreshToken != null}}';
}

/// Replaces JWT-shaped substrings so error text can be logged safely.
String scrubJwtTokens(String text) => text.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      '<jwt>',
    );
