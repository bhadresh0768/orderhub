Uri businessDeepLinkUri(String businessId) {
  return Uri(scheme: 'orderhub', host: 'business', pathSegments: [businessId]);
}

Uri businessWebDeepLinkUri(String businessId) {
  return Uri(
    scheme: 'https',
    host: 'orderhub.app',
    pathSegments: ['business', businessId],
  );
}

String businessDeepLink(String businessId) =>
    businessDeepLinkUri(businessId).toString();

String businessWebDeepLink(String businessId) =>
    businessWebDeepLinkUri(businessId).toString();

String? businessIdFromDeepLink(Uri? uri) {
  if (uri == null) return null;

  if (uri.scheme == 'orderhub' && uri.host == 'business') {
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.first.trim().isEmpty
        ? null
        : uri.pathSegments.first.trim();
  }

  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'orderhub.app') {
    if (uri.pathSegments.length < 2) return null;
    if (uri.pathSegments.first != 'business') return null;
    final id = uri.pathSegments[1].trim();
    return id.isEmpty ? null : id;
  }

  return null;
}
