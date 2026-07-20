import 'package:flutter/material.dart';

import '../../app/theme/brand_theme.dart';
import '../../app/theme/tokens/app_tokens.dart';
import '../branding/brand_assets.dart';
import '../branding/brand_config.dart';

/// The shared, accessible building blocks for consumer-facing screens.
///
/// Screens should compose these controls instead of defining their own button,
/// card, input and adaptive-width variants. Product-specific content stays in
/// its feature package.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              );
    final enabled = isLoading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.primary =>
        ElevatedButton(onPressed: enabled, child: child),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: enabled, child: child),
      AppButtonVariant.text => TextButton(onPressed: enabled, child: child),
    };
    return Semantics(
      button: true,
      label: label,
      enabled: enabled != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

enum AppButtonVariant { primary, secondary, text }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? IconButton.filledTonal(
            icon: Icon(icon), tooltip: tooltip, onPressed: onPressed)
        : IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
    return Semantics(button: true, label: tooltip, child: button);
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Semantics(
        textField: true,
        label: label ?? hint,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: enabled,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.avatar,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: onSelected != null,
        label: label,
        child: FilterChip(
          label: Text(label),
          avatar: avatar,
          selected: selected,
          onSelected: onSelected,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
}

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.secondary;
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration:
            BoxDecoration(color: background, borderRadius: AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: scheme.onSecondary),
                const SizedBox(width: AppSpacing.xxs)
              ],
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.brand,
    this.trailing,
    this.showName = true,
  });

  final BrandDetails brand;
  final Widget? trailing;
  final bool showName;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: brand.name,
        child: Row(
          children: [
            BrandAvatar(brand: brand, radius: 22),
            if (showName) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: BrandLogo(brand: brand)),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!
            ],
          ],
        ),
      );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.image, this.name, this.radius = 22});

  final ImageProvider<Object>? image;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials =
        (name ?? '').trim().characters.take(2).join().toUpperCase();
    final hasName = initials.isNotEmpty;
    return Semantics(
      image: true,
      label: name == null ? 'Профіль користувача' : 'Профіль: $name',
      child: CircleAvatar(
        radius: radius,
        backgroundImage: image,
        child: image == null
            ? hasName
                ? Text(initials)
                : const Icon(Icons.person_outline)
            : null,
      ),
    );
  }
}

/// Loading placeholder with the design's 1.4 s shimmer sweep.
///
/// Falls back to a static [SemanticColors.surfaceStrong] block when the
/// platform requests reduced motion.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton(
      {super.key,
      this.width,
      this.height = 16,
      this.borderRadius = AppRadius.sm});

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  /// Design: «Shimmer 1.4 с».
  static const Duration shimmerPeriod = Duration(milliseconds: 1400);

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSkeleton.shimmerPeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Repeating forever would stall `pumpAndSettle` and burn frames for users
    // who asked for reduced motion, so the sweep is opt-out.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final base = semantic.surfaceStrong;
    final highlight = Color.alphaBlend(
      semantic.surface.withOpacity(.65),
      base,
    );

    return Semantics(
      label: 'Завантаження',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // -1.5 → 1.5 walks the highlight band fully across the box.
              final offset = _controller.value * 3 - 1.5;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment(offset - 1, 0),
                    end: Alignment(offset + 1, 0),
                    colors: [base, highlight, base],
                    stops: const [.35, .5, .65],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Icon + label metadata pair used across recipe cards, detail and camera
/// results (Handoff §3: chip height 34–36, radius 8–18, label 12–13).
///
/// Numeric values render in the mono data role so counters line up.
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.isData = false,
    this.boxed = false,
  });

  final IconData icon;
  final String label;

  /// Renders [label] in the JetBrains Mono data role (times, servings, counts).
  final bool isData;

  /// Draws the surface + border chip shell. Bare rows stay borderless so dense
  /// metadata wraps cleanly inside a card.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final textStyle = isData
        ? semantic.dataBody
            .copyWith(fontSize: 12, color: semantic.textSecondary)
        : Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: semantic.textSecondary);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: semantic.textSecondary),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    if (!boxed) return Semantics(label: label, child: row);

    return Semantics(
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: semantic.surface,
            borderRadius: AppRadius.sm,
            border: Border.all(color: semantic.surfaceStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Horizontal progress stepper (Handoff §3): 26–28 px circles, done =
/// success + check, active = accent + number, pending = surfaceStrong.
class FlowStepper extends StatelessWidget {
  const FlowStepper({
    super.key,
    required this.labels,
    required this.currentStep,
  });

  final List<String> labels;

  /// 1-based index of the active step.
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    final brand = theme.extension<BrandThemeExtension>();
    final accent = theme.brightness == Brightness.dark
        ? brand?.accentOnDark ?? AppColorsV2.premiumGold
        : brand?.accent ?? AppColorsV2.premiumGold;

    return Semantics(
      label: 'Крок $currentStep з ${labels.length}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, 18),
        child: Row(
          children: List.generate(labels.length, (index) {
            final stepNumber = index + 1;
            final isDone = stepNumber < currentStep;
            final isCurrent = stepNumber == currentStep;
            final circleColor = isDone
                ? semantic.success
                : isCurrent
                    ? accent
                    : semantic.surfaceStrong;
            final onCircle = isDone || isCurrent
                ? (brand?.onAccent ?? AppColorsV2.ink)
                : semantic.textSecondary;

            return Expanded(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 27,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? Icon(Icons.check_rounded,
                                size: 16, color: onCircle)
                            : Text(
                                '$stepNumber',
                                style: TextStyle(
                                  color: onCircle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      labels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCurrent
                            ? semantic.textPrimary
                            : semantic.textSecondary,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (index < labels.length - 1)
                    Container(
                      width: 16,
                      height: 1,
                      color: semantic.surfaceStrong,
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxs),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget> actions = const [],
}) =>
    showDialog<T>(
      context: context,
      builder: (_) =>
          AlertDialog(title: Text(title), content: content, actions: actions),
    );

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: builder(sheetContext),
        ),
      ),
    );
