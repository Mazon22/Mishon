import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

final notificationSummaryProvider = AsyncNotifierProvider<
  NotificationSummaryNotifier,
  NotificationSummaryModel
>(NotificationSummaryNotifier.new);

class NotificationSummaryNotifier
    extends AsyncNotifier<NotificationSummaryModel> {
  @override
  Future<NotificationSummaryModel> build() async {
    final cachedSummary =
        ref.read(socialRepositoryProvider).peekNotificationSummary();

    if (cachedSummary != null) {
      Future<void>.microtask(() => refresh(silent: true));
      return cachedSummary;
    }

    return _fetch(forceRefresh: true);
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final summary = await _fetch(forceRefresh: true);
      state = AsyncValue.data(summary);
    } catch (error, stackTrace) {
      if (!silent) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> markAllAsRead() async {
    await ref.read(socialRepositoryProvider).markAllNotificationsRead();
    await refresh();
  }

  Future<NotificationSummaryModel> _fetch({bool forceRefresh = false}) async {
    return ref
        .read(socialRepositoryProvider)
        .getNotificationSummary(forceRefresh: forceRefresh);
  }
}
