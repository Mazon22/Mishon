import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';

enum AppConnectionPhase { connecting, updating, connected }

class AppConnectionStatus {
  final AppConnectionPhase phase;

  const AppConnectionStatus._(this.phase);

  const AppConnectionStatus.connecting()
    : this._(AppConnectionPhase.connecting);

  const AppConnectionStatus.updating() : this._(AppConnectionPhase.updating);

  const AppConnectionStatus.connected() : this._(AppConnectionPhase.connected);

  bool get isVisible => phase != AppConnectionPhase.connected;

  String label(AppStrings strings) {
    switch (phase) {
      case AppConnectionPhase.connecting:
        return strings.connectionConnecting;
      case AppConnectionPhase.updating:
        return strings.connectionUpdating;
      case AppConnectionPhase.connected:
        return strings.connectionConnected;
    }
  }
}

final appConnectionStatusProvider = Provider<AppConnectionStatus>((ref) {
  final bootstrapState = ref.watch(appBootstrapProvider);

  if (!bootstrapState.hasConnection) {
    return const AppConnectionStatus.connecting();
  }

  if (bootstrapState.phase == AppBootstrapPhase.preloadingRemoteData) {
    return const AppConnectionStatus.updating();
  }

  if (!bootstrapState.isReady) {
    return const AppConnectionStatus.connecting();
  }

  return const AppConnectionStatus.connected();
});
