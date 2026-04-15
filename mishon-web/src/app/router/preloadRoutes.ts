export const importLoginPage = () => import('../../pages/login/LoginPage');
export const importAccountAccessPage = () => import('../../pages/login/AuthActionPage');
export const importAdminPage = () => import('../../pages/admin/AdminPage');
export const importFeedPage = () => import('../../pages/feed/FeedPage');
export const importPostDetailPage = () => import('../../pages/post/PostDetailPage');
export const importBookmarksPage = () => import('../../pages/bookmarks/BookmarksPage');
export const importChatsPage = () => import('../../pages/chats/ChatsPage');
export const importFriendsPage = () => import('../../pages/friends/FriendsPage');
export const importProfilePage = () => import('../../pages/profile/ProfilePage');
export const importNotificationsPage = () => import('../../pages/notifications/NotificationsPage');
export const importSettingsPage = () => import('../../pages/settings/SettingsPage');
export const importSupportPage = () => import('../../pages/support/SupportPage');

export function preloadAppRoutes() {
  void importLoginPage();
  void importAccountAccessPage();
  void importAdminPage();
  void importFeedPage();
  void importPostDetailPage();
  void importBookmarksPage();
  void importChatsPage();
  void importFriendsPage();
  void importProfilePage();
  void importNotificationsPage();
  void importSettingsPage();
  void importSupportPage();
}
