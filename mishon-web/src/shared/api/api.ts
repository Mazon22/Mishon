import { adminApi } from './domains/admin';
import { authApi } from './domains/auth';
import { chatsApi } from './domains/chats';
import { feedApi } from './domains/feed';
import { friendsApi } from './domains/friends';
import { notificationsApi } from './domains/notifications';
import { profileApi } from './domains/profile';
import { supportApi } from './domains/support';

export { HttpError } from './core/errors';
export { configureApi } from './core/session';

export const api = {
  admin: adminApi,
  auth: authApi,
  profile: profileApi,
  feed: feedApi,
  chats: chatsApi,
  friends: friendsApi,
  notifications: notificationsApi,
  support: supportApi,
};
