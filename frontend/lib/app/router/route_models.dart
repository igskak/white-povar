class SearchRouteLocation {
  const SearchRouteLocation({this.query, this.tag});

  final String? query;
  final String? tag;

  factory SearchRouteLocation.fromUri(Uri uri) => SearchRouteLocation(
        query: _nonEmpty(uri.queryParameters['q']),
        tag: _nonEmpty(uri.queryParameters['tag']),
      );

  Uri toUri() => Uri(
        path: '/search',
        queryParameters: {
          if (query != null) 'q': query!,
          if (tag != null) 'tag': tag!,
        },
      );
}

class OfferRouteLocation {
  const OfferRouteLocation({required this.offerId, this.returnTo});

  final String offerId;
  final String? returnTo;

  factory OfferRouteLocation.subscription({String? returnTo}) =>
      OfferRouteLocation(offerId: 'subscription', returnTo: returnTo);

  factory OfferRouteLocation.fromUri(Uri uri) => OfferRouteLocation(
        offerId: uri.pathSegments.length > 1 ? uri.pathSegments[1] : '',
        returnTo: safeReturnPath(uri.queryParameters['returnTo']),
      );

  String get location => Uri(
        path: '/offers/$offerId',
        queryParameters: {if (returnTo != null) 'returnTo': returnTo!},
      ).toString();

  static String? safeReturnPath(String? value) {
    if (value == null || !value.startsWith('/')) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.path == '/login') {
      return null;
    }
    return uri.toString();
  }
}

/// A collection can mark one of its premium materials as a free preview. That
/// grant belongs to the collection, not to the recipe, so it has to travel with
/// the link — otherwise a material the collection screen showed as free locks
/// itself again the moment it opens on its own route. The server re-checks the
/// claim; carrying it here only keeps it from being lost in navigation.
class PreviewGrant {
  const PreviewGrant._();

  static const String queryParam = 'collectionId';

  static String appendTo(String path, String? collectionId) {
    if (collectionId == null || collectionId.isEmpty) return path;
    final uri = Uri.parse(path);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      queryParam: collectionId,
    }).toString();
  }

  static String? fromUri(Uri uri) => _nonEmpty(uri.queryParameters[queryParam]);
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
