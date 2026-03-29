import { Suspense, lazy } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { useAuth } from '../providers/useAuth';
import { ProtectedRoute } from './ProtectedRoute';

const LoginPage = lazy(() => import('../../pages/login/LoginPage').then((module) => ({ default: module.LoginPage })));
const FeedPage = lazy(() => import('../../pages/feed/FeedPage').then((module) => ({ default: module.FeedPage })));
const ChatsPage = lazy(() => import('../../pages/chats/ChatsPage').then((module) => ({ default: module.ChatsPage })));
const FriendsPage = lazy(() => import('../../pages/friends/FriendsPage').then((module) => ({ default: module.FriendsPage })));
const ProfilePage = lazy(() => import('../../pages/profile/ProfilePage').then((module) => ({ default: module.ProfilePage })));
const NotificationsPage = lazy(
  () => import('../../pages/notifications/NotificationsPage').then((module) => ({ default: module.NotificationsPage })),
);
const SettingsPage = lazy(() => import('../../pages/settings/SettingsPage').then((module) => ({ default: module.SettingsPage })));

function RouteFallback() {
  return <div className="splash-screen">Подготавливаем Mishon Web...</div>;
}

export function AppRouter() {
  const { profile } = useAuth();
  const currentUserId = profile?.id ?? 0;

  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/feed"
          element={
            <ProtectedRoute subtitle="Публикации и обновления" title="Лента">
              <FeedPage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />
        <Route
          path="/chats"
          element={
            <ProtectedRoute subtitle="Личные сообщения" title="Чаты">
              <ChatsPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/friends"
          element={
            <ProtectedRoute subtitle="Друзья, запросы и поиск людей" title="Друзья">
              <FriendsPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/profile"
          element={
            <ProtectedRoute subtitle="Ваш профиль и активность" title="Профиль">
              <ProfilePage currentUserId={currentUserId} />
            </ProtectedRoute>
          }
        />
        <Route
          path="/notifications"
          element={
            <ProtectedRoute subtitle="Лайки, комментарии и события" title="Уведомления">
              <NotificationsPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/settings"
          element={
            <ProtectedRoute subtitle="Тема, внешний вид и приватность" title="Настройки">
              <SettingsPage />
            </ProtectedRoute>
          }
        />
        <Route path="*" element={<Navigate replace to="/feed" />} />
      </Routes>
    </Suspense>
  );
}
