import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Supabase Storage serves objects untouched, and the pilot recipe bucket holds
/// 1-2 MB PNGs. A catalogue screen pulls ~20 of them, which is why photography
/// stalls on a phone. The render endpoint resizes on the fly and re-encodes to
/// WebP for clients that accept it, so a card thumbnail costs tens of kilobytes.
const _objectPrefix = '/storage/v1/object/public/';
const _renderPrefix = '/storage/v1/render/image/public/';

/// Image transformations are not available on every Supabase project. Keep
/// them opt-in so a project without that feature loads the public original
/// instead of turning every image request into a 403 response.
const supabaseImageTransformsEnabled = bool.fromEnvironment(
  'SUPABASE_IMAGE_TRANSFORMS_ENABLED',
  defaultValue: false,
);

/// The web HtmlImage path negotiates WebP through the browser, but the native
/// and http-fallback paths have to ask for it. Without this header the render
/// endpoint returns a resized PNG that can be larger than the original.
const remoteImageHeaders = {'Accept': 'image/webp,image/*'};

/// Supabase caps transformation dimensions; stay inside the supported range.
const _minRenderWidth = 64;
const _maxRenderWidth = 2000;

/// Requested widths are snapped to these steps so that devices with different
/// pixel ratios still share CDN and on-device cache entries.
const _widthBuckets = <int>[
  160,
  320,
  480,
  640,
  960,
  1280,
  1600,
  _maxRenderWidth
];

/// When transformations are enabled, rewrites a public Supabase object URL to
/// its resized, WebP-negotiated variant. Disabled transformations and anything
/// outside Supabase Storage are returned unchanged.
String sizedRemoteImageUrl(
  String url, {
  required int width,
  int quality = 70,
  bool enableTransform = supabaseImageTransformsEnabled,
}) {
  if (!enableTransform) return url;
  final marker = url.indexOf(_objectPrefix);
  if (marker < 0) return url;

  // Keep the object path byte-for-byte: it is already percent-encoded, and
  // rebuilding it through Uri would escape the escapes.
  var objectPath = url.substring(marker + _objectPrefix.length);
  for (final terminator in const ['?', '#']) {
    final cut = objectPath.indexOf(terminator);
    if (cut >= 0) objectPath = objectPath.substring(0, cut);
  }
  if (objectPath.isEmpty) return url;

  return '${url.substring(0, marker)}$_renderPrefix$objectPath'
      '?width=${renderWidthFor(width)}&quality=$quality&resize=contain';
}

/// Clamps and snaps a pixel width to the buckets the render endpoint is asked
/// for. Exposed for tests.
int renderWidthFor(int pixelWidth) {
  if (pixelWidth <= _minRenderWidth) return _widthBuckets.first;
  for (final bucket in _widthBuckets) {
    if (pixelWidth <= bucket) return bucket;
  }
  return _maxRenderWidth;
}

/// Network photography sized for the slot it fills.
///
/// [targetWidth] is the logical width of that slot; it is scaled by the device
/// pixel ratio to pick the transformation and the decode size, so a phone never
/// downloads or rasterises a full-resolution original.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.targetWidth,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double targetWidth;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final pixelWidth = renderWidthFor(
      (targetWidth * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    final loading = placeholder;
    final failed = errorWidget;
    final requestedUrl = sizedRemoteImageUrl(url, width: pixelWidth);
    return CachedNetworkImage(
      imageUrl: requestedUrl,
      httpHeaders: remoteImageHeaders,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      alignment: alignment,
      memCacheWidth: pixelWidth,
      placeholder: loading == null ? null : (_, __) => loading,
      errorWidget: (_, __, ___) {
        // A deployment may enable transforms before the Supabase feature is
        // actually available. In that case preserve photography by retrying
        // the public object URL once.
        if (requestedUrl != url) {
          return CachedNetworkImage(
            imageUrl: url,
            httpHeaders: remoteImageHeaders,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            alignment: alignment,
            memCacheWidth: pixelWidth,
            placeholder: loading == null ? null : (_, __) => loading,
            errorWidget: failed == null ? null : (_, __, ___) => failed,
          );
        }
        return failed ?? const SizedBox.shrink();
      },
    );
  }
}
