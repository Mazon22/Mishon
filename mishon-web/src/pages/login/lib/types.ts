export type AuthModalKind = 'register' | 'login' | null;

export type RegisterStep = 'profile' | 'credentials';

export type RegisterFormState = {
  name: string;
  email: string;
  birthMonth: string;
  birthDay: string;
  birthYear: string;
  username: string;
  password: string;
};

export type LoginFormState = {
  email: string;
  password: string;
};

export type AuthValidation = {
  valid: boolean;
  message?: string;
};
