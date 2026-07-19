import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/brand_theme.dart';
import '../../../app/theme/tokens/app_tokens.dart';
import '../../../core/branding/brand_assets.dart';
import '../../../core/branding/brand_providers.dart';
import '../../../core/widgets/design_system.dart';
import '../../collections/providers/collection_provider.dart';
import '../purchase_adapter.dart';
import '../paywall_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

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
    final isDialog = MediaQuery.sizeOf(context).width >= 600;
    final child = _PaywallCard(snapshot: snapshot);
    return Scaffold(
      backgroundColor:
          isDialog ? Colors.black45 : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: isDialog
                ? Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.lg,
                    child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

class _PaywallCard extends ConsumerWidget {
  const _PaywallCard({required this.snapshot});

  final PaywallSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(tenantBootstrapProvider).brandConfig.brand;
    final purchasing = snapshot.phase == PaywallPhase.purchasing;
    final active = _isEntitled(snapshot.phase);
    final unavailable = snapshot.phase == PaywallPhase.productsUnavailable ||
        snapshot.phase == PaywallPhase.notAllowlisted;
    final selectedId = ref.watch(selectedPurchaseProductProvider) ??
        snapshot.products.firstOrNull?.id;
    final selectedProduct = snapshot.products
        .where((product) => product.id == selectedId)
        .firstOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF16130F),
        borderRadius:
            MediaQuery.sizeOf(context).width >= 600 ? AppRadius.lg : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        children: [
          Row(children: [
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Закрити',
              onPressed: purchasing ? null : () => Navigator.maybePop(context),
            ),
            const Spacer(),
            Text('ПІДПИСКА',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.brandTheme.accentOnDark,
                    letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
              height: 130,
              child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: BrandHero(brand: brand, role: 'paywall'))),
          const SizedBox(height: 18),
          if (active)
            _ActivePanel(snapshot: snapshot)
          else ...[
            Text(brand.voice.paywallTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFFF3E9DA),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('— ${brand.creatorName}, ${brand.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.brandTheme.accentOnDark,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const _Benefit(
                icon: Icons.check_circle, text: 'Premium-колекції та рецепти'),
            const _Benefit(
                icon: Icons.check_circle,
                text: 'AI-поради й пошук за фото без лімітів'),
            const SizedBox(height: 14),
            if (snapshot.phase == PaywallPhase.productsLoading)
              const _ProductsLoading()
            else if (unavailable)
              _Unavailable(message: snapshot.message)
            else ...[
              for (final product in snapshot.products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProductOption(
                    product: product,
                    selected: product.id == selectedId,
                    enabled: !purchasing,
                    onTap: () => ref
                        .read(selectedPurchaseProductProvider.notifier)
                        .state = product.id,
                  ),
                ),
              const SizedBox(height: 4),
              AppButton(
                label: 'Активувати демо-доступ',
                expand: true,
                isLoading: purchasing,
                onPressed: purchasing || selectedProduct == null
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
              const SizedBox(height: 8),
              const Text('Кошти не списуються',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB9AC98))),
            ],
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
          else
            AppButton(
                label: 'Оновити доступ',
                variant: AppButtonVariant.text,
                expand: true,
                isLoading: purchasing,
                onPressed: unavailable || purchasing
                    ? null
                    : () => ref.read(paywallProvider.notifier).restore()),
          const SizedBox(height: 4),
          Text('Умови · Конфіденційність',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: const Color(0xFF8D8271))),
        ],
      ),
    );
  }
}

bool _isEntitled(PaywallPhase phase) =>
    phase == PaywallPhase.active ||
    phase == PaywallPhase.grace ||
    phase == PaywallPhase.billingRetry;
bool _needsMessage(PaywallPhase phase) =>
    phase == PaywallPhase.success ||
    phase == PaywallPhase.error ||
    phase == PaywallPhase.userCancelled ||
    phase == PaywallPhase.grace ||
    phase == PaywallPhase.billingRetry ||
    phase == PaywallPhase.expired ||
    phase == PaywallPhase.cancelled ||
    phase == PaywallPhase.notAllowlisted ||
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
  const _Unavailable({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => _Notice(
      icon: Icons.phone_android_outlined,
      message: message ?? 'Продукти зараз недоступні.');
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
        const _Benefit(
            icon: Icons.check_circle, text: 'Premium-контент відкрито'),
        const _Benefit(icon: Icons.check_circle, text: 'AI-поради без лімітів'),
      ]);
}

String _entitlementLabel(PaywallSnapshot snapshot) => switch (snapshot.phase) {
      PaywallPhase.grace => 'Пільговий період активний. Оновіть спосіб оплати.',
      PaywallPhase.billingRetry =>
        'Повторюємо оплату. Premium-доступ поки активний.',
      _ =>
        'Premium активний${snapshot.renewsOn == null ? '' : ' · до ${snapshot.renewsOn!.day}.${snapshot.renewsOn!.month}.${snapshot.renewsOn!.year}'}',
    };

class _ProductOption extends StatelessWidget {
  const _ProductOption(
      {required this.product,
      required this.selected,
      required this.enabled,
      required this.onTap});
  final PurchaseProduct product;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '${product.title}, ${product.price}',
        child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: AppRadius.md,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: selected
                          ? context.brandTheme.accentOnDark
                          : const Color(0xFF4A4234),
                      width: selected ? 2 : 1),
                  borderRadius: AppRadius.md),
              child: Row(children: [
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: context.brandTheme.accentOnDark),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${product.title} · ${product.price}',
                          style: const TextStyle(
                              color: Color(0xFFF3E9DA),
                              fontWeight: FontWeight.w700)),
                      if (product.detail != null)
                        Text(product.detail!,
                            style: const TextStyle(
                                color: Color(0xFFB9AC98), fontSize: 12))
                    ])),
                if (product.badge != null) AppBadge(label: product.badge!)
              ]),
            )),
      );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: context.brandTheme.accentOnDark),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFE0D4BF))))
      ]));
}

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
          color: const Color(0xFF2A1A17),
          border: Border.all(color: const Color(0xFF6B3A31)),
          borderRadius: AppRadius.md),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFD67A6B)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFF3E9DA)))),
        if (action != null) action!
      ]));
}
