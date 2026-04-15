import type { Comment, CommentListQuery, PagedResponse, Post } from '../../types/api';
import { client, compatClient } from '../core/client';
import {
  asRecord,
  normalizeComment,
  normalizeMobileComment,
  normalizeMobilePost,
  normalizePost,
} from '../core/normalizers';

export const feedApi = {
  async list(mode: 'for-you' | 'following', page = 1, pageSize = 12) {
    const response = await client.get<PagedResponse<Post>>('/feed', {
      params: { page, pageSize, mode: mode === 'following' ? 'following' : undefined },
    });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizePost(item)),
    };
  },
  async create(content: string, imageUrl?: string, imageFile?: File | null) {
    if (imageFile) {
      const formData = new FormData();
      formData.append('content', content);
      formData.append('image', imageFile);
      const response = await compatClient.post('/posts', formData, {
        timeout: 90000,
      });
      return normalizeMobilePost(asRecord(response.data));
    }

    const response = await client.post<Post>('/posts', { content, imageUrl });
    return normalizePost(response.data);
  },
  async update(postId: number, content: string, imageUrl?: string) {
    const response = await client.patch<Post>(`/posts/${postId}`, { content, imageUrl });
    return normalizePost(response.data);
  },
  async remove(postId: number) {
    await client.delete(`/posts/${postId}`);
  },
  async toggleLike(postId: number) {
    const response = await client.post<Post>(`/posts/${postId}/like`);
    return normalizePost(response.data);
  },
  async toggleBookmark(postId: number) {
    const response = await client.post<Post>(`/posts/${postId}/bookmark`);
    return normalizePost(response.data);
  },
  async getPost(postId: number) {
    const response = await client.get<Post>(`/posts/${postId}`);
    return normalizePost(response.data);
  },
  async listBookmarks(page = 1, pageSize = 12) {
    const response = await client.get<PagedResponse<Post>>('/bookmarks/posts', {
      params: { page, pageSize },
    });

    return {
      ...response.data,
      items: response.data.items.map((item) => normalizePost(item)),
    };
  },
  async comments(postId: number, query: CommentListQuery = {}) {
    const response = await client.get<PagedResponse<Comment>>(`/posts/${postId}/comments`, {
      params: {
        page: query.page,
        pageSize: query.pageSize,
        sort: query.sort,
        parentCommentId: query.parentCommentId,
      },
    });

    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeComment(item)),
    };
  },
  async createComment(postId: number, content: string, parentCommentId?: number) {
    const response = await client.post<Comment>(`/posts/${postId}/comments`, { content, parentCommentId });
    return normalizeComment(response.data);
  },
  async updateComment(postId: number, commentId: number, content: string) {
    const response = await client.patch(`/posts/${postId}/comments/${commentId}`, { content });
    return normalizeMobileComment(asRecord(response.data), postId);
  },
  async deleteComment(postId: number, commentId: number) {
    await client.delete(`/posts/${postId}/comments/${commentId}`);
  },
  async toggleCommentLike(postId: number, commentId: number) {
    const response = await client.post<Comment>(`/posts/${postId}/comments/${commentId}/like`);
    return normalizeComment(response.data);
  },
};
