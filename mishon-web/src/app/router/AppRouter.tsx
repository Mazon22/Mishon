import { Suspense, lazy } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { AppSplash } from '../components/AppSplash';
import { useAuth } from '../providers/useAuth';
import {
  importAccountAccessPage,
  importAdminPage,
  importBookmarksPage,
  importChatsPage,
  importFeedPage,
  importFriendsPage,
  importLoginPage,
  importNotificationsPage,
  importPostDetailPage,
  importProfilePage,
  importSettingsPage,
  importSupportPage,
} from './preloadRoutes';
import { ProtectedRoute } from './ProtectedRoute';

const LoginPage = lazy(() => importLoginPage().then((module) => ({ default: module.LoginPage })));
const AuthActionPage = lazy(() => importAccountAccessPage().then((module) => ({ default: module.AuthActionPage })));
const AdminPage = lazy(() => importAdminPage().then((module) => ({ default: module.AdminPage })));
const FeedPage = lazy(() => importFeedPage().then((module) => ({ default: module.FeedPage })));
const PostDetailPage = lazy(() => importPostDetailPage().then((module) => ({ default: module.PostDetailPage })));
const BookmarksPage = lazy(() => importBookmarksPage().then((module) => ({ default: module.BookmarksPage })));
const ChatsPage = lazy(() => importChatsPage().then((module) => ({ default: module.ChatsPage })));
const FriendsPage = lazy(() => importFriendsPage().then((module) => ({ default: module.FriendsPage })));
const ProfilePage = lazy(() => importProfilePage().then((module) => ({ default: module.ProfilePage })));
const NotificationsPage = lazy(() => importNotificationsPage().then((module) => ({ default: module.NotificationsPage })));
const SettingsPage = lazy(() => importSettingsPage().then((module) => ({ default: module.SettingsPage })));
const SupportPage = lazy(() => importSupportPage().then((module) => ({ default: module.SupportPage })));

function RouteFallback() {
  return <AppSplash variant="fallback" />;
}

export function AppRouter() {
  const { profile } = useAuth();
  const currentUserId = profile?.id ?? 0;

  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/forgot-password" element={<AuthActionPage />} />
        <Route path="/reset-password" element={<AuthActionPage />} />
        <Route path="/verify-email" element={<AuthActionPage />} />
        <Route path="/verify-email/pending" element={<AuthActionPage />} />
        <Route
          path="/admin"
          element={
            <ProtectedRoute minimumRole="Admin" shellVariant="wide" subtitle="Пользователи, поддержка и действия модерации" title="Админка">
              <AdminPage />
            </ProtectedRoute>
          }
        />

        <Route
          path="/feed"
          element={
            <ProtectedRoute hideTopbar subtitle="Персональная лента и новые публикации" title="Лента">
              <FeedPage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />

        <Route
          path="/posts/:postId"
          element={
            <ProtectedRoute subtitle="Публикация, медиа и полное обсуждение" title="Публикация">
              <PostDetailPage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />

        <Route
          path="/bookmarks"
          element={
            <ProtectedRoute subtitle="Сохранённые публикации и быстрый доступ к ним" title="Закладки">
              <BookmarksPage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />

        <Route
          path="/chats"
          element={
            <ProtectedRoute shellVariant="messages" subtitle="Личные сообщения и пересланные публикации" title="Чаты">
              <ChatsPage />
            </ProtectedRoute>
          }
        />

        <Route
          path="/friends"
          element={
            <ProtectedRoute subtitle="Поиск людей, запросы и рекомендации" title="Люди">
              <FriendsPage />
            </ProtectedRoute>
          }
        />

        <Route
          path="/profile"
          element={
            <ProtectedRoute hideTopbar subtitle="Ваш профиль, медиа и активность" title="Профиль">
              <ProfilePage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />

        <Route
          path="/profile/:userId"
          element={
            <ProtectedRoute hideTopbar subtitle="Профиль пользователя, публикации и связи" title="Профиль">
              <ProfilePage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />

        <Route
          path="/notifications"
          element={
            <ProtectedRoute subtitle="Лайки, комментарии, заявки и сообщения" title="Уведомления">
              <NotificationsPage />
            </ProtectedRoute>
          }
        />

        <Route
          path="/settings"
          element={
            <ProtectedRoute subtitle="Профиль, приватность, сессии и безопасность" title="Настройки">
              <SettingsPage />
            </ProtectedRoute>
          }
        />

        <Route
          path="/support"
          element={
            <ProtectedRoute shellVariant="wide" subtitle="Ваши обращения и ответы команды поддержки" title="Поддержка">
              <SupportPage />
            </ProtectedRoute>
          }
        />

        <Route path="*" element={<Navigate replace to="/feed" />} />
      </Routes>
    </Suspense>
  );
}
