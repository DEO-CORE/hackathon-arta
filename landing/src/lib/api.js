export const MODE = import.meta.env.VITE_DATA_MODE || "api";
if (!["api", "demo"].includes(MODE))
  throw new Error("VITE_DATA_MODE must be api or demo");
export const API_URL = (import.meta.env.VITE_API_URL || "/api").replace(
  /\/$/,
  "",
);
export class ApiError extends Error {
  constructor(status, body) {
    const errors = body?.error?.details?.errors;
    super(
      errors?.length
        ? errors.map((e) => `${e.field}: ${e.message}`).join("\n")
        : body?.error?.message || `Ошибка сервера (${status}).`,
    );
    this.status = status;
    this.code = body?.error?.code;
    this.details = body?.error?.details;
  }
}
export async function api(path, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(API_URL + path, {
      ...options,
      credentials: "include",
      signal: options.signal || controller.signal,
      headers: {
        ...(options.body instanceof FormData
          ? {}
          : { "Content-Type": "application/json" }),
        ...options.headers,
      },
    });
    const body = response.status === 204 ? null : await response.json();
    if (!response.ok) throw new ApiError(response.status, body);
    return body;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new Error(
      error.name === "AbortError"
        ? "Сервер не ответил вовремя. Повторите запрос."
        : "Не удалось связаться с сервером. Проверьте соединение.",
    );
  } finally {
    clearTimeout(timer);
  }
}
export const json = (method, body) => ({ method, body: JSON.stringify(body) });
export const mediaUrl = (path) =>
  path.startsWith("/") ? API_URL + path : path;
