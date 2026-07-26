import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/brand_theme.dart';
import '../../app/theme/tokens/app_tokens.dart';
import '../images/remote_image.dart';
import 'brand_config.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, required this.brand, this.radius = 24});

  final BrandDetails brand;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback =
        _BrandMonogram(radius: radius, creatorName: brand.creatorName);
    if (!_isRemoteUrl(brand.avatar)) return fallback;
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: RemoteImage(
          url: brand.avatar,
          targetWidth: radius * 2,
          placeholder: fallback,
          errorWidget: fallback,
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.brand, this.height = 32});

  final BrandDetails brand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      brand.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
    );
    if (!_isRemoteUrl(brand.logo)) return fallback;
    return SizedBox(
      height: height,
      child: RemoteImage(
        url: brand.logo!,
        // Wordmarks are wider than they are tall; leave room for the ratio.
        targetWidth: height * 6,
        fit: BoxFit.contain,
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }
}

class BrandHero extends StatelessWidget {
  const BrandHero(
      {super.key,
      required this.brand,
      required this.role,
      this.fit = BoxFit.cover,
      this.targetWidth});

  final BrandDetails brand;
  final String role;
  final BoxFit fit;

  /// Logical width of the slot. Defaults to the window, which is right for the
  /// full-bleed login and paywall scenes; callers that fill only part of the
  /// screen pass their own width so the fetch and the decode stay in scale.
  final double? targetWidth;

  @override
  Widget build(BuildContext context) {
    final photo = brand.heroFor(role);
    final fallback = _BrandHeroFallback(creatorName: brand.creatorName);
    if (photo == null || !_isRemoteUrl(photo.url)) return fallback;
    return RemoteImage(
      url: photo.url,
      targetWidth: targetWidth ?? MediaQuery.sizeOf(context).width,
      fit: fit,
      alignment: Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1),
      placeholder: fallback,
      errorWidget: fallback,
    );
  }
}

/// A published brand photo shown as a rounded banner.
///
/// Home and the collection index read as finished without a photo, so call
/// sites guard on [BrandDetails.heroFor] and omit this entirely rather than
/// dropping in the gradient placeholder [BrandHero] uses. No scrim: nothing is
/// drawn on top, and the dish should read bright.
class BrandHeroBanner extends StatelessWidget {
  const BrandHeroBanner({
    super.key,
    required this.brand,
    required this.role,
    this.aspectRatio = 2,
    this.maxHeight = 300,
  });

  final BrandDetails brand;
  final String role;

  /// Height follows the width so the banner keeps its shape across
  /// breakpoints. A fixed height turns into a 9:1 letterbox on a desktop
  /// column, which crops a portrait to a band.
  final double aspectRatio;

  /// Ceiling for wide columns, so the banner stays a banner.
  final double maxHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return SizedBox(
            height: math.min(width / aspectRatio, maxHeight),
            width: double.infinity,
            child: ClipRRect(
              borderRadius: AppRadius.lg,
              child: BrandHero(
                brand: brand,
                role: role,
                // The banner is a column, not the window: asking for the window
                // width fetches and decodes a 2000px original for a 300px slot.
                targetWidth: width,
              ),
            ),
          );
        },
      );
}

class _BrandMonogram extends StatelessWidget {
  const _BrandMonogram({required this.radius, required this.creatorName});

  final double radius;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: context.brandTheme.accent),
      child: Text(
        creatorName.characters.first.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(color: context.brandTheme.onAccent),
      ),
    );
  }
}

class _BrandHeroFallback extends StatelessWidget {
  const _BrandHeroFallback({required this.creatorName});

  final String creatorName;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.accentOnDark, const Color(0xFF16130F)],
        ),
      ),
      child: Center(
        child: Text(
          creatorName,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

bool _isRemoteUrl(String? value) =>
    value != null &&
    Uri.tryParse(value)?.hasScheme == true &&
    value.startsWith('http');
