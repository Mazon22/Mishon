import type { AxiosError } from 'axios';

import type { ApiError } from '../../types/api';

export class HttpError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.status = status;
  }
}

export function normalizeError(error: AxiosError<ApiError>) {
  const message = error.response?.data?.message ?? error.message ?? 'Request failed';
  return new HttpError(message, error.response?.status ?? 500);
}
