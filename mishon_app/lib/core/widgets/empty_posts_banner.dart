import 'package:flutter/material.dart';

/// Современный баннер для отображения пустого состояния постов
/// С призывом к действию (CTA), адаптивный, с выразительной иконкой
class EmptyPostsBanner extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final String? ctaText;
  final VoidCallback? onCtaPressed;
  final bool showCta;

  const EmptyPostsBanner({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.ctaText,
    this.onCtaPressed,
    this.showCta = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isWeb = screenSize.width > 800;

    // Адаптивный размер иконки
    final iconSize = isWeb
        ? (screenSize.width * 0.05).clamp(100.0, 160.0)
        : (screenSize.width * 0.35).clamp(120.0, 160.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        // Минимальная высота для контента
        final minContentHeight = iconSize + 120 + (showCta ? 80 : 40);

        // Если контента больше чем доступно - используем scroll
        if (minContentHeight > availableHeight) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildContent(
              context,
              theme,
              colorScheme,
              isDark,
              iconSize,
              constraints: constraints,
            ),
          );
        }

        // Иначе центрируем
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildContent(
              context,
              theme,
              colorScheme,
              isDark,
              iconSize,
              constraints: constraints,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
    double iconSize, {
    required BoxConstraints constraints,
  }) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final maxWidth = constraints.maxWidth;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isWeb ? 500 : maxWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Выразительная иконка с градиентным фоном
          Flexible(
            flex: 0,
            child: Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          colorScheme.primaryContainer.withValues(alpha: 0.4),
                          colorScheme.primary.withValues(alpha: 0.2),
                        ]
                      : [
                          colorScheme.primaryContainer.withValues(alpha: 0.6),
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 8,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon ?? Icons.add_photo_alternate_outlined,
                size: iconSize * 0.5,
                color: isDark
                    ? colorScheme.primary.withValues(alpha: 0.9)
                    : colorScheme.primary,
              ),
            ),
          ),
          // Воздушный отступ
          SizedBox(height: isWeb ? 40 : 32),
          // Заголовок
          Flexible(
            flex: 0,
            child: Text(
              title ?? 'Нет постов',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.95)
                    : colorScheme.onSurface,
                fontSize: isWeb ? 32 : 28,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: isWeb ? 20 : 16),
          // Подзаголовок
          Flexible(
            flex: 0,
            child: Text(
              subtitle ??
                  'Создайте свой первый пост\nи поделитесь им с миром',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.6)
                    : colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: isWeb ? 18 : 16,
                height: 1.6,
              ),
            ),
          ),
          // CTA кнопка
          if (showCta && onCtaPressed != null) ...[
            SizedBox(height: isWeb ? 32 : 24),
            Flexible(
              flex: 0,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCtaPressed,
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: Text(
                    ctaText ?? 'Создать первый пост',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: isWeb ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 40 : 32,
                      vertical: isWeb ? 18 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
          // Гибкий отступ
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

/// Баннер для пустой ленты (Feed)
class EmptyFeedBanner extends StatelessWidget {
  const EmptyFeedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPostsBanner(
      title: 'Лента пуста',
      subtitle: 'Подпишитесь на пользователей,\nчтобы видеть их посты здесь',
      icon: Icons.feed_outlined,
    );
  }
}

/// Баннер для пустых комментариев
class EmptyCommentsBanner extends StatelessWidget {
  const EmptyCommentsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPostsBanner(
      title: 'Нет комментариев',
      subtitle: 'Будьте первым,\nкто оставит комментарий',
      icon: Icons.chat_bubble_outline,
    );
  }
}

/// Баннер для пустого списка подписчиков/подписок
class EmptyFollowBanner extends StatelessWidget {
  final bool isFollowers;
  final int? followersCount;
  final VoidCallback? onFindPeoplePressed;

  const EmptyFollowBanner({
    super.key,
    this.isFollowers = true,
    this.followersCount,
    this.onFindPeoplePressed,
  });

  @override
  Widget build(BuildContext context) {
    // Мотивационный текст если есть подписчики
    final hasFollowers = followersCount != null && followersCount! > 0;
    
    return EmptyPostsBanner(
      title: isFollowers 
          ? (hasFollowers ? 'Пока нет новых подписчиков' : 'Нет подписчиков')
          : 'Нет подписок',
      subtitle: isFollowers
          ? (hasFollowers
              ? 'У вас уже $followersCount подписчик(а)!\nПокажите им, чем вы живёте'
              : 'Когда на вас подпишутся,\nони появятся здесь')
          : 'Когда вы подпишетесь на кого-то,\nон появится здесь',
      icon: isFollowers ? Icons.people_outline : Icons.person_add_outlined,
      ctaText: isFollowers ? 'Найти людей' : 'Подписаться',
      onCtaPressed: onFindPeoplePressed,
      showCta: isFollowers, // Показываем CTA только для подписчиков
    );
  }
}
