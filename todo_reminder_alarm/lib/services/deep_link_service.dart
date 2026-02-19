import 'dart:async';

import 'package:app_links/app_links.dart';

import '../app/deep_link_utils.dart';

class DeepLinkService {
  DeepLinkService(this._appLinks);

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  final _businessIdController = StreamController<String>.broadcast();
  bool _initialized = false;

  Stream<String> get businessIdStream => _businessIdController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      final initialBusinessId = businessIdFromDeepLink(initialUri);
      if (initialBusinessId != null) {
        _businessIdController.add(initialBusinessId);
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen((uri) {
      final businessId = businessIdFromDeepLink(uri);
      if (businessId != null) {
        _businessIdController.add(businessId);
      }
    }, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
    _businessIdController.close();
  }
}
