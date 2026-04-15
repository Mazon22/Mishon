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
          ? 'Сделайте профиль узнаваемым. Отображаемое имя, username и описание помогают людям найти вас в Mishon.'
          : 'Keep it minimal and recognizable. Display name, username, and bio help people find you in Mishon.';
  String get displayName => isRu ? 'Отображаемое имя' : 'Display name';
  String get displayNameHint => isRu ? 'Ваше имя' : 'Your name';
  String get displayNameHelperText =>
      isRu
          ? 'Имя, которое показывается над @username.'
          : 'The name shown above your @username.';
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
  String get checkingEmail => isRu ? 'Проверяем email...' : 'Checking email...';
  String get emailAvailable => isRu ? 'Email доступен' : 'Email available';
  String get emailUnavailable =>
      isRu ? 'Этот email уже используется.' : 'This email is already in use.';
  String get emailVerifyFailed =>
      isRu
          ? 'Не удалось проверить email.'
          : 'Could not verify email right now.';

  String get noFollowersYet =>
      isRu ? 'Пока нет подписчиков' : 'No followers yet';
  String get noFollowingYet => isRu ? 'Пока нет подписок' : 'No following yet';
  String get noFriendsYet => isRu ? 'Пока нет друзей' : 'No friends yet';
  String get followersWillAppearHere =>
      isRu
          ? 'Когда на вас подпишутся, они появятся здесь.'
          : 'Followers will appear here when people subscribe to you.';
  String get followingWillAppearHere =>
      isRu
          ? 'Когда вы подпишетесь на кого-то, они появятся здесь.'
          : 'People you follow will appear here.';
  String get friendsWillAppearHere =>
      isRu ? 'Ваши друзья появятся здесь.' : 'Your friends will appear here.';

  String get signInTitle => isRu ? 'Вход' : 'Sign in';
  String get signInSubtitle =>
      isRu ? 'Продолжите работу с аккаунтом.' : 'Continue with your account.';
  String get signInAction => isRu ? 'Войти' : 'Sign in';
  String get signUpAction => isRu ? 'Регистрация' : 'Sign up';
  String get continueWithGoogle =>
      isRu ? 'Продолжить через Google' : 'Continue with Google';
  String get continueWithApple =>
      isRu ? 'Продолжить через Apple' : 'Continue with Apple';
  String get orDivider => isRu ? 'или' : 'or';
  String get noAccountLabel =>
      isRu ? 'Ещё нет аккаунта?' : 'Don\'t have an account?';
  String get forgotPasswordAction =>
      isRu ? 'Забыли пароль?' : 'Forgot password?';
  String get createAccountTitle => isRu ? 'Создать аккаунт' : 'Create account';
  String get createAccountSubtitle =>
      isRu
          ? 'Создайте аккаунт и начните общение.'
          : 'Create your account and start connecting.';
  String get alreadyHaveAccountLabel =>
      isRu ? 'Уже есть аккаунт?' : 'Already have an account?';
  String get createAccountAction => isRu ? 'Создать аккаунт' : 'Create account';
  String get legalLead =>
      isRu
          ? 'Создавая аккаунт, вы принимаете'
          : 'By creating an account, you agree to';
  String get legalAnd => isRu ? 'и' : 'and';
  String get legalTermsLink => isRu ? 'условия' : 'terms';
  String get legalPrivacyLink =>
      isRu ? 'политику приватности' : 'privacy policy';
  String get legalCookieLink => isRu ? 'cookie' : 'cookie policy';
  String socialProviderComingSoon(String provider) =>
      isRu
          ? 'Вход через $provider скоро появится. Пока используйте email и пароль.'
          : '$provider sign in is coming soon. For now, use email and password.';
  String get chooseUsernameValidation =>
      isRu ? 'Придумайте username.' : 'Choose a username.';
  String get usernameMinThreeValidation =>
      isRu ? 'Минимум 5 символов.' : 'Use at least 5 characters.';
  String get usernameMaxFiftyValidation =>
      isRu ? 'Максимум 32 символа.' : 'Use 32 characters or fewer.';
  String get usernameCharactersValidation =>
      isRu
          ? 'Используйте только строчные a-z, цифры, точки и подчёркивания. Без точки в начале или конце и без двойных точек.'
          : 'Use lowercase a-z, numbers, dots, and underscores. No leading, trailing, or double dots.';
  String get usernameHelperText =>
      isRu
          ? 'От 5 до 32 символов: строчные a-z, цифры, точки и подчёркивания.'
          : '5 to 32 characters: lowercase letters, numbers, dots, and underscores.';
  String get passwordUppercaseValidation =>
      isRu
          ? 'Добавьте хотя бы одну заглавную букву.'
          : 'Include at least one uppercase letter.';
  String get passwordLowercaseValidation =>
      isRu
          ? 'Добавьте хотя бы одну строчную букву.'
          : 'Include at least one lowercase letter.';
  String get passwordNumberValidation =>
      isRu ? 'Добавьте хотя бы одну цифру.' : 'Include at least one number.';
  String get passwordHelperText =>
      isRu
          ? 'Минимум 8 символов, с буквой в верхнем и нижнем регистре и цифрой.'
          : 'At least 8 characters with uppercase, lowercase, and a number.';
  String get emailAddress => isRu ? 'Email' : 'Email';
  String get passwordLabel => isRu ? 'Пароль' : 'Password';
  String get passwordHint => isRu ? 'Введите пароль' : 'Enter your password';
  String get enterEmailValidation =>
      isRu ? 'Введите email.' : 'Enter your email.';
  String get emailInvalidValidation =>
      isRu ? 'Введите корректный email.' : 'Enter a valid email address.';
  String get enterPasswordValidation =>
      isRu ? 'Введите пароль.' : 'Enter your password.';
  String get passwordLengthValidation =>
      isRu ? 'Минимум 8 символов.' : 'Use at least 8 characters.';
  String get confirmPasswordValidation =>
      isRu ? 'Подтвердите пароль.' : 'Confirm your password.';
  String get passwordMismatchValidation =>
      isRu ? 'Пароли не совпадают.' : 'Passwords do not match.';
  String get newPasswordLabel => isRu ? 'Новый пароль' : 'New password';
  String get newPasswordHint =>
      isRu ? 'Придумайте новый пароль' : 'Create a new password';
  String get confirmNewPasswordLabel =>
      isRu ? 'Подтвердите новый пароль' : 'Confirm new password';
  String get confirmPasswordHint =>
      isRu ? 'Повторите пароль' : 'Repeat your password';
  String get backToLogin => isRu ? 'Вернуться ко входу' : 'Back to login';
  String get rememberedPassword =>
      isRu ? 'Вспомнили пароль?' : 'Remembered your password?';
  String get forgotPasswordTitle =>
      isRu ? 'Восстановление пароля' : 'Forgot password';
  String get forgotPasswordSubtitle =>
      isRu
          ? 'Введите email, и мы отправим ссылку.'
          : 'Enter your email and we will send a reset link.';
  String get forgotPasswordSuccessTitle =>
      isRu ? 'Проверьте почту' : 'Check your email';
  String get forgotPasswordSuccessSubtitle =>
      isRu
          ? 'Если аккаунт существует, письмо для сброса уже в пути.'
          : 'If the account exists, a reset email is already on the way.';
  String get sendResetLink => isRu ? 'Отправить ссылку' : 'Send reset link';
  String get resetPasswordTitle => isRu ? 'Сброс пароля' : 'Reset password';
  String get resetPasswordSubtitle =>
      isRu
          ? 'Задайте новый пароль для входа.'
          : 'Set a new password to sign in.';
  String get resetPasswordAction => isRu ? 'Сохранить пароль' : 'Save password';
  String get resetPasswordSuccessTitle =>
      isRu ? 'Пароль обновлён' : 'Password updated';
  String get resetPasswordSuccessSubtitle =>
      isRu
          ? 'Теперь можно войти с новым паролем.'
          : 'You can now sign in with your new password.';
  String get invalidOrExpiredResetLink =>
      isRu
          ? 'Ссылка недействительна или истекла.'
          : 'The link is invalid or expired.';
  String get verifyEmailPendingTitle =>
      isRu ? 'Подтвердите email' : 'Verify your email';
  String verifyEmailPendingSubtitle(String email) =>
      isRu
          ? 'Мы отправили письмо на $email. Откройте ссылку из письма, чтобы продолжить.'
          : 'We sent a verification email to $email. Open the link in that email to continue.';
  String get resendVerificationEmail =>
      isRu ? 'Отправить письмо ещё раз' : 'Resend verification email';
  String get verificationEmailResent =>
      isRu ? 'Письмо отправлено повторно.' : 'Verification email sent again.';
  String get continueToApp => isRu ? 'Продолжить' : 'Continue';
  String get verificationLinkInvalid =>
      isRu
          ? 'Ссылка подтверждения недействительна.'
          : 'The verification link is invalid.';
  String get verificationInProgressTitle =>
      isRu ? 'Подтверждаем email' : 'Verifying email';
  String get verificationSuccessTitle =>
      isRu ? 'Email подтверждён' : 'Email verified';
  String get verificationSuccessSubtitle =>
      isRu
          ? 'Теперь доступны все функции аккаунта.'
          : 'Your full account access is now unlocked.';
  String get verificationFailedTitle =>
      isRu ? 'Не удалось подтвердить email' : 'Could not verify email';
  String get onboardingTitle => isRu ? 'Онбординг' : 'Onboarding';
  String get onboardingSubtitle =>
      isRu
          ? 'Давайте быстро доведём профиль и уведомления до рабочего состояния.'
          : 'Let\'s quickly finish your profile and notification setup.';
  String get onboardingProfileStepTitle => isRu ? 'Профиль' : 'Profile';
  String get onboardingProfileStepSubtitle =>
      isRu
          ? 'Добавьте аватар, описание и сделайте профиль узнаваемым.'
          : 'Add an avatar, a bio, and make your profile recognizable.';
  String get onboardingProfileMissingHint =>
      isRu ? 'Добавьте пару слов о себе.' : 'Add a short intro about yourself.';
  String get onboardingSuggestionsStepTitle =>
      isRu ? 'Рекомендации' : 'Suggested people';
  String get onboardingSuggestionsStepSubtitle =>
      isRu
          ? 'Подпишитесь на несколько людей, чтобы рекомендации стали точнее.'
          : 'Follow a few people to improve recommendations.';
  String get noSuggestionsAvailable =>
      isRu
          ? 'Рекомендации появятся чуть позже.'
          : 'Suggestions will appear shortly.';
  String get suggestedPeopleHint =>
      isRu
          ? 'Новый профиль для знакомства.'
          : 'A fresh profile to connect with.';
  String get onboardingNotificationsStepTitle =>
      isRu ? 'Уведомления' : 'Notifications';
  String get onboardingNotificationsStepSubtitle =>
      isRu
          ? 'Разрешите push, чтобы не пропускать сообщения и запросы.'
          : 'Enable push so you do not miss messages and requests.';
  String get notificationsEnabled =>
      isRu ? 'Push-уведомления включены.' : 'Push notifications are enabled.';
  String get notificationsPermissionDenied =>
      isRu
          ? 'Разрешение на уведомления отклонено.'
          : 'Notification permission was denied.';
  String get notificationsOptInHint =>
      isRu
          ? 'Уведомления пока не настроены.'
          : 'Notifications are not configured yet.';
  String get notificationsOptInAction =>
      isRu ? 'Включить уведомления' : 'Enable notifications';
  String get onboardingVerificationStepTitle =>
      isRu ? 'Подтверждение email' : 'Email verification';
  String get onboardingVerificationStepSubtitle =>
      isRu
          ? 'Подтвердите email, чтобы убрать ограничения на аккаунте.'
          : 'Verify your email to remove account restrictions.';
  String get emailAlreadyVerified =>
      isRu ? 'Email уже подтверждён.' : 'Your email is already verified.';
  String get completeOnboarding =>
      isRu ? 'Завершить онбординг' : 'Complete onboarding';
  String get skipForNow => isRu ? 'Позже' : 'Skip for now';
  String get activeSessionsTitle =>
      isRu ? 'Активные сессии' : 'Active sessions';
  String get currentSessionCannotBeRevoked =>
      isRu
          ? 'Текущую сессию нельзя отозвать отсюда.'
          : 'You cannot revoke the current session from here.';
  String get sessionRevoked => isRu ? 'Сессия отозвана.' : 'Session revoked.';
  String get noOtherSessions =>
      isRu ? 'Других сессий нет.' : 'There are no other sessions.';
  String get otherSessionsLoggedOut =>
      isRu ? 'Остальные сессии завершены.' : 'Other sessions were logged out.';
  String get logoutOtherSessions =>
      isRu ? 'Выйти на других устройствах' : 'Log out other devices';
  String get logoutAllSessionsAction => isRu ? 'Выйти везде' : 'Log out all';
  String get unknownDevice =>
      isRu ? 'Неизвестное устройство' : 'Unknown device';
  String get currentSessionChip => isRu ? 'Текущая' : 'Current';
  String get platformLabel => isRu ? 'Платформа' : 'Platform';
  String get unknownPlatform => isRu ? 'Неизвестно' : 'Unknown';
  String get lastUsedLabel => isRu ? 'Последняя активность' : 'Last used';
  String get signedInLabel => isRu ? 'Вход выполнен' : 'Signed in';
  String get sessionExpiresLabel => isRu ? 'Истекает' : 'Expires';
  String get ipAddressLabel => 'IP';
  String get revokeSessionAction => isRu ? 'Завершить' : 'Revoke';
  String get privacyTitle => isRu ? 'Приватность' : 'Privacy';
  String get privacyCardSubtitle =>
      isRu
          ? 'Кто видит профиль, пишет вам и видит ваш онлайн.'
          : 'Control who can see your profile, contact you, and view your presence.';
  String get privateAccountTitle =>
      isRu ? 'Закрытый аккаунт' : 'Private account';
  String get privateAccountSubtitle =>
      isRu
          ? 'Новые подписчики будут отправлять запрос.'
          : 'New followers will have to send a request.';
  String get privateAccountShort => isRu ? 'Закрыт' : 'Private';
  String get publicAccountShort => isRu ? 'Открыт' : 'Public';
  String get profileVisibilityTitle =>
      isRu ? 'Видимость профиля' : 'Profile visibility';
  String get profileVisibilitySubtitle =>
      isRu ? 'Кто может открыть ваш профиль.' : 'Who can open your profile.';
  String get messagePrivacyTitle =>
      isRu ? 'Кто может писать' : 'Who can message you';
  String get messagePrivacySubtitle =>
      isRu
          ? 'Ограничьте входящие диалоги.'
          : 'Limit who can start chats with you.';
  String get commentPrivacyTitle =>
      isRu ? 'Кто может комментировать' : 'Who can comment';
  String get commentPrivacySubtitle =>
      isRu
          ? 'Настройте доступ к комментариям.'
          : 'Choose who can comment on your posts.';
  String get presencePrivacyTitle =>
      isRu ? 'Видимость онлайна' : 'Presence visibility';
  String get presencePrivacySubtitle =>
      isRu
          ? 'Кто видит ваш онлайн и last active.'
          : 'Choose who can see your online and last active status.';
  String get privacyAudienceEveryone => isRu ? 'Все' : 'Everyone';
  String get privacyAudienceFollowers => isRu ? 'Подписчики' : 'Followers';
  String get privacyAudienceFriends => isRu ? 'Друзья' : 'Friends';
  String get privacyAudienceNobody => isRu ? 'Никто' : 'Nobody';
  String get privacyAudiencePublic =>
      isRu ? 'Открытый профиль' : 'Public profile';
  String get privacySaved =>
      isRu ? 'Настройки приватности сохранены.' : 'Privacy settings saved.';
  String get followRequestsTitle =>
      isRu ? 'Запросы на подписку' : 'Follow requests';
  String get followRequestsSubtitle =>
      isRu
          ? 'Входящие запросы на доступ к закрытому профилю.'
          : 'Incoming requests to access your private profile.';
  String get noFollowRequestsTitle =>
      isRu ? 'Запросов пока нет' : 'No follow requests yet';
  String get noFollowRequestsSubtitle =>
      isRu ? 'Новые запросы появятся здесь.' : 'New requests will appear here.';
  String get followRequestDefaultHint =>
      isRu
          ? 'Хочет подписаться на ваш профиль.'
          : 'Wants to follow your profile.';
  String get approveAction => isRu ? 'Принять' : 'Approve';
  String get rejectAction => isRu ? 'Отклонить' : 'Reject';
  String get moderationTitle => isRu ? 'Модерация' : 'Moderation';
  String get moderationCardSubtitle =>
      isRu
          ? 'Жалобы, санкции и роль модератора.'
          : 'Reports, sanctions, and moderator tools.';
  String get moderationUnavailableTitle =>
      isRu ? 'Доступ только для модераторов' : 'Moderators only';
  String get moderationUnavailableSubtitle =>
      isRu
          ? 'Этот раздел открыт только для Moderator/Admin.'
          : 'This section is available only to Moderator/Admin roles.';
  String get noModeratorNote =>
      isRu ? 'Дополнительной заметки нет.' : 'No extra note was provided.';
  String get statusLabel => isRu ? 'Статус' : 'Status';
  String get resolutionLabel => isRu ? 'Решение' : 'Resolution';
  String get targetLabel => isRu ? 'Цель' : 'Target';
  String get assignToMeAction => isRu ? 'Назначить на меня' : 'Assign to me';
  String get resolveReportAction => isRu ? 'Закрыть жалобу' : 'Resolve report';
  String get warnUserAction => isRu ? 'Предупредить' : 'Warn';
  String get suspendUserAction => isRu ? 'Заморозить' : 'Suspend';
  String get banUserAction => isRu ? 'Забанить' : 'Ban';
  String get unbanUserAction => isRu ? 'Разбанить' : 'Unban';
  String get assignModeratorAction =>
      isRu ? 'Назначить модератором' : 'Assign moderator';
  String get removeModeratorAction =>
      isRu ? 'Снять модератора' : 'Remove moderator';
  String get resolutionWarning => isRu ? 'Предупреждение' : 'Warning issued';
  String get resolutionContentHidden =>
      isRu ? 'Скрыть контент' : 'Hide content';
  String get resolutionContentRemoved =>
      isRu ? 'Удалить контент' : 'Remove content';
  String get resolutionUserSuspended =>
      isRu ? 'Временно заморозить' : 'Suspend user';
  String get resolutionUserBanned =>
      isRu ? 'Забанить пользователя' : 'Ban user';
  String get resolutionRejected => isRu ? 'Отклонить жалобу' : 'Reject report';
  String get optionalModeratorNote =>
      isRu ? 'Заметка модератора' : 'Moderator note';
  String get noReportsTitle => isRu ? 'Жалоб нет' : 'No reports';
  String get noReportsSubtitle =>
      isRu ? 'Список жалоб сейчас пуст.' : 'There are no reports right now.';
  String get openReportDetails => isRu ? 'Открыть' : 'Open';
  String get adminShort => isRu ? 'Admin' : 'Admin';
  String get moderatorShort => isRu ? 'Moderator' : 'Moderator';
  String get loadMore => isRu ? 'Показать ещё' : 'Load more';

  String get reportAction => isRu ? 'Пожаловаться' : 'Report';
  String get reportUserAction =>
      isRu ? 'Пожаловаться на пользователя' : 'Report user';
  String get reportPostAction => isRu ? 'Пожаловаться на пост' : 'Report post';
  String get reportCommentAction =>
      isRu ? 'Пожаловаться на комментарий' : 'Report comment';
  String get reportMessageAction =>
      isRu ? 'Пожаловаться на сообщение' : 'Report message';
  String get reportReasonLabel => isRu ? 'Причина' : 'Reason';
  String get reportNoteLabel =>
      isRu ? 'Комментарий (необязательно)' : 'Note (optional)';
  String get reportSubmitted =>
      isRu ? 'Жалоба отправлена.' : 'Report submitted.';
  String get reportTargetUserTitle =>
      isRu ? 'Жалоба на пользователя' : 'Report user';
  String get reportTargetPostTitle => isRu ? 'Жалоба на пост' : 'Report post';
  String get reportTargetCommentTitle =>
      isRu ? 'Жалоба на комментарий' : 'Report comment';
  String get reportTargetMessageTitle =>
      isRu ? 'Жалоба на сообщение' : 'Report message';
  String get reasonSpam => isRu ? 'Спам' : 'Spam';
  String get reasonHarassment => isRu ? 'Оскорбления' : 'Harassment';
  String get reasonHateSpeech => isRu ? 'Язык ненависти' : 'Hate speech';
  String get reasonViolence => isRu ? 'Насилие' : 'Violence';
  String get reasonNudity => isRu ? 'Нагота' : 'Nudity';
  String get reasonScam => isRu ? 'Мошенничество' : 'Scam';
  String get reasonImpersonation =>
      isRu ? 'Выдача себя за другого' : 'Impersonation';
  String get reasonSelfHarm => isRu ? 'Самоповреждение' : 'Self-harm';
  String get reasonPrivacyViolation =>
      isRu ? 'Нарушение приватности' : 'Privacy violation';
  String get reasonIllegalContent =>
      isRu ? 'Незаконный контент' : 'Illegal content';
  String get reasonSuspiciousActivity =>
      isRu ? 'Подозрительная активность' : 'Suspicious activity';
  String get reasonOther => isRu ? 'Другое' : 'Other';
  String get requestPendingLabel => isRu ? 'Запрос отправлен' : 'Request sent';
  String get cancelRequestAction => isRu ? 'Отменить запрос' : 'Cancel request';
  String get privateProfileLockedTitle =>
      isRu ? 'Профиль закрыт' : 'Private profile';
  String get privateProfileLockedSubtitle =>
      isRu
          ? 'Владелец профиля ограничил доступ к публикациям и разделам профиля.'
          : 'This profile is private and limits access to posts and profile details.';
  String get followRequestPendingSubtitle =>
      isRu
          ? 'Запрос уже отправлен. Доступ откроется после одобрения.'
          : 'Your follow request is pending approval.';
  String get verifyEmailAction => isRu ? 'Подтвердить email' : 'Verify email';
  String get verifyEmailReminderTitle =>
      isRu
          ? 'Подтвердите email для полного доступа'
          : 'Verify your email for full access';
  String get verifyEmailReminderSubtitle =>
      isRu
          ? 'Некоторые действия остаются ограничены, пока email не подтверждён.'
          : 'Some actions stay limited until your email is verified.';
  String get commentRemovedLabel =>
      isRu ? 'Комментарий удалён' : 'Comment removed';
  String get contentHiddenLabel =>
      isRu ? 'Контент скрыт модерацией' : 'Content hidden by moderation';
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
