import 'package:flutter/material.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/theme/app_theme.dart';

enum AuthLegalDocumentType { terms, privacy, cookie }

class _LegalSectionData {
  final String title;
  final List<String> paragraphs;

  const _LegalSectionData({required this.title, required this.paragraphs});
}

class _LegalDocumentData {
  final String title;
  final List<_LegalSectionData> sections;

  const _LegalDocumentData({required this.title, required this.sections});
}

Future<void> showAuthLegalSheet(
  BuildContext context,
  AuthLegalDocumentType type,
) {
  final strings = AppStrings.of(context);
  final document = _buildLegalDocument(type, strings.isRu);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x260F1728),
    builder: (sheetContext) {
      final screenHeight = MediaQuery.sizeOf(sheetContext).height;

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0F4FB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1C2740),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.title,
                        style: Theme.of(
                          sheetContext,
                        ).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      tooltip:
                          MaterialLocalizations.of(
                            sheetContext,
                          ).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: const Color(0xFFF6F8FD),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final section in document.sections) ...[
                        Text(
                          section.title,
                          style: Theme.of(
                            sheetContext,
                          ).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final paragraph in section.paragraphs) ...[
                          Text(
                            paragraph,
                            style: Theme.of(
                              sheetContext,
                            ).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.56,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

_LegalDocumentData _buildLegalDocument(AuthLegalDocumentType type, bool isRu) {
  switch (type) {
    case AuthLegalDocumentType.terms:
      return _LegalDocumentData(
        title: isRu ? 'Условия использования' : 'Terms of Use',
        sections: [
          _LegalSectionData(
            title: isRu ? 'Как устроен доступ' : 'How access works',
            paragraphs: [
              isRu
                  ? 'Mishon — социальная платформа для общения, публикаций и обмена сообщениями. Этот временный документ описывает базовые правила использования сервиса, пока мы готовим финальную юридическую версию.'
                  : 'Mishon is a social platform for publishing, messaging, and connecting with people. This temporary document outlines the baseline rules while the final legal version is being prepared.',
              isRu
                  ? 'Создавая аккаунт, вы подтверждаете, что используете сервис добросовестно, не выдаёте себя за другого человека и не нарушаете применимые законы.'
                  : 'By creating an account, you confirm that you use the service in good faith, do not impersonate others, and do not violate applicable laws.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Контент и поведение' : 'Content and conduct',
            paragraphs: [
              isRu
                  ? 'Публикации, комментарии и сообщения не должны содержать спам, мошенничество, призывы к насилию, домогательства или незаконный контент. Нарушающие материалы могут быть скрыты или удалены.'
                  : 'Posts, comments, and messages must not include spam, fraud, violent threats, harassment, or illegal material. Violating content may be hidden or removed.',
              isRu
                  ? 'Мы также можем ограничить функциональность аккаунта или временно приостановить доступ, если заметим злоупотребление сервисом.'
                  : 'We may also limit account functionality or temporarily suspend access if we detect abuse of the service.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Изменения и поддержка' : 'Updates and support',
            paragraphs: [
              isRu
                  ? 'По мере развития Mishon правила и процессы могут обновляться. Когда появятся полноценные юридические страницы, этот временный текст будет заменён на постоянный документ.'
                  : 'As Mishon evolves, rules and processes may change. Once full legal pages are ready, this temporary text will be replaced with the permanent document.',
            ],
          ),
        ],
      );
    case AuthLegalDocumentType.privacy:
      return _LegalDocumentData(
        title: isRu ? 'Политика приватности' : 'Privacy Policy',
        sections: [
          _LegalSectionData(
            title: isRu ? 'Какие данные используются' : 'What data is used',
            paragraphs: [
              isRu
                  ? 'Для входа и работы аккаунта Mishon временно использует базовые данные: email, имя пользователя, настройки профиля, контент публикаций и техническую информацию о сессиях.'
                  : 'To sign you in and operate your account, Mishon temporarily uses core data such as email, username, profile settings, post content, and basic session metadata.',
              isRu
                  ? 'Эти сведения нужны, чтобы вы могли авторизоваться, видеть ленту, отправлять сообщения и восстанавливать доступ к аккаунту.'
                  : 'This information is required so you can authenticate, view the feed, send messages, and recover access to your account.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Как данные защищаются' : 'How data is protected',
            paragraphs: [
              isRu
                  ? 'Мы применяем технические меры для защиты сессий, API-доступа и учётных данных. Финальные правила хранения, удаления и экспорта данных будут подробно описаны в постоянной версии политики.'
                  : 'We apply technical safeguards to protect sessions, API access, and account credentials. Final retention, deletion, and export rules will be documented in the permanent policy.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Управление настройками' : 'Managing your settings',
            paragraphs: [
              isRu
                  ? 'Часть параметров приватности уже доступна в Mishon: видимость профиля, доступ к сообщениям, комментариям и статусу онлайн. Эти настройки обновляются вместе с вашим аккаунтом.'
                  : 'Some privacy controls are already available in Mishon, including profile visibility, messaging access, comments, and presence settings. These preferences sync with your account.',
            ],
          ),
        ],
      );
    case AuthLegalDocumentType.cookie:
      return _LegalDocumentData(
        title: isRu ? 'Политика cookie' : 'Cookie Policy',
        sections: [
          _LegalSectionData(
            title: isRu ? 'Зачем нужны cookie' : 'Why cookies are used',
            paragraphs: [
              isRu
                  ? 'Cookie и локальные токены помогают Mishon сохранять вход в аккаунт, удерживать активную сессию и запоминать локальные предпочтения интерфейса.'
                  : 'Cookies and local tokens help Mishon keep you signed in, maintain an active session, and remember local interface preferences.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Какие cookie используются' : 'What cookies are used',
            paragraphs: [
              isRu
                  ? 'Сейчас мы используем только минимально необходимые элементы для аутентификации, безопасности и стабильной работы приложения. По мере роста продукта политика будет расширена и описана точнее.'
                  : 'At the moment, we only rely on the minimum required elements for authentication, security, and application stability. As the product grows, this policy will be expanded with more detail.',
            ],
          ),
          _LegalSectionData(
            title: isRu ? 'Что можно изменить позже' : 'What may change later',
            paragraphs: [
              isRu
                  ? 'Когда появятся дополнительные сценарии аналитики и персонализации, мы вынесем их в полноценную политику cookie с более точным описанием категорий и управления согласием.'
                  : 'When analytics or personalization scenarios expand, we will replace this placeholder with a full cookie policy that clearly describes categories and consent controls.',
            ],
          ),
        ],
      );
  }
}
