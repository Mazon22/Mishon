import type { InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from 'react';

import { AppIcon } from '../../../shared/ui/AppIcon';

type BaseProps = {
  label: string;
  hint?: string;
  error?: string | null;
  leading?: ReactNode;
  trailing?: ReactNode;
  action?: ReactNode;
  className?: string;
};

type TextInputProps = BaseProps & {
  as?: 'input';
  inputProps?: InputHTMLAttributes<HTMLInputElement>;
};

type SelectInputProps = BaseProps & {
  as: 'select';
  selectProps?: SelectHTMLAttributes<HTMLSelectElement>;
  children?: ReactNode;
};

type TextAreaProps = BaseProps & {
  as: 'textarea';
  textareaProps?: TextareaHTMLAttributes<HTMLTextAreaElement>;
};

type AuthInputProps = TextInputProps | SelectInputProps | TextAreaProps;

export function AuthInput(props: AuthInputProps) {
  const { label, hint, error, leading, trailing, action, className } = props;
  const filled =
    props.as === 'select'
      ? Boolean(props.selectProps?.value)
      : props.as === 'textarea'
        ? Boolean(props.textareaProps?.value)
        : Boolean(props.inputProps?.value);

  const isSelect = props.as === 'select';
  const resolvedTrailing =
    trailing ??
    (isSelect ? <AppIcon name="chevron-right" className="app-icon auth-input__chevron" /> : null);

  return (
    <label
      className={[
        'auth-input',
        isSelect ? 'auth-input--select' : '',
        filled ? 'auth-input--filled' : '',
        error ? 'auth-input--error' : '',
        leading ? 'auth-input--with-leading' : '',
        resolvedTrailing ? 'auth-input--with-trailing' : '',
        className ?? '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <span className="auth-input__label-row">
        <span className="auth-input__label">{label}</span>
        {action ? <span className="auth-input__action">{action}</span> : null}
      </span>
      <span className="auth-input__field">
        {leading ? <span className="auth-input__leading">{leading}</span> : null}
        {props.as === 'select' ? (
          <select className="auth-input__control" {...props.selectProps}>
            {props.children}
          </select>
        ) : props.as === 'textarea' ? (
          <textarea className="auth-input__control auth-input__control--area" {...props.textareaProps} />
        ) : (
          <input className="auth-input__control" {...props.inputProps} />
        )}
        {resolvedTrailing ? <span className="auth-input__trailing">{resolvedTrailing}</span> : null}
      </span>
      {error ? <span className="auth-input__meta auth-input__meta--error">{error}</span> : hint ? <span className="auth-input__meta">{hint}</span> : null}
    </label>
  );
}
