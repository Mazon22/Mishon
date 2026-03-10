import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  Timer? _poller;
  bool _isLoading = true;
  String? _errorMessage;
  List<ConversationModel> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _loadConversations(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations = await ref.read(socialRepositoryProvider).getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось загрузить диалоги';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentSection: AppSection.chats,
      title: 'Чаты',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _loadConversations(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF101727),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Личные сообщения',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Диалоги обновляются автоматически без перезагрузки страницы и приложения.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: _isLoading
                    ? const LoadingState()
                    : _errorMessage != null
                        ? ErrorState(
                            message: _errorMessage!,
                            onRetry: () => _loadConversations(),
                          )
                        : _conversations.isEmpty
                            ? const EmptyState(
                                icon: Icons.forum_outlined,
                                title: 'Пока нет диалогов',
                                subtitle: 'Добавьте пользователя в друзья и откройте с ним чат.',
                              )
                            : RefreshIndicator(
                                onRefresh: () => _loadConversations(),
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _conversations.length,
                                  itemBuilder: (context, index) {
                                    final conversation = _conversations[index];
                                    return _ConversationTile(
                                      conversation: conversation,
                                      onTap: () => context.push(
                                        '/chat',
                                        extra: ChatScreenArgs(
                                          conversationId: conversation.id,
                                          peerId: conversation.peerId,
                                          peerUsername: conversation.username,
                                          peerAvatarUrl: conversation.avatarUrl,
                                          peerAvatarScale: conversation.avatarScale,
                                          peerAvatarOffsetX: conversation.avatarOffsetX,
                                          peerAvatarOffsetY: conversation.avatarOffsetY,
                                        ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = conversation.lastMessageAt != null
        ? DateFormat('dd MMM, HH:mm').format(conversation.lastMessageAt!.toLocal())
        : 'Новый диалог';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppAvatar(
                username: conversation.username,
                imageUrl: conversation.avatarUrl,
                size: 52,
                scale: conversation.avatarScale,
                offsetX: conversation.avatarOffsetX,
                offsetY: conversation.avatarOffsetY,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          timestamp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conversation.lastMessage ?? 'Напишите первое сообщение',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (conversation.unreadCount > 0)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${conversation.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
