import 'package:flutter/material.dart';

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

class AppSkeleton extends StatelessWidget {
  const AppSkeleton(
      {super.key,
      this.width,
      this.height = 16,
      this.borderRadius = AppRadius.sm});

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Завантаження',
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ),
      );
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
