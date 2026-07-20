import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/brand_theme.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens/app_tokens.dart';
import '../../../core/branding/brand_assets.dart';
import '../../../core/branding/brand_config.dart';
import '../../../core/branding/brand_providers.dart';
import '../../../core/widgets/design_system.dart';
import '../../collections/providers/collection_provider.dart';
import '../purchase_adapter.dart';
import '../paywall_provider.dart';
import '../widgets/paywall_scene.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(paywallProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(paywallProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final isDialog = width >= 600;
    final child = _PaywallCard(snapshot: snapshot, onClose: _close);
    if (isDesktop) {
      return ForcedDarkTheme(
        child: _DesktopPaywall(
          brand: ref.watch(tenantBootstrapProvider).brandConfig.brand,
          onClose: _close,
          child: child,
        ),
      );
    }
    return ForcedDarkTheme(
      child: Builder(builder: (context) {
        final semantic = context.semantic;
        return Scaffold(
          // >= 600 presents as a centred dialog over a 45% scrim (13f).
          backgroundColor:
              isDialog ? AppColorsV2.ink.withOpacity(.45) : semantic.background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: isDialog
                    ? Material(
                        color: semantic.surface,
                        borderRadius: AppRadius.lg,
                        child: child)
                    : child,
              ),
            ),
          ),
        );
      }),
    );
  }

  void _close() => context.go(widget.returnTo ?? '/profile');
}

class _DesktopPaywall extends StatelessWidget {
  const _DesktopPaywall({
    required this.brand,
    required this.child,
    required this.onClose,
  });

  final BrandDetails brand;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColorsV2.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
                opacity: .35, child: BrandHero(brand: brand, role: 'paywall')),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColorsV2.ink.withOpacity(.70),
                    AppColorsV2.ink.withOpacity(.96),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: AppSpacing.lg,
                    left: AppSpacing.lg,
                    child: AppIconButton(
                      icon: Icons.close,
                      tooltip: 'Закрити',
                      filled: true,
                      onPressed: onClose,
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56),
                        child: Row(
                          children: [
                            Expanded(child: _DesktopPremiumPitch(brand: brand)),
                            const SizedBox(width: 64),
                            SizedBox(width: 400, child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DesktopPremiumPitch extends StatelessWidget {
  const _DesktopPremiumPitch({required this.brand});

  final BrandDetails brand;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColorsV2.premiumGold, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${brand.name} Premium',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColorsV2.onInk,
                  fontFamily: context.brandTheme.displayFontFamily,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Повний доступ до рецептів від шефа, AI-асистента та інструментів приготування.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: context.semantic.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _DesktopBenefit(
              icon: Icons.restaurant_menu_rounded,
              text: 'Усі рецепти від шефа без обмежень'),
          const _DesktopBenefit(
              icon: Icons.auto_awesome_rounded,
              text: 'AI-асистент та розпізнавання продуктів'),
          const _DesktopBenefit(icon: Icons.block_rounded, text: 'Без реклами'),
        ],
      );
}

class _DesktopBenefit extends StatelessWidget {
  const _DesktopBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(children: [
          Icon(icon, color: AppColorsV2.premiumGold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColorsV2.onInk)),
          ),
        ]),
      );
}

class _PaywallCard extends ConsumerWidget {
  const _PaywallCard({required this.snapshot, required this.onClose});

  final PaywallSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(tenantBootstrapProvider).brandConfig.brand;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final purchasing = snapshot.phase == PaywallPhase.purchasing;
    final active = _isEntitled(snapshot.phase);
    final unavailable = snapshot.phase == PaywallPhase.productsUnavailable ||
        snapshot.phase == PaywallPhase.notAllowlisted;
    final selectedId = ref.watch(selectedPurchaseProductProvider) ??
        _recommendedProduct(snapshot.products)?.id;
    final selectedProduct = snapshot.products
        .where((product) => product.id == selectedId)
        .firstOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.background,
        borderRadius:
            MediaQuery.sizeOf(context).width >= 600 ? AppRadius.lg : null,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDesktop)
              Row(children: [
                AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Закрити',
                  onPressed: purchasing ? null : onClose,
                ),
                const Spacer(),
                Text('ПІДПИСКА',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.brandTheme.accentOnDark,
                        letterSpacing: 1.4)),
              ]),
            const SizedBox(height: 10),
            if (active) ...[
              PaywallHeroImage(brand: brand),
              const SizedBox(height: 18),
              _ActivePanel(snapshot: snapshot),
            ] else ...[
              PaywallPitch(brand: brand),
              const SizedBox(height: 14),
              if (snapshot.phase == PaywallPhase.productsLoading)
                const _ProductsLoading()
              else if (unavailable)
                _Unavailable(
                  phase: snapshot.phase,
                  message: snapshot.message,
                  onRetry: () => ref.read(paywallProvider.notifier).load(),
                )
              else
                PaywallPlans(
                  products: snapshot.products,
                  selectedId: selectedId,
                  onSelect: (id) => ref
                      .read(selectedPurchaseProductProvider.notifier)
                      .state = id,
                  busy: purchasing,
                  ctaLabel: kIsWeb
                      ? 'Активувати демо-доступ'
                      : selectedProduct?.trial != null
                          ? 'Спробувати ${selectedProduct!.trial}'
                          : 'Продовжити',
                  footnote: kIsWeb
                      ? 'Кошти не списуються'
                      : selectedProduct?.detail ??
                          'Скасувати можна в налаштуваннях магазину.',
                  onPurchase: purchasing || selectedProduct == null
                      ? null
                      : () async {
                          await ref
                              .read(paywallProvider.notifier)
                              .purchase(selectedProduct);
                          final phase = ref.read(paywallProvider).phase;
                          if (context.mounted &&
                              phase == PaywallPhase.success &&
                              selectedProduct.accessScope ==
                                  PurchaseAccessScope.collection &&
                              selectedProduct.collectionIds.isNotEmpty) {
                            final collectionId =
                                selectedProduct.collectionIds.first;
                            // The collection page may already be in the router
                            // cache with its pre-purchase locked projection.
                            // Re-read the server decision before returning to it.
                            ref.invalidate(
                                collectionDetailProvider(collectionId));
                            context.go(
                              '/collections/$collectionId',
                            );
                          }
                        },
                ),
            ],
            if (_needsMessage(snapshot.phase)) ...[
              const SizedBox(height: 14),
              _StatusMessage(
                  snapshot: snapshot,
                  onRetry: snapshot.phase == PaywallPhase.error ||
                          snapshot.phase == PaywallPhase.billingRetry
                      ? () => ref.read(paywallProvider.notifier).load()
                      : null),
            ],
            const SizedBox(height: 12),
            if (active)
              AppButton(
                  label: 'Керувати підпискою',
                  icon: Icons.open_in_new,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () =>
                      ref.read(paywallProvider.notifier).manageSubscription())
            else if (!unavailable)
              AppButton(
                  label: 'Відновити покупку',
                  variant: AppButtonVariant.text,
                  expand: true,
                  isLoading: purchasing,
                  onPressed: purchasing
                      ? null
                      : () => ref.read(paywallProvider.notifier).restore()),
            const SizedBox(height: 4),
            Text('Умови · Конфіденційність',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: context.semantic.textSecondary)),
          ],
        ),
      ),
    );
  }
}

bool _isEntitled(PaywallPhase phase) =>
    phase == PaywallPhase.active ||
    phase == PaywallPhase.grace ||
    phase == PaywallPhase.billingRetry;

PurchaseProduct? _recommendedProduct(List<PurchaseProduct> products) {
  if (products.isEmpty) return null;
  final annual = products.where((product) {
    final value =
        '${product.id} ${product.title} ${product.badge ?? ''}'.toLowerCase();
    return value.contains('annual') ||
        value.contains('year') ||
        value.contains('річ') ||
        value.contains('вигід');
  });
  return annual.firstOrNull ?? products.first;
}

bool _needsMessage(PaywallPhase phase) =>
    phase == PaywallPhase.success ||
    phase == PaywallPhase.error ||
    phase == PaywallPhase.userCancelled ||
    phase == PaywallPhase.grace ||
    phase == PaywallPhase.billingRetry ||
    phase == PaywallPhase.expired ||
    phase == PaywallPhase.cancelled ||
    phase == PaywallPhase.confirmationPending;

class _ProductsLoading extends StatelessWidget {
  const _ProductsLoading();
  @override
  Widget build(BuildContext context) => const Column(children: [
        AppSkeleton(height: 76),
        SizedBox(height: 8),
        AppSkeleton(height: 76)
      ]);
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.phase,
    required this.onRetry,
    this.message,
  });

  final PaywallPhase phase;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.semantic.surface,
          border: Border.all(color: context.semantic.surfaceStrong),
          borderRadius: AppRadius.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              phase == PaywallPhase.notAllowlisted
                  ? Icons.person_off_outlined
                  : Icons.storefront_outlined,
              color: context.brandTheme.accentOnDark,
              size: 30,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              phase == PaywallPhase.notAllowlisted
                  ? 'Доступ недоступний для акаунта'
                  : 'Каталог тимчасово недоступний',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.semantic.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ??
                  (phase == PaywallPhase.notAllowlisted
                      ? 'Демо-доступ недоступний для цього акаунта.'
                      : 'Не вдалося отримати доступні плани. Спробуйте оновити каталог.'),
              style: TextStyle(color: context.semantic.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Оновити каталог',
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed: onRetry,
            ),
          ],
        ),
      );
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({required this.snapshot});
  final PaywallSnapshot snapshot;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Notice(
            icon: Icons.workspace_premium,
            message: _entitlementLabel(snapshot)),
        const SizedBox(height: 16),
        const PaywallBenefit(
            icon: Icons.check_circle, text: 'Premium-контент відкрито'),
        const PaywallBenefit(
            icon: Icons.check_circle, text: 'AI-поради без лімітів'),
      ]);
}

String _entitlementLabel(PaywallSnapshot snapshot) => switch (snapshot.phase) {
      PaywallPhase.grace => 'Пільговий період активний. Оновіть спосіб оплати.',
      PaywallPhase.billingRetry =>
        'Повторюємо оплату. Premium-доступ поки активний.',
      _ =>
        'Premium активний${snapshot.renewsOn == null ? '' : ' · до ${snapshot.renewsOn!.day}.${snapshot.renewsOn!.month}.${snapshot.renewsOn!.year}'}',
    };

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.snapshot, this.onRetry});
  final PaywallSnapshot snapshot;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => _Notice(
      icon: snapshot.phase == PaywallPhase.success
          ? Icons.check_circle
          : snapshot.phase == PaywallPhase.userCancelled
              ? Icons.info_outline
              : Icons.error_outline,
      message: snapshot.message ??
          switch (snapshot.phase) {
            PaywallPhase.notAllowlisted =>
              'Демо-доступ недоступний для цього акаунта.',
            PaywallPhase.confirmationPending =>
              'Підтверджуємо доступ на сервері…',
            PaywallPhase.success => 'Premium активовано.',
            PaywallPhase.userCancelled =>
              'Покупку скасовано. Кошти не списано.',
            PaywallPhase.grace => 'Потрібно оновити спосіб оплати.',
            PaywallPhase.billingRetry => 'Повторюємо оплату.',
            PaywallPhase.expired => 'Підписка завершилась.',
            PaywallPhase.cancelled => 'Автопоновлення вимкнено.',
            _ => 'Покупку не завершено. Кошти не списано.'
          },
      action: onRetry == null
          ? null
          : TextButton(onPressed: onRetry, child: const Text('Повторити')));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Color.alphaBlend(context.semantic.error.withOpacity(.16),
              context.semantic.background),
          border: Border.all(color: context.semantic.error.withOpacity(.55)),
          borderRadius: AppRadius.md),
      child: Row(children: [
        Icon(icon, color: context.semantic.error),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(color: context.semantic.textPrimary))),
        if (action != null) action!
      ]));
}
