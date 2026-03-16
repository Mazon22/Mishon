import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUserModel>>(
  (ref) {
    return ref.watch(socialRepositoryProvider).getBlockedUsers();
  },
);

final currentSessionInfoProvider =
    FutureProvider.autoDispose<CurrentSessionInfo>((ref) async {
      final repository = ref.read(authRepositoryProvider);
      final storage = ref.read(storageProvider);
      await storage.warmup();

      final profileFromState = ref.read(profileNotifierProvider).valueOrNull;
      final profile = profileFromState ?? await repository.getProfile();

      return CurrentSessionInfo(
        userId: profile.id,
        email: profile.email,
        accessTokenExpiry:
            storage.cachedAccessTokenExpiry ??
            await storage.readAccessTokenExpiry(),
        refreshTokenExpiry:
            storage.cachedRefreshTokenExpiry ??
            await storage.readRefreshTokenExpiry(),
      );
    });

class CurrentSessionInfo {
  final int userId;
  final String email;
  final DateTime? accessTokenExpiry;
  final DateTime? refreshTokenExpiry;

  const CurrentSessionInfo({
    required this.userId,
    required this.email,
    required this.accessTokenExpiry,
    required this.refreshTokenExpiry,
  });
}

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          strings.isRu ? 'Заблокированные пользователи' : 'Blocked users',
        ),
      ),
      body: SafeArea(
        top: false,
        child: blockedUsersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return _CenteredState(
                icon: Icons.shield_outlined,
                title:
                    strings.isRu
                        ? 'Список блокировок пуст'
                        : 'No blocked users',
                subtitle:
                    strings.isRu
                        ? 'Пользователи, которых вы заблокируете в чатах, появятся здесь.'
                        : 'Users you block in chats will appear here.',
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(blockedUsersProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _BlockedUserCard(user: user);
                },
              ),
            );
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
          error:
              (error, _) => _CenteredState(
                icon: Icons.error_outline_rounded,
                title:
                    strings.isRu
                        ? 'Не удалось загрузить список'
                        : 'Could not load the list',
                subtitle:
                    error is OfflineException
                        ? error.message
                        : strings.isRu
                        ? 'Проверьте подключение и попробуйте снова.'
                        : 'Check your connection and try again.',
                actionLabel: strings.retry,
                onAction: () => ref.refresh(blockedUsersProvider),
              ),
        ),
      ),
    );
  }
}

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final sessionAsync = ref.watch(currentSessionInfoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(strings.isRu ? 'Активные сеансы' : 'Active sessions'),
      ),
      body: SafeArea(
        top: false,
        child: sessionAsync.when(
          data:
              (session) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD9E2F2)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF081226,
                          ).withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F0FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.devices_rounded,
                                color: Color(0xFF2F67FF),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _platformLabel(strings),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF18243C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    strings.isRu
                                        ? 'Текущий сеанс Mishon'
                                        : 'Current Mishon session',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF66748C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF8F1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                strings.isRu ? 'Активен' : 'Active',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF1C8A59),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _SessionFactRow(
                          label:
                              strings.isRu ? 'Почта для входа' : 'Login email',
                          value: session.email,
                          onTap:
                              () => _copyEmail(context, strings, session.email),
                        ),
                        const Divider(height: 28),
                        _SessionFactRow(
                          label: strings.isRu ? 'User ID' : 'User ID',
                          value: session.userId.toString(),
                        ),
                        const Divider(height: 28),
                        _SessionFactRow(
                          label:
                              strings.isRu
                                  ? 'Доступ-токен действует до'
                                  : 'Access token valid until',
                          value: _formatDateTime(
                            strings,
                            session.accessTokenExpiry,
                          ),
                        ),
                        const Divider(height: 28),
                        _SessionFactRow(
                          label:
                              strings.isRu
                                  ? 'Refresh-сессия действует до'
                                  : 'Refresh session valid until',
                          value: _formatDateTime(
                            strings,
                            session.refreshTokenExpiry,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDCE4F2)),
                    ),
                    child: Text(
                      strings.isRu
                          ? 'Сейчас Mishon хранит один активный сеанс на аккаунт. Когда появится поддержка нескольких устройств, список будет расширен автоматически.'
                          : 'Mishon currently keeps one active session per account. This list will expand automatically once multi-device sessions are supported.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF66748C),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
          loading:
              () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
          error:
              (error, _) => _CenteredState(
                icon: Icons.error_outline_rounded,
                title:
                    strings.isRu
                        ? 'Не удалось загрузить сеанс'
                        : 'Could not load the session',
                subtitle:
                    error is OfflineException
                        ? error.message
                        : strings.isRu
                        ? 'Попробуйте открыть экран ещё раз.'
                        : 'Try opening this screen again.',
                actionLabel: strings.retry,
                onAction: () => ref.refresh(currentSessionInfoProvider),
              ),
        ),
      ),
    );
  }

  static Future<void> _copyEmail(
    BuildContext context,
    AppStrings strings,
    String email,
  ) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) {
      return;
    }

    showAppToast(
      context,
      message: strings.isRu ? 'Почта скопирована' : 'Email copied',
    );
  }
}

class _BlockedUserCard extends ConsumerWidget {
  final BlockedUserModel user;

  const _BlockedUserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => context.push('/profile/${user.id}'),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFDCE4F2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF081226).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              AppAvatar(
                username: user.username,
                imageUrl: user.avatarUrl,
                size: 54,
                scale: user.avatarScale,
                offsetX: user.avatarOffsetX,
                offsetY: user.avatarOffsetY,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF18243C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.aboutMe?.trim().isNotEmpty == true
                          ? user.aboutMe!.trim()
                          : _blockedLabel(strings, user.blockedAt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF66748C),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () => _unblock(context, ref, strings),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE9F0FF),
                  foregroundColor: const Color(0xFF2F67FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(strings.isRu ? 'Разблокировать' : 'Unblock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    try {
      await ref.read(socialRepositoryProvider).unblockUserFromChat(user.id);
      ref.invalidate(blockedUsersProvider);
      if (!context.mounted) {
        return;
      }

      showAppToast(
        context,
        message: strings.isRu ? 'Пользователь разблокирован' : 'User unblocked',
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
                ? 'Не удалось разблокировать пользователя'
                : 'Could not unblock the user',
        isError: true,
      );
    }
  }

  static String _blockedLabel(AppStrings strings, DateTime blockedAt) {
    final day = strings.formatMonthDay(blockedAt);
    final time = strings.formatShortTime(blockedAt);
    return strings.isRu ? 'Заблокирован $day, $time' : 'Blocked on $day, $time';
  }
}

class _SessionFactRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SessionFactRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF66748C)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF18243C),
            ),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFFB8C4D8)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF18243C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF66748C),
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(AppStrings strings, DateTime? value) {
  if (value == null) {
    return strings.isRu ? 'Неизвестно' : 'Unknown';
  }

  final localValue = value.toLocal();
  return '${strings.formatMonthDay(localValue)}, ${strings.formatShortTime(localValue)}';
}

String _platformLabel(AppStrings strings) {
  if (kIsWeb) {
    return strings.isRu ? 'Веб-браузер' : 'Web browser';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      strings.isRu ? 'Android-устройство' : 'Android device',
    TargetPlatform.iOS => strings.isRu ? 'iPhone или iPad' : 'iPhone or iPad',
    TargetPlatform.macOS => strings.isRu ? 'Mac' : 'Mac',
    TargetPlatform.windows => strings.isRu ? 'Windows' : 'Windows',
    TargetPlatform.linux => strings.isRu ? 'Linux' : 'Linux',
    TargetPlatform.fuchsia => strings.isRu ? 'Устройство' : 'Device',
  };
}
