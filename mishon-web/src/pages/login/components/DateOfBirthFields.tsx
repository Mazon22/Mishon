import { AppIcon } from '../../../shared/ui/AppIcon';
import { AUTH_MONTHS } from '../lib/auth-utils';
import { AuthInput } from './AuthInput';

type Option = {
  value: string;
  label: string;
};

type DateOfBirthFieldsProps = {
  month: string;
  day: string;
  year: string;
  dayOptions: Option[];
  yearOptions: Option[];
  onChange: (field: 'birthMonth' | 'birthDay' | 'birthYear', value: string) => void;
};

export function DateOfBirthFields({
  month,
  day,
  year,
  dayOptions,
  yearOptions,
  onChange,
}: DateOfBirthFieldsProps) {
  return (
    <div className="auth-dob">
      <div className="auth-dob__copy">
        <h3>Дата рождения</h3>
        <p>Нужна для возраста и приватности аккаунта.</p>
      </div>

      <div className="auth-dob__grid">
        <AuthInput
          as="select"
          label="Месяц"
          leading={<AppIcon name="calendar" className="app-icon" />}
          selectProps={{
            value: month,
            onChange: (event) => onChange('birthMonth', event.target.value),
          }}
        >
          <option value="">Месяц</option>
          {AUTH_MONTHS.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </AuthInput>

        <AuthInput
          as="select"
          label="День"
          selectProps={{
            value: day,
            onChange: (event) => onChange('birthDay', event.target.value),
          }}
        >
          <option value="">День</option>
          {dayOptions.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </AuthInput>

        <AuthInput
          as="select"
          label="Год"
          selectProps={{
            value: year,
            onChange: (event) => onChange('birthYear', event.target.value),
          }}
        >
          <option value="">Год</option>
          {yearOptions.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </AuthInput>
      </div>
    </div>
  );
}
