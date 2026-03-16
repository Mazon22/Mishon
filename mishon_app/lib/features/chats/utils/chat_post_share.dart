import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/utils/chat_share_content.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/features/chats/widgets/chat_destination_picker.dart';

Future<void> sharePostToChat({
  required BuildContext context,
  required WidgetRef ref,
  required Post post,
}) async {
  final strings = AppStrings.of(context);

  try {
    final destinations = await loadChatDestinationChoices(
      ref: ref,
      strings: strings,
    );
    if (!context.mounted) {
      return;
    }

    final destination = await showChatDestinationPicker(
      context: context,
      title: strings.isRu ? 'Поделиться постом' : 'Share post',
      subtitle:
          strings.isRu
              ? 'Выберите чат или Saved Messages'
              : 'Choose a chat or Saved Messages',
      destinations: destinations,
    );
    if (!context.mounted || destination == null) {
      return;
    }

    var targetConversationId = destination.conversationId;
    if (targetConversationId == null) {
      final createdConversation = await ref
          .read(socialRepositoryProvider)
          .getOrCreateConversation(destination.peerId);
      targetConversationId = createdConversation.id;
    }

    await ref
        .read(socialRepositoryProvider)
        .sendMessage(targetConversationId, encodeSharedPostMessage(post));

    if (!context.mounted) {
      return;
    }

    showAppToast(
      context,
      message:
          strings.isRu
              ? 'Пост отправлен в ${destination.title}'
              : 'Post sent to ${destination.title}',
    );
  } on ApiException catch (e) {
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: e.apiError.message, isError: true);
  } on OfflineException catch (e) {
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: e.message, isError: true);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message:
          strings.isRu
              ? 'Не удалось поделиться постом'
              : 'Could not share the post',
      isError: true,
    );
  }
}
