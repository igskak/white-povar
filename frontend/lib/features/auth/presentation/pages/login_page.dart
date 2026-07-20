import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../models/auth_state.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { signIn, signUp, reset }

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  _LoginMode _mode = _LoginMode.signIn;
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

  bool get _isReset => _mode == _LoginMode.reset;
  bool get _isSignUp => _mode == _LoginMode.signUp;

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

  void _setMode(_LoginMode mode) {
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

    final form = _LoginForm(
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
                        child: _LoginHero(brand: brand, compact: false),
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
                            child: _LoginHero(brand: brand, compact: true),
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

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.brand, required this.compact});

  final BrandDetails brand;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: compact ? 172 : double.infinity,
        child: ClipRRect(
          borderRadius: compact ? AppRadius.lg : BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BrandHero(brand: brand, role: 'login'),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x3316130F), Color(0xFF16130F)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.brandName,
    required this.loginTitle,
    required this.avatar,
    required this.mode,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.resetSent,
    required this.verificationPending,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onModeChanged,
    required this.onProviderPressed,
    required this.onGuestPressed,
  });

  final String brandName;
  final String loginTitle;
  final Widget avatar;
  final _LoginMode mode;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool resetSent;
  final bool verificationPending;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final ValueChanged<_LoginMode> onModeChanged;
  final ValueChanged<String> onProviderPressed;
  final VoidCallback onGuestPressed;

  bool get isReset => mode == _LoginMode.reset;
  bool get isSignUp => mode == _LoginMode.signUp;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final foreground = semantic.textPrimary;
    final muted = semantic.textSecondary;
    final field = semantic.surface;
    final accent = Theme.of(context).colorScheme.primary;
    final form = Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) _AuthBanner(message: error!, error: true),
            if (error != null) const SizedBox(height: 12),
            if (verificationPending) ...[
              const _AuthBanner(
                message:
                    'Перевірте пошту й підтвердьте email, щоб завершити створення акаунта.',
                error: false,
              ),
              const SizedBox(height: 12),
            ],
            if (isReset) ...[
              Row(
                children: [
                  IconButton(
                    onPressed: isLoading
                        ? null
                        : () => onModeChanged(_LoginMode.signIn),
                    tooltip: 'Назад до входу',
                    icon: const Icon(Icons.arrow_back),
                    color: foreground,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Відновлення пароля',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: foreground)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                  'Введіть email — надішлемо лист із посиланням для зміни пароля.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: muted)),
              const SizedBox(height: 16),
            ] else ...[
              Center(child: avatar),
              const SizedBox(height: 8),
              Text(brandName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8)),
              const SizedBox(height: 6),
              Text(isSignUp ? 'Створіть свій акаунт' : loginTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: foreground)),
              const SizedBox(height: 18),
            ],
            _darkField(
              controller: emailController,
              focusNode: emailFocus,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction:
                  isReset ? TextInputAction.done : TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onSubmitted: isReset
                  ? (_) => onSubmit()
                  : (_) => passwordFocus.requestFocus(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введіть email';
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(value.trim())) {
                  return 'Схоже, в адресі немає «@» — перевірте написання';
                }
                return null;
              },
              field: field,
              foreground: foreground,
              muted: muted,
              border: semantic.surfaceStrong,
              focus: accent,
            ),
            if (!isReset) ...[
              const SizedBox(height: 12),
              _darkField(
                controller: passwordController,
                focusNode: passwordFocus,
                label: 'Пароль',
                icon: Icons.lock_outline,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  isSignUp ? AutofillHints.newPassword : AutofillHints.password
                ],
                onSubmitted: (_) => onSubmit(),
                suffix: IconButton(
                  onPressed: onTogglePassword,
                  tooltip:
                      obscurePassword ? 'Показати пароль' : 'Сховати пароль',
                  color: muted,
                  icon: Icon(obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введіть пароль';
                  if (isSignUp && value.length < 8) return 'Мінімум 8 символів';
                  return null;
                },
                field: field,
                foreground: foreground,
                muted: muted,
                border: semantic.surfaceStrong,
                focus: accent,
              ),
              const SizedBox(height: 4),
              if (isSignUp)
                Text('Мінімум 8 символів',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted))
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                      label: 'Забули пароль?',
                      variant: AppButtonVariant.text,
                      onPressed: isLoading
                          ? null
                          : () => onModeChanged(_LoginMode.reset)),
                ),
            ],
            const SizedBox(height: 12),
            AppButton(
              label: isReset
                  ? 'Надіслати посилання'
                  : isSignUp
                      ? 'Створити акаунт'
                      : 'Увійти',
              expand: true,
              isLoading: isLoading,
              onPressed: isLoading ? null : onSubmit,
            ),
            if (isReset && resetSent) ...[
              const SizedBox(height: 12),
              const _AuthBanner(
                  message:
                      'Якщо акаунт з таким email існує, ми надіслали лист із посиланням для зміни пароля.',
                  error: false),
            ],
            if (!isReset) ...[
              const SizedBox(height: 12),
              Center(
                  child: AppButton(
                      label: isSignUp
                          ? 'У мене вже є акаунт'
                          : 'Створити новий акаунт',
                      variant: AppButtonVariant.text,
                      onPressed: isLoading
                          ? null
                          : () => onModeChanged(isSignUp
                              ? _LoginMode.signIn
                              : _LoginMode.signUp))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Divider(color: semantic.surfaceStrong)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('АБО',
                        style: TextStyle(color: muted, fontSize: 11))),
                Expanded(child: Divider(color: semantic.surfaceStrong))
              ]),
              const SizedBox(height: 12),
              if (AppConfig.googleOAuthEnabled)
                AppButton(
                    label: 'Продовжити з Google',
                    icon: Icons.g_mobiledata_rounded,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed:
                        isLoading ? null : () => onProviderPressed('Google')),
              if (!kIsWeb &&
                  defaultTargetPlatform != TargetPlatform.android) ...[
                const SizedBox(height: 8),
                AppButton(
                    label: 'Продовжити з Apple',
                    icon: Icons.apple_rounded,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed:
                        isLoading ? null : () => onProviderPressed('Apple')),
              ],
            ],
            const SizedBox(height: 12),
            Center(
                child: AppButton(
                    label: 'Продовжити як гість',
                    variant: AppButtonVariant.text,
                    onPressed: isLoading ? null : onGuestPressed)),
          ],
        ),
      ),
    );
    return DecoratedBox(
      decoration:
          BoxDecoration(color: semantic.background, borderRadius: AppRadius.lg),
      child: Padding(padding: const EdgeInsets.all(24), child: form),
    );
  }

  Widget _darkField(
          {required TextEditingController controller,
          required FocusNode focusNode,
          required String label,
          required IconData icon,
          required Color field,
          required Color foreground,
          required Color muted,
          required Color border,
          required Color focus,
          TextInputType? keyboardType,
          TextInputAction? textInputAction,
          Iterable<String>? autofillHints,
          bool obscureText = false,
          Widget? suffix,
          ValueChanged<String>? onSubmitted,
          FormFieldValidator<String>? validator}) =>
      Theme(
        data: ThemeData.dark().copyWith(
            inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: field,
                labelStyle: TextStyle(color: muted),
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
                enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide(color: focus, width: 1.5)))),
        child: AppTextField(
            controller: controller,
            focusNode: focusNode,
            label: label,
            prefixIcon: Icon(icon, color: muted),
            suffixIcon: suffix,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            onSubmitted: onSubmitted,
            validator: validator),
      );
}

class _AuthBanner extends StatelessWidget {
  const _AuthBanner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Builder(builder: (context) {
          final semantic = context.semantic;
          final tone = error ? semantic.error : semantic.warning;
          return DecoratedBox(
            decoration: BoxDecoration(
                color: Color.alphaBlend(
                    tone.withOpacity(.16), semantic.background),
                border: Border.all(color: tone.withOpacity(.55)),
                borderRadius: AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                      error
                          ? Icons.error_outline
                          : Icons.mark_email_read_outlined,
                      color: tone),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(message,
                          style: TextStyle(
                              color: semantic.textPrimary, height: 1.35))),
                ],
              ),
            ),
          );
        }),
      );
}
