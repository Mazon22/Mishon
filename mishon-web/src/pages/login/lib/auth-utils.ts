import type { AuthValidation, RegisterFormState } from './types';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const USERNAME_REPLACE_PATTERN = /[^a-z0-9._]/g;
const USERNAME_INVALID_PATTERN = /[^a-z0-9._]/;
const MIN_AGE = 13;

export const AUTH_MONTHS = [
  { value: '1', label: 'Январь' },
  { value: '2', label: 'Февраль' },
  { value: '3', label: 'Март' },
  { value: '4', label: 'Апрель' },
  { value: '5', label: 'Май' },
  { value: '6', label: 'Июнь' },
  { value: '7', label: 'Июль' },
  { value: '8', label: 'Август' },
  { value: '9', label: 'Сентябрь' },
  { value: '10', label: 'Октябрь' },
  { value: '11', label: 'Ноябрь' },
  { value: '12', label: 'Декабрь' },
] as const;

export function buildDayOptions() {
  return Array.from({ length: 31 }, (_, index) => ({
    value: String(index + 1),
    label: String(index + 1),
  }));
}

export function buildYearOptions() {
  const currentYear = new Date().getFullYear();
  return Array.from({ length: 90 }, (_, index) => {
    const value = String(currentYear - index);
    return { value, label: value };
  });
}

export function isEmail(value: string) {
  return EMAIL_PATTERN.test(value.trim());
}

export function suggestUsername(name: string, email: string) {
  const source = name.trim() || email.split('@')[0] || '';
  const normalized = source
    .toLowerCase()
    .replace(/\s+/g, '.')
    .replace(USERNAME_REPLACE_PATTERN, '')
    .replace(/\.{2,}/g, '.')
    .replace(/^\.|\.$/g, '')
    .slice(0, 32);

  if (normalized.length >= 4) {
    return normalized;
  }

  return '';
}

export function validateRegisterProfile(form: RegisterFormState): AuthValidation {
  if (!form.name.trim()) {
    return { valid: false, message: 'Введите имя, которое увидят другие люди.' };
  }

  if (!isEmail(form.email)) {
    return { valid: false, message: 'Укажите корректный email для входа и восстановления доступа.' };
  }

  if (!form.birthMonth || !form.birthDay || !form.birthYear) {
    return { valid: false, message: 'Укажите дату рождения полностью.' };
  }

  const month = Number(form.birthMonth);
  const day = Number(form.birthDay);
  const year = Number(form.birthYear);
  const candidate = new Date(year, month - 1, day);

  if (
    Number.isNaN(candidate.getTime()) ||
    candidate.getFullYear() !== year ||
    candidate.getMonth() !== month - 1 ||
    candidate.getDate() !== day
  ) {
    return { valid: false, message: 'Похоже, дата рождения введена некорректно.' };
  }

  const now = new Date();
  let age = now.getFullYear() - candidate.getFullYear();
  const birthdayPassed =
    now.getMonth() > candidate.getMonth() ||
    (now.getMonth() === candidate.getMonth() && now.getDate() >= candidate.getDate());

  if (!birthdayPassed) {
    age -= 1;
  }

  if (age < MIN_AGE) {
    return { valid: false, message: 'Для регистрации в веб-версии нужен возраст не младше 13 лет.' };
  }

  return { valid: true };
}

export function validateRegisterCredentials(form: RegisterFormState): AuthValidation {
  const username = form.username.trim().toLowerCase();

  if (username.length < 4) {
    return { valid: false, message: 'Придумайте username не короче 4 символов.' };
  }

  if (username.length > 32 || USERNAME_INVALID_PATTERN.test(username)) {
    return {
      valid: false,
      message: 'Username может содержать только латиницу, цифры, точку и нижнее подчеркивание.',
    };
  }

  if (form.password.length < 8) {
    return { valid: false, message: 'Сделайте пароль длиной минимум 8 символов.' };
  }

  return { valid: true };
}
