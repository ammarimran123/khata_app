import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Stream (the Supabase auth-state stream) to go_router's
/// `refreshListenable`, so route redirects re-evaluate on every auth event.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
