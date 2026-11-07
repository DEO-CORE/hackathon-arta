// Role-specific frontend validation. The buyer profile needs a new backend
// contract; these helpers do not store credentials or make network requests.
export const activities = {
  garment_factory: "Швейное производство",
  workshop: "Мастерская / ремесленник",
  recycler: "Переработка текстиля",
  other: "Другое производство",
};

export function validateEmail(email) {
  const value = email.trim();
  if (!value) return "Укажите email.";
  if (value.length > 254 || !/^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$/.test(value))
    return "Проверьте адрес, например hello@workshop.kg.";
  return "";
}

export function validateRegistrationProfile(values) {
  const errors = {};
  if (!["enterprise", "buyer"].includes(values.role))
    errors.role = "Выберите, как вы хотите использовать ARTA.";
  if (
    values.role === "enterprise" &&
    (!values.name.trim() || values.name.trim().length > 200)
  )
    errors.name = "Укажите название организации — до 200 символов.";
  if (
    values.role === "buyer" &&
    (!values.contact_name.trim() || values.contact_name.trim().length > 200)
  )
    errors.contact_name = "Укажите ваше имя — до 200 символов.";
  else if (values.contact_name.trim().length > 200)
    errors.contact_name = "Имя должно быть не длиннее 200 символов.";
  if (!values.city.trim() || values.city.trim().length > 100)
    errors.city = "Укажите город — до 100 символов.";
  if (
    values.role === "enterprise" &&
    !Object.hasOwn(activities, values.activity_type)
  )
    errors.activity_type = "Выберите направление работы.";
  return errors;
}

export function validateCredentials(
  values,
  { email = true, newPassword = false } = {},
) {
  const errors = {};
  if (email) {
    const error = validateEmail(values.email);
    if (error) errors.email = error;
  }
  if (!values.password) errors.password = "Введите пароль.";
  else if (newPassword && Array.from(values.password).length < 10)
    errors.password = "Используйте не меньше 10 символов.";
  else if (Array.from(values.password).length > 128)
    errors.password = "Пароль должен быть не длиннее 128 символов.";
  if (newPassword && (!values.confirm || values.confirm !== values.password))
    errors.confirm = "Пароли должны совпадать.";
  return errors;
}

// Call only after validation. Enterprise matches the existing registration DTO.
// Buyer uses a proposed personal-profile shape: see INTEGRATION.md before API use.
// Hidden fields from the other role never enter the payload.
export function registrationPayload(values) {
  const account = {
    email: values.email.trim().toLowerCase(),
    password: values.password,
    role: values.role,
  };
  if (values.role === "buyer")
    return {
      ...account,
      profile: { name: values.contact_name.trim(), city: values.city.trim() },
    };
  return {
    ...account,
    organization: {
      name: values.name.trim(),
      city: values.city.trim(),
      activity_type: values.activity_type,
      ...(values.contact_name.trim()
        ? {
            contacts: { contact_name: values.contact_name.trim() },
          }
        : {}),
    },
  };
}
