import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  static const supportedLocales = [Locale('ru'), Locale('en')];
  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(strings != null, 'AppStrings not found in context.');
    return strings!;
  }

  bool get isRu => locale.languageCode == 'ru';
  String get localeCode => isRu ? 'ru' : 'en';

  String get appName => 'Mishon';

  String get feed => isRu ? 'Лента' : 'Feed';
  String get people => isRu ? 'Люди' : 'People';
  String get friends => isRu ? 'Друзья' : 'Friends';
  String get chats => isRu ? 'Чаты' : 'Chats';
  String get profile => isRu ? 'Профиль' : 'Profile';

  String get errorTitle => isRu ? 'Ошибка' : 'Error';
  String pageNotFound(String path) =>
      isRu ? 'Страница не найдена: $path' : 'Page not found: $path';
  String get goHome => isRu ? 'На главную' : 'Go home';
  String get retry => isRu ? 'Повторить' : 'Retry';
  String get operationError =>
      isRu ? 'Не удалось выполнить действие' : 'Could not complete the action';

  String get settings => isRu ? 'Настройки' : 'Settings';
  String get settingsSubtitle =>
      isRu
          ? 'Язык и локальные параметры профиля.'
          : 'Language and local profile preferences.';
  String get language => isRu ? 'Язык' : 'Language';
  String get languageSubtitle =>
      isRu
          ? 'Выберите язык интерфейса приложения.'
          : 'Choose the interface language.';
  String get russian => isRu ? 'Русский' : 'Russian';
  String get english => 'English';
  String get interfaceSection => isRu ? 'Интерфейс' : 'Interface';
  String get interfaceSectionSubtitle =>
      isRu
          ? 'Небольшие локальные параметры для профиля.'
          : 'A few local preferences for the profile experience.';
  String get profileAutoRefresh =>
      isRu ? 'Автообновление профиля' : 'Profile auto refresh';
  String get profileAutoRefreshSubtitle =>
      isRu
          ? 'Обновлять профиль и статус каждые 15 секунд.'
          : 'Refresh profile data and presence every 15 seconds.';
  String get motionEffects => isRu ? 'Анимации' : 'Motion effects';
  String get motionEffectsSubtitle =>
      isRu
          ? 'Использовать плавные переходы на экранах профиля.'
          : 'Use smoother transitions in profile screens.';
  String get messagePreviews => isRu ? 'Превью сообщений' : 'Message previews';
  String get messagePreviewsSubtitle =>
      isRu
          ? 'Показывать короткие подсказки в интерфейсе.'
          : 'Show short hints in the interface.';

  String get couldNotLoadProfile =>
      isRu ? 'Не удалось загрузить профиль' : 'Could not load the profile';
  String get couldNotUpdateFollowStatus =>
      isRu ? 'Не удалось обновить подписку' : 'Could not update follow status';
  String get userBlockedYou =>
      isRu
          ? 'Этот пользователь вас заблокировал.'
          : 'This user has blocked you.';
  String get youBlockedUser =>
      isRu ? 'Вы заблокировали этого пользователя.' : 'You blocked this user.';
  String get couldNotOpenChat =>
      isRu ? 'Не удалось открыть чат' : 'Could not open chat';
  String get couldNotUpdateLike =>
      isRu ? 'Не удалось обновить реакцию' : 'Could not update the like';
  String get postDeleted => isRu ? 'Пост удалён' : 'Post deleted';
  String get couldNotDeletePost =>
      isRu ? 'Не удалось удалить пост' : 'Could not delete the post';
  String get couldNotPrepareImage =>
      isRu
          ? 'Не удалось подготовить изображение'
          : 'Could not prepare the image';
  String get profileMediaUpdated =>
      isRu ? 'Медиа профиля обновлено' : 'Profile media updated';
  String get couldNotUpdateProfileMedia =>
      isRu
          ? 'Не удалось обновить медиа профиля'
          : 'Could not update profile media';
  String shareNotConfigured(String username) =>
      isRu
          ? 'Поделиться профилем "$username" пока нельзя.'
          : 'Sharing for "$username" is not configured yet.';
  String get couldNotSaveProfile =>
      isRu ? 'Не удалось сохранить профиль' : 'Could not save the profile';

  String get saving => isRu ? 'Сохранение...' : 'Saving...';
  String get working => isRu ? 'Обработка...' : 'Working...';
  String get connectionConnecting => isRu ? 'Соединение...' : 'Connecting...';
  String get connectionUpdating => isRu ? 'Обновление...' : 'Updating...';
  String get connectionConnected => isRu ? 'Подключено' : 'Connected';
  String get bootstrapInitializingServices =>
      isRu
          ? 'Инициализация защищённой сессии и основных сервисов'
          : 'Initializing secure session and essential services';
  String get bootstrapCheckingNetwork =>
      isRu ? 'Проверяем доступность сети' : 'Checking network availability';
  String get bootstrapRestoringCache =>
      isRu ? 'Восстанавливаем кэшированные данные' : 'Restoring cached data';
  String get bootstrapPreloadingData =>
      isRu
          ? 'Предзагружаем ленту, чаты и профиль'
          : 'Preloading your feed, chats, and profile';
  String get bootstrapPreparingApp =>
      isRu ? 'Подготавливаем приложение' : 'Preparing the application';
  String get about => isRu ? 'О себе' : 'About';
  String get edit => isRu ? 'Редактировать' : 'Edit';
  String get editProfile => isRu ? 'Изменить профиль' : 'Edit profile';
  String get message => isRu ? 'Сообщение' : 'Message';
  String get follow => isRu ? 'Подписаться' : 'Follow';
  String get followingLabel => isRu ? 'Вы подписаны' : 'Following';
  String get posts => isRu ? 'Посты' : 'Posts';
  String get followers => isRu ? 'Подписчики' : 'Followers';
  String get following => isRu ? 'Подписки' : 'Following';
  String get media => isRu ? 'Медиа' : 'Media';
  String get likes => isRu ? 'Лайки' : 'Likes';
  String get share => isRu ? 'Поделиться' : 'Share';
  String get unfollow => isRu ? 'Отписаться' : 'Unfollow';
  String get deletePost => isRu ? 'Удалить пост' : 'Delete post';
  String get postShort => isRu ? 'Пост' : 'Post';
  String get forYou => isRu ? 'Для вас' : 'For You';
  String get feedSubtitle =>
      isRu
          ? 'Переключайтесь между персональными рекомендациями и лентой по подпискам.'
          : 'Switch between ranked recommendations and strict subscriptions.';
  String get forYouFeedDescription =>
      isRu
          ? 'Сортировка по свежести, вовлеченности, взаимодействиям и трендам.'
          : 'Ranked by recency, engagement, people you interact with, and trending momentum.';
  String get followingFeedDescription =>
      isRu
          ? 'Только новые посты от людей, на которых вы подписаны, в строгом хронологическом порядке.'
          : 'Newest posts only from people you follow, sorted by time.';
  String get feedRecommendationsWarmupTitle =>
      isRu
          ? 'Рекомендации настраиваются'
          : 'Your recommendations are warming up';
  String get feedFollowingEmptyTitle =>
      isRu ? 'Пока нет постов по подпискам' : 'No subscription posts yet';
  String get feedRecommendationsWarmupSubtitle =>
      isRu
          ? 'Подпишитесь на больше людей и взаимодействуйте с постами, чтобы Mishon лучше понимал ваши интересы.'
          : 'Follow more people and interact with posts so Mishon can personalize your feed.';
  String get feedFollowingEmptySubtitle =>
      isRu
          ? 'Когда люди, на которых вы подписаны, опубликуют новый пост, он появится здесь.'
          : 'When people you follow publish something, it will appear here in chronological order.';
  String get feedShowingCachedPosts =>
      isRu
          ? 'Показаны последние загруженные посты. Потяните вниз, чтобы попробовать еще раз.'
          : 'Showing your last loaded posts. Pull to try again.';
  String get feedLoadFailedTitle =>
      isRu ? 'Не удалось загрузить ленту' : 'Couldn\'t load the feed';
  String shareForHandleUnavailable(String handle) =>
      isRu
          ? 'Поделиться постом @$handle пока нельзя.'
          : 'Share for @$handle is not connected yet.';
  String get feedCheckConnection =>
      isRu
          ? 'Проверьте соединение и попробуйте снова.'
          : 'Check your connection and try again.';
  String get noInternetConnectionRightNow =>
      isRu
          ? 'Сейчас нет подключения к интернету.'
          : 'No internet connection right now.';
  String get feedLoadGenericError =>
      isRu
          ? 'При загрузке ленты что-то пошло не так.'
          : 'Something went wrong while loading your feed.';
  String get chatSwipeHint =>
      isRu
          ? 'Свайп вправо закрепляет, влево архивирует'
          : 'Right swipe pins, left swipe archives';
  String get chatSettings => isRu ? 'Настройки чата' : 'Chat settings';
  String get typing => isRu ? 'Печатает...' : 'Typing...';
  String get youCannotSendMessagesToThisUser =>
      isRu
          ? 'Вы не можете писать этому пользователю.'
          : 'You cannot send messages to this user.';
  String get unblockUserFirst =>
      isRu ? 'Сначала разблокируйте пользователя.' : 'Unblock the user first.';
  String get messageUpdated => isRu ? 'Сообщение обновлено' : 'Message updated';
  String get failedToSaveMessage =>
      isRu ? 'Не удалось сохранить сообщение.' : 'Failed to save the message.';
  String get attachment => isRu ? 'Вложение' : 'Attachment';
  String get failedToSendMessage =>
      isRu ? 'Не удалось отправить сообщение.' : 'Failed to send the message.';
  String get unblockUser =>
      isRu ? 'Разблокировать пользователя' : 'Unblock user';
  String get deleteForMe => isRu ? 'Удалить у меня' : 'Delete for me';
  String get deleteForEveryone =>
      isRu ? 'Удалить у всех' : 'Delete for everyone';
  String get uploading => isRu ? 'Загружается...' : 'Uploading...';
  String uploadingWithProgress(int progress) =>
      isRu ? 'Загружается $progress%' : 'Uploading $progress%';
  String get sendingMessage => isRu ? 'Отправляется...' : 'Sending...';
  String get failedStatus => isRu ? 'Ошибка' : 'Failed';
  String get nowShort => isRu ? 'сейчас' : 'now';
  String minutesShort(int minutes) => isRu ? '$minutes мин' : '${minutes}m';
  String hoursShort(int hours) => isRu ? '$hours ч' : '${hours}h';
  String daysShort(int days) => isRu ? '$days д' : '${days}d';
  String visibleNow(int count) =>
      isRu ? '$count видно сейчас' : '$count visible now';
  String get noPostsYet => isRu ? 'Пока нет постов' : 'No posts yet';
  String get firstPostPrompt =>
      isRu
          ? 'Ваш профиль готов к первому посту.'
          : 'Your profile is ready for the first post.';
  String get profileHasNoPosts =>
      isRu
          ? 'Этот профиль ещё ничего не публиковал.'
          : 'This profile has not posted anything yet.';
  String get createPost => isRu ? 'Создать пост' : 'Create post';
  String get profileNotFound =>
      isRu ? 'Профиль не найден' : 'Profile not found';
  String get noMediaYet => isRu ? 'Пока нет медиа' : 'No media yet';
  String get mediaWillAppearHere =>
      isRu
          ? 'Изображения из постов появятся здесь.'
          : 'Images from posts will appear here.';
  String get nothingLikedYet =>
      isRu ? 'Пока ничего не понравилось' : 'Nothing liked yet';
  String get likedPostsWillAppearHere =>
      isRu
          ? 'Посты, которые вам понравились в этом профиле, появятся здесь.'
          : 'Posts you liked in this profile will surface here.';

  String get logoutQuestion => isRu ? 'Выйти из аккаунта?' : 'Log out?';
  String get logoutContent =>
      isRu
          ? 'Вы вернётесь на экран входа.'
          : 'You will be taken back to the login screen.';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get logout => isRu ? 'Выйти' : 'Log out';
  String get deletePostQuestion =>
      isRu ? 'Удалить этот пост?' : 'Delete this post?';
  String get actionCannotBeUndone =>
      isRu ? 'Это действие нельзя отменить.' : 'This action cannot be undone.';
  String get delete => isRu ? 'Удалить' : 'Delete';

  String get online => isRu ? 'онлайн' : 'online';
  String lastSeenAt(String time) =>
      isRu ? 'был в сети $time' : 'last seen at $time';
  String lastSeenYesterdayAt(String time) =>
      isRu ? 'был в сети вчера в $time' : 'last seen yesterday at $time';
  String lastSeenDaysAgoAt(int days, String time) =>
      isRu
          ? 'был в сети $days д. назад в $time'
          : 'last seen $days d. ago at $time';

  String get profileSetupTitle => isRu ? 'Изменить профиль' : 'Edit profile';
  String get profileSetupSectionTitle => isRu ? 'Профиль' : 'Profile';
  String get profileSetupSectionSubtitle =>
      isRu
          ? 'Сделайте профиль узнаваемым. Имя пользователя и описание помогают людям найти вас в Mishon.'
          : 'Keep it minimal and recognizable. Username and bio update how people find you in Mishon.';
  String get username => isRu ? 'Имя пользователя' : 'Username';
  String get usernameHint => 'username';
  String get aboutHint =>
      isRu
          ? 'Расскажите немного о себе'
          : 'Tell people a little about yourself';
  String get changeAvatar => isRu ? 'Сменить аватар' : 'Change avatar';
  String get removeAvatar => isRu ? 'Удалить аватар' : 'Remove avatar';
  String get changeBanner => isRu ? 'Сменить баннер' : 'Change banner';
  String get removeBanner => isRu ? 'Удалить баннер' : 'Remove banner';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get usernameMinLength =>
      isRu
          ? 'Минимальная длина - 5 символов.'
          : 'Minimum length is 5 characters.';
  String get usernameInvalid =>
      isRu
          ? 'Имя пользователя может содержать только a-z, 0-9, . или _'
          : 'Username must contain only a-z, 0-9, . or _';
  String get checkingUsername =>
      isRu ? 'Проверяем имя пользователя...' : 'Checking username...';
  String get usernameAvailable =>
      isRu ? 'Имя пользователя доступно' : 'Username available';
  String get usernameUnavailable =>
      isRu
          ? 'Это имя пользователя уже занято.'
          : 'This username is already taken.';
  String get usernameVerifyFailed =>
      isRu
          ? 'Не удалось проверить имя пользователя.'
          : 'Could not verify username right now.';

  String get noFollowersYet =>
      isRu ? 'Пока нет подписчиков' : 'No followers yet';
  String get noFollowingYet => isRu ? 'Пока нет подписок' : 'No following yet';
  String get followersWillAppearHere =>
      isRu
          ? 'Когда на вас подпишутся, они появятся здесь.'
          : 'Followers will appear here when people subscribe to you.';
  String get followingWillAppearHere =>
      isRu
          ? 'Когда вы подпишетесь на кого-то, они появятся здесь.'
          : 'People you follow will appear here.';

  String formatShortTime(DateTime dateTime) =>
      DateFormat('HH:mm', localeCode).format(dateTime);

  String formatMonthDay(DateTime dateTime) =>
      DateFormat('dd MMM', localeCode).format(dateTime);
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
