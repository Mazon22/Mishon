import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

final notificationSummaryProvider =
    AsyncNotifierProvider<NotificationSummaryNotifier, NotificationSummaryModel>(
  NotificationSummaryNotifier.new,
);

class NotificationSummaryNotifier extends AsyncNotifier<NotificationSummaryModel> {
  Timer? _poller;
  var _isDisposed = false;

  @override
  Future<NotificationSummaryModel> build() async {
    ref.onDispose(() {
      _isDisposed = true;
      _poller?.cancel();
    });
    _poller ??= Timer.periodic(const Duration(seconds: 8), (_) => refresh(silent: true));
    return _fetch();
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final summary = await _fetch();
      if (!_isDisposed) {
        state = AsyncValue.data(summary);
      }
    } catch (error, stackTrace) {
      if (!silent && !_isDisposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> markAllAsRead() async {
    await ref.read(socialRepositoryProvider).markAllNotificationsRead();
    await refresh();
  }

  Future<NotificationSummaryModel> _fetch() async {
    return ref.read(socialRepositoryProvider).getNotificationSummary();
  }
}
