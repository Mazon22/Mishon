import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';

class ChatDestinationChoice {
  final int? conversationId;
  final int peerId;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final bool isSavedMessages;

  const ChatDestinationChoice({
    required this.conversationId,
    required this.peerId,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.avatarScale,
    required this.avatarOffsetX,
    required this.avatarOffsetY,
    this.isSavedMessages = false,
  });
}

Future<List<ChatDestinationChoice>> loadChatDestinationChoices({
  required WidgetRef ref,
  required AppStrings strings,
}) async {
  final currentUserId = ref.read(currentUserIdProvider);
  final socialRepository = ref.read(socialRepositoryProvider);
  final authRepository = ref.read(authRepositoryProvider);
  final conversations = await socialRepository.getConversations(
    forceRefresh: true,
  );

  UserProfile? currentProfile;
  if (currentUserId != null) {
    currentProfile = authRepository.peekProfile();
    if (currentProfile == null) {
      try {
        currentProfile = await authRepository.getProfile();
      } catch (_) {
        currentProfile = null;
      }
    }
  }

  final destinations = <ChatDestinationChoice>[];
  if (currentUserId != null) {
    ConversationModel? savedMessagesConversation;
    for (final conversation in conversations) {
      if (conversation.peerId == currentUserId) {
        savedMessagesConversation = conversation;
        break;
      }
    }

    destinations.add(
      ChatDestinationChoice(
        conversationId: savedMessagesConversation?.id,
        peerId: currentUserId,
        title: 'Saved Messages',
        subtitle:
            strings.isRu
                ? 'Личные заметки, файлы и пересылки'
                : 'Private notes, files, and forwards',
        avatarUrl:
            currentProfile?.avatarUrl ?? savedMessagesConversation?.avatarUrl,
        avatarScale:
            currentProfile?.avatarScale ??
            savedMessagesConversation?.avatarScale ??
            1,
        avatarOffsetX:
            currentProfile?.avatarOffsetX ??
            savedMessagesConversation?.avatarOffsetX ??
            0,
        avatarOffsetY:
            currentProfile?.avatarOffsetY ??
            savedMessagesConversation?.avatarOffsetY ??
            0,
        isSavedMessages: true,
      ),
    );
  }

  for (final conversation in conversations) {
    if (currentUserId != null && conversation.peerId == currentUserId) {
      continue;
    }

    destinations.add(
      ChatDestinationChoice(
        conversationId: conversation.id,
        peerId: conversation.peerId,
        title: conversation.username,
        subtitle:
            (conversation.lastMessage?.trim().isNotEmpty ?? false)
                ? conversation.lastMessage!.trim()
                : (strings.isRu ? 'Чат' : 'Chat'),
        avatarUrl: conversation.avatarUrl,
        avatarScale: conversation.avatarScale,
        avatarOffsetX: conversation.avatarOffsetX,
        avatarOffsetY: conversation.avatarOffsetY,
      ),
    );
  }

  return destinations;
}

Future<ChatDestinationChoice?> showChatDestinationPicker({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<ChatDestinationChoice> destinations,
}) {
  return showModalBottomSheet<ChatDestinationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder:
        (context) => _ChatDestinationPickerSheet(
          title: title,
          subtitle: subtitle,
          destinations: destinations,
        ),
  );
}

class _ChatDestinationPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ChatDestinationChoice> destinations;

  const _ChatDestinationPickerSheet({
    required this.title,
    required this.subtitle,
    required this.destinations,
  });

  @override
  State<_ChatDestinationPickerSheet> createState() =>
      _ChatDestinationPickerSheetState();
}

class _ChatDestinationPickerSheetState
    extends State<_ChatDestinationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final destinations =
        normalizedQuery.isEmpty
            ? widget.destinations
            : widget.destinations
                .where(
                  (destination) =>
                      destination.title.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      destination.subtitle.toLowerCase().contains(
                        normalizedQuery,
                      ),
                )
                .toList(growable: false);

    return SizedBox(
      height: math.min(MediaQuery.sizeOf(context).height * 0.82, 620),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18243C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF74839C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDE6F6)),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText:
                          strings.isRu ? 'Поиск по чатам' : 'Search chats',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                destinations.isEmpty
                    ? Center(
                      child: Text(
                        strings.isRu ? 'Ничего не найдено' : 'Nothing found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7C889C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final destination = destinations[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.of(context).pop(destination),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color:
                                      destination.isSavedMessages
                                          ? const Color(0xFFD6E4FF)
                                          : const Color(0xFFE7EDF7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF132443,
                                    ).withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AppAvatar(
                                        username: destination.title,
                                        imageUrl: destination.avatarUrl,
                                        size: 48,
                                        scale: destination.avatarScale,
                                        offsetX: destination.avatarOffsetX,
                                        offsetY: destination.avatarOffsetY,
                                      ),
                                      if (destination.isSavedMessages)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2F67FF),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.bookmark_rounded,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          destination.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            color: const Color(0xFF18243C),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          destination.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF75839C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFF8A97AD),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
