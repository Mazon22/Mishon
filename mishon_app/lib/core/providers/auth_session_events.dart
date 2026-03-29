import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthSessionEventType { invalidated }

class AuthSessionEvent {
  final AuthSessionEventType type;

  const AuthSessionEvent(this.type);
}

class AuthSessionEvents {
  final StreamController<AuthSessionEvent> _controller =
      StreamController<AuthSessionEvent>.broadcast();

  Stream<AuthSessionEvent> get stream => _controller.stream;

  void notifyInvalidated() {
    if (_controller.isClosed) {
      return;
    }

    _controller.add(const AuthSessionEvent(AuthSessionEventType.invalidated));
  }

  void dispose() {
    _controller.close();
  }
}

final authSessionEventsProvider = Provider<AuthSessionEvents>((ref) {
  final events = AuthSessionEvents();
  ref.onDispose(events.dispose);
  return events;
});
