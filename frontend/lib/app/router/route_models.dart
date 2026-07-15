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

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
