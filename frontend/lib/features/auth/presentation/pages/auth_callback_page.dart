import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../providers/auth_provider.dart';

class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  Timer? _timeoutTimer;
  bool _isTimedOut = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _isTimedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (_, next) {
      if (next.isAuthenticated && mounted) {
        _timeoutTimer?.cancel();
        context.go('/home');
      }
    });

    if (!_isTimedOut && (authState.isLoading || authState.isAuthenticated)) {
      return const Scaffold(
        body: StateView.loading(
          title: 'Completing sign-in',
          subtitle: 'Waiting for the authentication callback...',
        ),
      );
    }

    return Scaffold(
      body: StateView.error(
        title: 'Authentication did not complete',
        subtitle: authState.error ??
            'The callback took too long. Try signing in again.',
        onRetry: () => context.go('/login'),
        actionLabel: 'Back to login',
      ),
    );
  }
}
