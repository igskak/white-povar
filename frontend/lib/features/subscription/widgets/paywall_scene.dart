import 'package:flutter/material.dart';

import '../../../app/theme/brand_theme.dart';
import '../../../app/theme/tokens/app_tokens.dart';
import '../../../core/branding/brand_assets.dart';
import '../../../core/branding/brand_config.dart';
import '../../../core/widgets/design_system.dart';
import '../purchase_adapter.dart';

/// The presentational halves of the paywall (13h), free of providers so the
/// Creator Studio preview (13m) renders the very same widgets the app does.

/// heroPhotos[0] cropped to the paywall portrait; falls back to the brand
/// gradient when the tenant published no photos (13d).
class PaywallHeroImage extends StatelessWidget {
  const PaywallHeroImage({super.key, required this.brand, this.height = 130});

  final BrandDetails brand;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: AppRadius.md,
          child: BrandHero(brand: brand, role: 'paywall'),
        ),
      );
}

/// Hero, brand voice title, creator signature and the benefit list.
class PaywallPitch extends StatelessWidget {
  const PaywallPitch({super.key, required this.brand});

  final BrandDetails brand;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaywallHeroImage(brand: brand),
          const SizedBox(height: 18),
          Text(brand.voice.paywallTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.semantic.textPrimary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('— ${brand.creatorName}, ${brand.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.brandTheme.accentOnDark,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          // 13m: the course benefit disappears when the brand publishes no
          // courseName; the product benefits below never depend on the tenant.
          if (brand.voice.courseName != null)
            PaywallBenefit(
                icon: Icons.check_circle,
                text: 'Курс «${brand.voice.courseName}» + premium-рецепти'),
          const PaywallBenefit(
              icon: Icons.check_circle, text: 'Premium-колекції та рецепти'),
          const PaywallBenefit(
              icon: Icons.check_circle,
              text: 'AI-поради й пошук за фото без лімітів'),
          const PaywallBenefit(
              icon: Icons.check_circle,
              text: 'Збереження, планування меню та список покупок'),
          const PaywallBenefit(
              icon: Icons.check_circle,
              text: 'Нові авторські колекції без реклами'),
        ],
      );
}

/// Store plans, the purchase CTA and its renewal footnote.
class PaywallPlans extends StatelessWidget {
  const PaywallPlans({
    super.key,
    required this.products,
    required this.selectedId,
    required this.onSelect,
    required this.ctaLabel,
    required this.footnote,
    required this.onPurchase,
    this.busy = false,
  });

  final List<PurchaseProduct> products;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String ctaLabel;
  final String footnote;
  final VoidCallback? onPurchase;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final product in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PaywallProductOption(
                product: product,
                selected: product.id == selectedId,
                enabled: !busy,
                onTap: () => onSelect(product.id),
              ),
            ),
          const SizedBox(height: 4),
          AppButton(
            label: ctaLabel,
            expand: true,
            isLoading: busy,
            onPressed: onPurchase,
          ),
          const SizedBox(height: 8),
          Text(footnote,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.semantic.textSecondary)),
        ],
      );
}

class PaywallProductOption extends StatelessWidget {
  const PaywallProductOption({
    super.key,
    required this.product,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

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
                          : context.semantic.surfaceStrong,
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
                          style: TextStyle(
                              color: context.semantic.textPrimary,
                              fontWeight: FontWeight.w700)),
                      if (product.detail != null)
                        Text(product.detail!,
                            style: TextStyle(
                                color: context.semantic.textSecondary,
                                fontSize: 12))
                      else if (product.trial != null)
                        Text(product.trial!,
                            style: TextStyle(
                                color: context.semantic.textSecondary,
                                fontSize: 12))
                    ])),
                if (product.badge != null) AppBadge(label: product.badge!)
              ]),
            )),
      );
}

class PaywallBenefit extends StatelessWidget {
  const PaywallBenefit({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: context.brandTheme.accentOnDark),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: TextStyle(color: context.semantic.textPrimary)))
      ]));
}
