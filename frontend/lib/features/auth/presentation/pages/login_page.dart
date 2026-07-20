import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../models/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../widgets/login_scene.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  LoginMode _mode = LoginMode.signIn;
  bool _obscurePassword = true;
  bool _resetSent = false;
  String? _activeProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _isReset => _mode == LoginMode.reset;
  bool get _isSignUp => _mode == LoginMode.signUp;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider.notifier);
    final email = _emailController.text.trim();
    _activeProvider = null;
    if (_isReset) {
      setState(() => _resetSent = true);
      auth.sendPasswordResetEmail(email);
    } else if (_isSignUp) {
      auth.signUpWithEmail(email, _passwordController.text);
    } else {
      auth.signInWithEmail(email, _passwordController.text);
    }
  }

  void _setMode(LoginMode mode) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _mode = mode;
      _resetSent = false;
      _activeProvider = null;
    });
  }

  void _signInWithProvider(String provider) {
    setState(() => _activeProvider = provider);
    final auth = ref.read(authProvider.notifier);
    if (provider == 'Google') {
      auth.signInWithGoogle();
    } else {
      auth.signInWithApple();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(tenantBootstrapProvider).brandConfig.brand;
    final authState = ref.watch(authProvider);
    final width = MediaQuery.sizeOf(context).width;

    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted) {
        final returnTo = OfferRouteLocation.safeReturnPath(
          GoRouterState.of(context).uri.queryParameters['returnTo'],
        );
        context.go(returnTo ?? '/home');
      }
    });

    final form = LoginForm(
      brandName: brand.name,
      loginTitle: brand.voice.loginTitle,
      avatar: BrandAvatar(brand: brand, radius: 36),
      mode: _mode,
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      emailFocus: _emailFocus,
      passwordFocus: _passwordFocus,
      obscurePassword: _obscurePassword,
      resetSent: _resetSent,
      verificationPending: authState.needsEmailVerification,
      isLoading: authState.isLoading,
      error: _visibleError(authState.error),
      onSubmit: _submit,
      onTogglePassword: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onModeChanged: _setMode,
      onProviderPressed: _signInWithProvider,
      onGuestPressed: () => context.go('/home'),
    );

    return ForcedDarkTheme(
      child: Scaffold(
        backgroundColor: SemanticColors.dark.background,
        body: SafeArea(
          child: width >= 1024
              ? Row(
                  key: const ValueKey('desktop-login-split'),
                  children: [
                    Expanded(
                      flex: 46,
                      child: KeyedSubtree(
                        key: const ValueKey('desktop-login-hero'),
                        child: LoginHero(brand: brand, compact: false),
                      ),
                    ),
                    Expanded(
                      flex: 54,
                      child: Center(
                        key: const ValueKey('desktop-login-form'),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: form,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KeyedSubtree(
                            key: const ValueKey('mobile-login-hero'),
                            child: LoginHero(brand: brand, compact: true),
                          ),
                          const SizedBox(height: 16),
                          form,
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String? _visibleError(String? error) {
    if (error == null) return null;
    final value = error.toLowerCase();
    if (_activeProvider != null) {
      if (value.contains('identity') || value.contains('already linked')) {
        return 'Цей email уже пов’язаний з іншим способом входу. Увійдіть через нього, щоб прив’язати $_activeProvider.';
      }
      return 'Не вдалося увійти через $_activeProvider. Спробуйте ще раз або скористайтесь email.';
    }
    if (value.contains('invalid login') ||
        value.contains('invalid credentials')) {
      return 'Email або пароль не підходять.';
    }
    if (value.contains('rate limit') || value.contains('too many')) {
      return 'Забагато спроб, зачекайте хвилину.';
    }
    return 'Не вдалося виконати запит. Перевірте з’єднання та спробуйте ще раз.';
  }
}
