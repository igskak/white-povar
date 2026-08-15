import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/brand_theme.dart';
import '../../app/theme/tokens/app_tokens.dart';
import '../images/remote_image.dart';
import 'brand_config.dart';

/// Aspect ratios used by the compact Studio preview.
///
/// Keep these in one place: the crop thumbnails in Studio must describe the
/// same slots as the widgets below, otherwise a perfectly valid 1.0x crop can
/// look dramatically more zoomed when it reaches the live preview.
abstract final class BrandMediaAspectRatio {
  static const double studioViewportWidth = 360;
  static const double login = (studioViewportWidth - AppSpacing.md * 2) / 172;
  static const double paywall = (studioViewportWidth - 22 * 2) / 130;
  static const double banner = 2;
  static const double avatar = 1;

  /// The window the Studio previews and crops desktop against — the same
  /// reference width the responsive goldens use.
  static const double desktopWindowWidth = 1280;

  /// The banner's shape on a desktop page of [windowWidth].
  ///
  /// [BrandHeroBanner] holds [banner] until its height reaches the ceiling, and
  /// a desktop column keeps widening past that — so the same photo is cropped
  /// to a flatter band there than on a phone. Derived rather than written down,
  /// so the crop thumbnail cannot promise a shape the page stopped rendering.
  static double bannerOnDesktop([double windowWidth = desktopWindowWidth]) {
    // What the branded rail, its divider and the page gutters leave.
    final page = windowWidth - AppLayout.railWidth - 1;
    final column = math.min(page, AppLayout.contentMax) -
        AppLayout.gutter(windowWidth) * 2;
    return column / math.min(column / banner, BrandHeroBanner.maxBannerHeight);
  }
}

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final zoom = brand.avatarCrop.zoom;
            // At 1x there is no overflow to pan through, so legacy focal
            // values away from the centre must not translate the whole image
            // out of its circular viewport.
            final minFocal = .5 / zoom;
            final maxFocal = 1 - minFocal;
            final focalX = brand.avatarCrop.focalX.clamp(minFocal, maxFocal);
            final focalY = brand.avatarCrop.focalY.clamp(minFocal, maxFocal);
            return Transform(
              transform: Matrix4.identity()
                ..translate(size.width / 2, size.height / 2)
                ..scale(zoom, zoom, 1)
                ..translate(
                  -focalX * size.width,
                  -focalY * size.height,
                ),
              child: RemoteImage(
                url: brand.avatar,
                targetWidth: radius * 2,
                placeholder: fallback,
                errorWidget: fallback,
              ),
            );
          },
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
    final alignment = Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1);
    return ClipRect(
      child: Transform.scale(
        scale: photo.zoom,
        alignment: alignment,
        child: RemoteImage(
          url: photo.url,
          targetWidth: targetWidth ?? MediaQuery.sizeOf(context).width,
          fit: fit,
          alignment: alignment,
          placeholder: fallback,
          errorWidget: fallback,
        ),
      ),
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
    this.aspectRatio = BrandMediaAspectRatio.banner,
    this.maxHeight = maxBannerHeight,
  });

  /// Ceiling a banner grows to before the column stops giving it height.
  static const double maxBannerHeight = 300;

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
