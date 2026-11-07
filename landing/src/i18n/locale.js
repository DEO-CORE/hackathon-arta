import { messages } from "./messages.js";

export const LANGUAGE_KEY = "arta-language-v1";
export const languages = [
  { code: "ru", label: "Русский", locale: "ru-RU" },
  { code: "ky", label: "Кыргызча", locale: "ky-KG" },
  { code: "en", label: "English", locale: "en-GB" },
];
const supported = (value) => languages.some((item) => item.code === value);
function readLanguage() {
  try {
    const saved = globalThis.localStorage?.getItem(LANGUAGE_KEY);
    return supported(saved) ? saved : "ru";
  } catch {
    return "ru";
  }
}
let language = readLanguage();
const listeners = new Set();
export const getLanguage = () => language;
export const getLocale = () =>
  languages.find((item) => item.code === language).locale;
export const subscribeLanguage = (listener) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};
export function setLanguage(next) {
  if (!supported(next)) return;
  language = next;
  try {
    globalThis.localStorage?.setItem(LANGUAGE_KEY, next);
  } catch {
    /* Keep the choice for this tab when storage is unavailable. */
  }
  listeners.forEach((listener) => listener());
}
if (typeof window !== "undefined")
  window.addEventListener("storage", (event) => {
    if (event.key !== LANGUAGE_KEY && event.key !== null) return;
    language = readLanguage();
    listeners.forEach((listener) => listener());
  });

// Source messages are stable Russian keys. Translate UI copy, never arbitrary
// user content. Substitution happens after lookup, so names remain untouched.
export function translate(source, params = {}, selected = language) {
  if (typeof source !== "string") return source;
  const key = source.replace(/\s+/g, " ").trim();
  const translated = selected === "ru" ? undefined : messages[key]?.[selected];
  const text =
    translated === undefined
      ? source
      : `${source.match(/^\s*/)[0]}${translated}${source.match(/\s*$/)[0]}`;
  return text.replace(/\{\{(\w+)\}\}/g, (match, key) =>
    Object.hasOwn(params, key) ? String(params[key]) : match,
  );
}
