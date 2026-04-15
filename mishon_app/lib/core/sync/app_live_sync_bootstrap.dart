import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/sync/live_sync_service.dart';
import 'package:mishon_app/features/chats/providers/chats_overview_provider.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/friends/providers/friends_screen_provider.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';
import 'package:mishon_app/features/people/providers/people_screen_provider.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

final appLiveSyncBootstrapProvider = Provider<LiveSyncStatus>((ref) {
  final service = ref.watch(liveSyncServiceProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  var isDisposed = false;

  var lastStatus = LiveSyncStatus.idle;
  Timer? flushTimer;
  var feedDirty = false;
  var profileDirty = false;
  var friendsDirty = false;
  var peopleDirty = false;
  var chatsDirty = false;
  var notificationsDirty = false;

  void flush() {
    flushTimer?.cancel();
    flushTimer = null;

    if (isDisposed) {
      return;
    }

    if (feedDirty) {
      ref.invalidate(feedNotifierProvider(FeedTabType.forYou));
      ref.invalidate(feedNotifierProvider(FeedTabType.following));
      feedDirty = false;
    }

    if (profileDirty) {
      ref.invalidate(profileNotifierProvider);
      if (currentUserId != null) {
        ref.invalidate(userProfileNotifierProvider(currentUserId));
      }
      profileDirty = false;
    }

    if (friendsDirty) {
      unawaited(
        ref
            .read(friendsScreenControllerProvider.notifier)
            .load(forceRefresh: true, silent: true),
      );
      friendsDirty = false;
    }

    if (peopleDirty) {
      unawaited(
        ref
            .read(peopleScreenControllerProvider.notifier)
            .loadDiscovery(forceRefresh: true, silent: true),
      );
      peopleDirty = false;
    }

    if (chatsDirty) {
      unawaited(
        ref
            .read(chatsOverviewControllerProvider.notifier)
            .load(forceRefresh: true, silent: true),
      );
      chatsDirty = false;
    }

    if (notificationsDirty) {
      unawaited(
        ref.read(notificationSummaryProvider.notifier).refresh(silent: true),
      );
      notificationsDirty = false;
    }
  }

  void scheduleFlush() {
    flushTimer?.cancel();
    flushTimer = Timer(const Duration(milliseconds: 250), flush);
  }

  final eventsSubscription = service.events.listen((event) {
    if (isDisposed) {
      return;
    }

    switch (event.type) {
      case 'sync.resync':
        unawaited(ref.read(appBootstrapProvider.notifier).refreshRemoteData());
        return;
      case 'post.created':
      case 'post.updated':
      case 'post.deleted':
      case 'post.interaction.changed':
      case 'comment.created':
      case 'comment.updated':
      case 'comment.deleted':
      case 'post.author-follow.changed':
        feedDirty = true;
        profileDirty = true;
        scheduleFlush();
        return;
      case 'profile.updated':
        feedDirty = true;
        profileDirty = true;
        peopleDirty = true;
        friendsDirty = true;
        chatsDirty = true;
        scheduleFlush();
        return;
      case 'friends.changed':
      case 'follow.changed':
        feedDirty = true;
        profileDirty = true;
        friendsDirty = true;
        peopleDirty = true;
        notificationsDirty = true;
        scheduleFlush();
        return;
      case 'notifications.changed':
      case 'notification.summary.changed':
        notificationsDirty = true;
        scheduleFlush();
        return;
      case 'chat.message.created':
      case 'chat.message.updated':
      case 'chat.message.deleted':
      case 'chat.conversation.changed':
      case 'chat.history.cleared':
      case 'chat.typing.started':
      case 'chat.typing.stopped':
        chatsDirty = true;
        notificationsDirty = true;
        scheduleFlush();
        return;
    }
  });

  final statusSubscription = service.statuses.listen((status) {
    lastStatus = status;
  });

  ref.onDispose(() {
    isDisposed = true;
    flushTimer?.cancel();
    eventsSubscription.cancel();
    statusSubscription.cancel();
  });

  if (isAuthenticated) {
    unawaited(service.ensureConnected());
  } else {
    unawaited(service.disconnect());
  }

  return lastStatus;
});
