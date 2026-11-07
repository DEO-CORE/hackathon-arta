import { useI18n } from "../i18n";
import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { register, login, forgotPassword, resetPassword } from "../lib/store";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Eye,
  EyeOff,
  Factory,
  Leaf,
  Clock3,
  Recycle,
  Scissors,
} from "lucide-react";
import { ButtonLink } from "../components/UI";
import {
  activities,
  registrationPayload,
  validateCredentials,
  validateEmail,
  validateRegistrationProfile,
} from "../lib/auth";

function AuthShell({ children }) {
  const { t } = useI18n();

  return (
    <div className="auth-page page-blocks">
      <section className="page-block auth-block">
        <Link to="/" className="auth-back">
          <ArrowLeft size={17} />
          {t(" На главную")}
        </Link>
        <div className="auth-layout">
          <div className="auth-panel">{t(children)}</div>
          <aside className="auth-story" aria-label={t("Вторая жизнь текстиля")}>
            <span className="auth-story-label">
              <Leaf size={16} />
              {t(" НОВЫЙ ЦИКЛ НАЧИНАЕТСЯ С ВАС")}
            </span>
            <h2>
              {t("Меньше остатков.")}
              <br />
              {t("Больше возможностей.")}
            </h2>
            <div className="auth-story-photo">
              <img
                src="/images/workshop.webp"
                alt={t("Мастерицы находят новое применение остаткам ткани")}
                width="780"
                height="620"
              />
              <span aria-hidden="true">
                <Recycle size={32} strokeWidth={1.5} />
              </span>
            </div>
            <p>
              {t("Соединяем тех, у кого остаётся ткань,")}
              <br />
              {t("с теми, у кого есть идея.")}
            </p>
            <div className="auth-story-foot">
              <span>{t("Из цеха — в мастерскую")}</span>
              <ArrowRight size={21} />
              <span>{t("В новый цикл")}</span>
            </div>
          </aside>
        </div>
      </section>
    </div>
  );
}

function AuthHeading({ title, children }) {
  const { t } = useI18n();

  return (
    <div className="auth-heading">
      <span className="auth-kicker">
        <span />
        {t(" Пространство ARTA")}
      </span>
      <h1>{t(title)}</h1>
      <p>{t(children)}</p>
    </div>
  );
}

function Field({ name, label, error, hint, children, ...props }) {
  const { t } = useI18n();

  const id = `auth-${name}`;
  const described =
    [hint && `${id}-hint`, error && `${id}-error`].filter(Boolean).join(" ") ||
    undefined;
  return (
    <div className="auth-field">
      <label htmlFor={id}>{t(label)}</label>
      {children ? (
        <select
          id={id}
          name={name}
          aria-invalid={Boolean(error)}
          aria-describedby={described}
          {...props}
        >
          {t(children)}
        </select>
      ) : (
        <input
          id={id}
          name={name}
          aria-invalid={Boolean(error)}
          aria-describedby={described}
          {...props}
        />
      )}
      {hint && (
        <span id={`${id}-hint`} className="auth-hint">
          {t(hint)}
        </span>
      )}
      {error && (
        <span id={`${id}-error`} className="auth-error" role="alert">
          {t(error)}
        </span>
      )}
    </div>
  );
}

function PasswordField({
  name = "password",
  label = "Пароль",
  error,
  hint,
  ...props
}) {
  const { t } = useI18n();

  const [visible, setVisible] = useState(false);
  const id = `auth-${name}`;
  return (
    <div className="auth-field">
      <label htmlFor={id}>{t(label)}</label>
      <div className="auth-password">
        <input
          id={id}
          name={name}
          type={visible ? "text" : "password"}
          aria-invalid={Boolean(error)}
          aria-describedby={
            [hint && `${id}-hint`, error && `${id}-error`]
              .filter(Boolean)
              .join(" ") || undefined
          }
          {...props}
        />
        <button
          type="button"
          onClick={() => setVisible(!visible)}
          aria-label={t(
            name === "confirm"
              ? visible
                ? "Скрыть повтор пароля"
                : "Показать повтор пароля"
              : visible
                ? "Скрыть пароль"
                : "Показать пароль",
          )}
          aria-pressed={visible}
        >
          {visible ? <EyeOff size={19} /> : <Eye size={19} />}
        </button>
      </div>
      {hint && (
        <span id={`${id}-hint`} className="auth-hint">
          {t(hint)}
        </span>
      )}
      {error && (
        <span id={`${id}-error`} className="auth-error" role="alert">
          {t(error)}
        </span>
      )}
    </div>
  );
}

function useFormValues(initial) {
  const [values, setValues] = useState(initial);
  const [errors, setErrors] = useState({});
  const update = (event) => {
    const { name, value } = event.target;
    setValues((current) => ({ ...current, [name]: value }));
    setErrors((current) => ({ ...current, [name]: undefined }));
  };
  const check = (nextErrors) => {
    setErrors(nextErrors);
    const first = Object.keys(nextErrors)[0];
    if (first)
      requestAnimationFrame(() =>
        document.getElementById(`auth-${first}`)?.focus(),
      );
    return !first;
  };
  return { values, setValues, errors, setErrors, update, check };
}

function Completion({ kind, role }) {
  const { t } = useI18n();

  const heading = useRef(null);
  useEffect(() => {
    heading.current?.focus();
  }, []);
  const content = {
    register: {
      title: "Аккаунт создан",
      text: "Теперь войдите с указанными email и паролем.",
      action: "Войти",
      to: "/login",
    },
    login: {
      title: "Вход скоро будет доступен",
      text: "Войти в аккаунт пока нельзя. Материалы в каталоге доступны без входа.",
      action: "Открыть каталог",
      to: "/catalog",
    },
    forgot: {
      title: "Проверьте почту",
      text: "Если аккаунт существует, на указанный email придёт ссылка для смены пароля.",
      action: "Вернуться ко входу",
      to: "/login",
    },
    reset: {
      title: "Пароль изменён",
      text: "Войдите с новым паролем. Предыдущие сессии завершены.",
      action: "Вернуться ко входу",
      to: "/login",
    },
  }[kind];
  return (
    <div className="auth-complete">
      <span className="auth-complete-icon" aria-hidden="true">
        <Clock3 size={30} />
      </span>
      <span className="auth-kicker">
        <span />
        {t(" Пространство ARTA")}
      </span>
      <h1 ref={heading} tabIndex={-1}>
        {t(content.title)}
      </h1>
      <p>{t(content.text)}</p>
      <ButtonLink to={content.to}>
        {t(content.action)}
        <ArrowRight size={18} />
      </ButtonLink>
      <Link className="auth-text-link" to="/">
        {t("На главную")}
      </Link>
    </div>
  );
}

function Register() {
  const { t } = useI18n();

  const { values, setValues, errors, setErrors, update, check } = useFormValues(
    {
      role: "enterprise",
      name: "",
      city: "",
      activity_type: "garment_factory",
      contact_name: "",
      email: "",
      password: "",
      confirm: "",
    },
  );
  const [step, setStep] = useState(1);
  const [complete, setComplete] = useState(false);
  const [pending, setPending] = useState(false);
  const [serverError, setServerError] = useState("");
  const requestLock = useRef(false);
  const isBuyer = values.role === "buyer";
  const stepTitle = useRef(null);
  const previousStep = useRef(step);
  useEffect(() => {
    if (previousStep.current !== step) stepTitle.current?.focus();
    previousStep.current = step;
  }, [step]);
  const submit = async (event) => {
    if (requestLock.current) {
      event.preventDefault();
      return;
    }
    event.preventDefault();
    if (step === 1) {
      if (check(validateRegistrationProfile(values))) setStep(2);
    } else if (check(validateCredentials(values, { newPassword: true }))) {
      requestLock.current = true;
      setPending(true);
      setServerError("");
      try {
        await register(registrationPayload(values));
        setValues((current) => ({ ...current, password: "", confirm: "" }));
        setComplete(true);
      } catch (error) {
        setServerError(error.message);
      } finally {
        requestLock.current = false;
        setPending(false);
      }
    }
  };
  if (complete) return <Completion kind="register" role={values.role} />;
  return (
    <>
      <AuthHeading title={t("Начнём новый цикл")}>
        {isBuyer
          ? t("Находите ткань для своих идей.")
          : t("Создайте пространство для вашей организации.")}
        <br />
        {t("Находите материалы или давайте им новую жизнь.")}
      </AuthHeading>
      <ol className="auth-steps" aria-label={t("Этапы регистрации")}>
        <li
          className="is-active"
          aria-current={step === 1 ? "step" : undefined}
        >
          <span>{step === 2 ? <Check size={14} /> : "01"}</span>
          {isBuyer ? t(" О вас") : t(" Организация")}
        </li>
        <li
          className={step === 2 ? "is-active" : ""}
          aria-current={step === 2 ? "step" : undefined}
        >
          <span>02</span>
          {t(" Доступ")}
        </li>
      </ol>
      {serverError && (
        <p role="alert" className="auth-error">
          {serverError}
        </p>
      )}
      <form noValidate onSubmit={submit} className="auth-form">
        <div key={step} className="auth-form-content">
          <h2 ref={stepTitle} tabIndex={-1} className="auth-step-title">
            {step === 1
              ? t("Как вы хотите использовать ARTA?")
              : t("Настройте доступ к аккаунту")}
          </h2>
          {step === 1 ? (
            <>
              <fieldset className="auth-roles">
                <legend className="sr-only">{t("Роль пользователя")}</legend>
                {[
                  {
                    value: "enterprise",
                    title: t("Предлагаю ткань"),
                    description: t("Цех или производство"),
                    Icon: Factory,
                  },
                  {
                    value: "buyer",
                    title: t("Ищу материал"),
                    description: t("Для себя или мастерской"),
                    Icon: Scissors,
                  },
                ].map(({ value, title, description, Icon }) => (
                  <label
                    key={value}
                    className={`auth-role ${values.role === value ? "is-selected" : ""}`}
                  >
                    <input
                      id={`auth-${value === "enterprise" ? "role" : "buyer"}`}
                      type="radio"
                      name="role"
                      value={value}
                      checked={values.role === value}
                      onChange={() => {
                        setValues((current) => ({
                          ...current,
                          role: value,
                        }));
                        setErrors({});
                      }}
                    />
                    <span className="auth-role-top">
                      <Icon size={22} strokeWidth={1.5} />
                      <span className="auth-radio-dot">
                        {values.role === value && <Check size={12} />}
                      </span>
                    </span>
                    <strong>{t(title)}</strong>
                    <span className="auth-role-description">
                      {t(description)}
                    </span>
                  </label>
                ))}
              </fieldset>
              {errors.role && (
                <p className="auth-error" role="alert">
                  {t(errors.role)}
                </p>
              )}
              {isBuyer ? (
                <Field
                  name="contact_name"
                  label={t("Ваше имя")}
                  value={values.contact_name}
                  onChange={update}
                  error={errors.contact_name}
                  placeholder={t("Как к вам обращаться")}
                  autoComplete="name"
                  maxLength={200}
                  required
                />
              ) : (
                <Field
                  name="name"
                  label={t("Название организации")}
                  value={values.name}
                  onChange={update}
                  error={errors.name}
                  placeholder={t("Например, мастерская «Жип»")}
                  autoComplete="organization"
                  maxLength={200}
                  required
                />
              )}
              <div className={isBuyer ? undefined : "auth-field-row"}>
                <Field
                  name="city"
                  label={t("Город")}
                  value={values.city}
                  onChange={update}
                  error={errors.city}
                  placeholder={t("Бишкек")}
                  autoComplete="address-level2"
                  maxLength={100}
                  required
                />
                {!isBuyer && (
                  <Field
                    name="activity_type"
                    label={t("Направление работы")}
                    value={values.activity_type}
                    onChange={update}
                    error={errors.activity_type}
                    required
                  >
                    {Object.entries(activities).map(([value, label]) => (
                      <option key={value} value={value}>
                        {t(label)}
                      </option>
                    ))}
                  </Field>
                )}
              </div>
              {!isBuyer && (
                <Field
                  name="contact_name"
                  label={
                    <>
                      {t("Контактное лицо")}{" "}
                      <span className="auth-optional">
                        {t("· необязательно")}
                      </span>
                    </>
                  }
                  value={values.contact_name}
                  onChange={update}
                  error={errors.contact_name}
                  placeholder={t("Как к вам обращаться")}
                  autoComplete="name"
                  maxLength={200}
                />
              )}
            </>
          ) : (
            <>
              <div className="auth-org-summary">
                <span>
                  {values.role === "enterprise" ? (
                    <Factory size={20} />
                  ) : (
                    <Scissors size={20} />
                  )}
                </span>
                <div>
                  <strong>
                    {isBuyer ? values.contact_name.trim() : values.name.trim()}
                  </strong>
                  <p>
                    {values.city.trim()}
                    {!isBuyer && <> · {t(activities[values.activity_type])}</>}
                  </p>
                </div>
              </div>
              <Field
                name="email"
                label="Email"
                type="email"
                value={values.email}
                onChange={update}
                error={errors.email}
                placeholder="hello@workshop.kg"
                autoComplete="username"
                autoCapitalize="none"
                spellCheck={false}
                maxLength={254}
                required
              />
              <PasswordField
                value={values.password}
                onChange={update}
                error={errors.password}
                autoComplete="new-password"
                hint={t(
                  "От 10 до 128 символов. Можно использовать длинную фразу.",
                )}
                required
              />
              <PasswordField
                name="confirm"
                label={t("Повторите пароль")}
                value={values.confirm}
                onChange={update}
                error={errors.confirm}
                autoComplete="new-password"
                required
              />
              <div
                className="auth-password-checks"
                aria-label={t("Требования к паролю")}
              >
                <span
                  className={
                    Array.from(values.password).length >= 10 &&
                    Array.from(values.password).length <= 128
                      ? "is-met"
                      : ""
                  }
                >
                  <Check size={14} />
                  {t(" 10–128 символов")}
                </span>
                <span
                  className={
                    values.confirm && values.confirm === values.password
                      ? "is-met"
                      : ""
                  }
                >
                  <Check size={14} />
                  {t(" Пароли совпадают")}
                </span>
              </div>
            </>
          )}
        </div>
        <div className="auth-form-actions">
          {step === 2 && (
            <button
              type="button"
              className="button button-outline"
              onClick={() => {
                setErrors({});
                setStep(1);
              }}
            >
              <ArrowLeft size={17} />
              {t(" Назад")}
            </button>
          )}
          <button
            type="submit"
            disabled={pending}
            aria-busy={pending}
            className="button button-primary"
          >
            {step === 1 ? t("Продолжить") : t("Зарегистрироваться")}
            <ArrowRight size={18} />
          </button>
        </div>
      </form>
      <p className="auth-alternative">
        {t("Уже есть аккаунт? ")}
        <Link to="/login">{t("Войти")}</Link>
      </p>
    </>
  );
}

function AccessForm({ mode }) {
  const navigate = useNavigate();
  const [resetToken] = useState(
    () => new URLSearchParams(window.location.hash.slice(1)).get("token") || "",
  );
  useEffect(() => {
    if (mode === "reset" && window.location.hash)
      window.history.replaceState(
        null,
        "",
        window.location.pathname + window.location.search,
      );
  }, [mode]);
  const { t } = useI18n();

  const { values, setValues, errors, update, check } = useFormValues({
    email: "",
    password: "",
    confirm: "",
  });
  const [complete, setComplete] = useState(false);
  const [pending, setPending] = useState(false);
  const [serverError, setServerError] = useState("");
  const requestLock = useRef(false);
  const forgot = mode === "forgot";
  const reset = mode === "reset";
  const content = {
    login: {
      title: "Рады видеть вас снова",
      description:
        "Ваши материалы, заявки и новые возможности — в одном пространстве.",
      action: "Войти",
    },
    forgot: {
      title: "Вернёмся в ваш аккаунт",
      description: "Укажите email, который использовали при регистрации.",
      action: "Восстановить доступ",
    },
    reset: {
      title: "Новый пароль. Новый старт.",
      description: "Придумайте новый пароль для вашего аккаунта.",
      action: "Сохранить пароль",
    },
  }[mode];
  const submit = async (event) => {
    if (requestLock.current) {
      event.preventDefault();
      return;
    }
    event.preventDefault();
    const emailError = forgot ? validateEmail(values.email) : "";
    const nextErrors = forgot
      ? emailError
        ? { email: emailError }
        : {}
      : validateCredentials(values, { email: !reset, newPassword: reset });
    if (!check(nextErrors)) return;
    requestLock.current = true;
    setPending(true);
    setServerError("");
    try {
      if (forgot) await forgotPassword(values.email);
      else if (reset) {
        if (!resetToken)
          throw new Error("Откройте ссылку из письма восстановления.");
        await resetPassword(resetToken, values.password);
      } else {
        await login(values.email, values.password);
        navigate("/requests");
        return;
      }
      setValues((current) => ({ ...current, password: "", confirm: "" }));
      setComplete(true);
    } catch (error) {
      setServerError(error.message);
    } finally {
      requestLock.current = false;
      setPending(false);
    }
  };
  if (complete) return <Completion kind={mode} />;
  return (
    <>
      <AuthHeading title={t(content.title)}>
        {t(content.description)}
      </AuthHeading>
      {serverError && (
        <p role="alert" className="auth-error">
          {serverError}
        </p>
      )}
      <form
        noValidate
        onSubmit={submit}
        className="auth-form auth-form-content"
      >
        {!reset && (
          <Field
            name="email"
            label="Email"
            type="email"
            value={values.email}
            onChange={update}
            error={errors.email}
            placeholder="hello@workshop.kg"
            autoComplete="username"
            autoCapitalize="none"
            spellCheck={false}
            maxLength={254}
            required
          />
        )}
        {!forgot && (
          <PasswordField
            label={reset ? t("Новый пароль") : t("Пароль")}
            value={values.password}
            onChange={update}
            error={errors.password}
            autoComplete={reset ? "new-password" : "current-password"}
            hint={
              reset
                ? t("От 10 до 128 символов. Можно использовать длинную фразу.")
                : undefined
            }
            required
          />
        )}
        {reset && (
          <PasswordField
            name="confirm"
            label={t("Повторите пароль")}
            value={values.confirm}
            onChange={update}
            error={errors.confirm}
            autoComplete="new-password"
            required
          />
        )}
        {mode === "login" && (
          <Link to="/forgot-password" className="auth-forgot">
            {t("Забыли пароль?")}
          </Link>
        )}
        <button
          type="submit"
          disabled={pending}
          aria-busy={pending}
          className="button button-primary auth-submit"
        >
          {t(content.action)}
          <ArrowRight size={18} />
        </button>
      </form>
      {mode === "login" ? (
        <p className="auth-alternative">
          {t("Впервые в ARTA? ")}
          <Link to="/register">{t("Зарегистрироваться")}</Link>
        </p>
      ) : (
        <Link to="/login" className="auth-return">
          <ArrowLeft size={16} />
          {t(" Вернуться ко входу")}
        </Link>
      )}
    </>
  );
}

export default function Auth({ mode }) {
  const { t } = useI18n();

  return (
    <AuthShell>
      {mode === "register" ? (
        <Register />
      ) : (
        <AccessForm key={mode} mode={mode} />
      )}
    </AuthShell>
  );
}
