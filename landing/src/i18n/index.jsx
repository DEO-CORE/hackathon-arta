import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import { Globe2, ChevronDown, Check } from "lucide-react";
import {
  getLanguage,
  getLocale,
  languages,
  setLanguage,
  subscribeLanguage,
  translate,
} from "./locale.js";
import { initialMaterials } from "../data/materials.js";

export function useI18n() {
  const language = useSyncExternalStore(
    subscribeLanguage,
    getLanguage,
    () => "ru",
  );
  const t = useCallback(
    (source, params) => translate(source, params, language),
    [language],
  );
  return { t, language, locale: getLocale(), setLanguage };
}

export function materialText(material, field, language) {
  const original = initialMaterials.find((item) => item.id === material.id);
  // Older saved fixtures can still contain the former organisation prefix.
  // Match only a known fixture; never rewrite a user's organisation name.
  const legacyName =
    field === "organization_name" && typeof material[field] === "string"
      ? material[field]
          .replace(/^Демо-/i, "")
          .replace(/^[а-я]/u, (letter) => letter.toUpperCase())
      : null;
  return !material.is_own &&
    original &&
    (original[field] === material[field] ||
      (legacyName !== null && original[field] === legacyName))
    ? translate(original[field], {}, language)
    : material[field];
}

export function LanguageSwitch({ onOpen }) {
  const { t, language } = useI18n();
  const [open, setOpen] = useState(false);
  const root = useRef(null);
  const trigger = useRef(null);
  const options = useRef([]);
  const focusOnOpen = useRef(0);
  const menuId = useId();
  const current = languages.find((item) => item.code === language);

  const close = (restoreFocus = false) => {
    setOpen(false);
    if (restoreFocus) trigger.current?.focus({ preventScroll: true });
  };
  const show = (index = languages.indexOf(current)) => {
    focusOnOpen.current = index;
    onOpen?.();
    setOpen(true);
  };

  useEffect(() => {
    if (!open) return;
    options.current[focusOnOpen.current]?.focus({ preventScroll: true });
    const dismiss = (event) => {
      if (!root.current?.contains(event.target)) setOpen(false);
    };
    document.addEventListener("pointerdown", dismiss);
    return () => document.removeEventListener("pointerdown", dismiss);
  }, [open]);

  const navigate = (event) => {
    const index = options.current.indexOf(document.activeElement);
    let next;
    if (event.key === "ArrowDown") next = (index + 1) % languages.length;
    else if (event.key === "ArrowUp")
      next = (index - 1 + languages.length) % languages.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = languages.length - 1;
    else if (event.key === "Tab") {
      // Let native Tab continue from the trigger to the next page control.
      close(true);
      return;
    } else if (
      event.key.length === 1 &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.altKey
    ) {
      const letter = event.key.toLocaleLowerCase();
      next = languages.findIndex(
        (item) =>
          item.label.toLocaleLowerCase().startsWith(letter) ||
          item.code.startsWith(letter),
      );
      if (next < 0) return;
    }
    if (next !== undefined) {
      event.preventDefault();
      options.current[next]?.focus({ preventScroll: true });
    }
  };

  return (
    <div
      ref={root}
      className="language-switch"
      data-open={open}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) close();
      }}
      onKeyDown={(event) => {
        if (event.key === "Escape" && open) {
          event.preventDefault();
          event.stopPropagation();
          close(true);
        }
      }}
    >
      <button
        ref={trigger}
        type="button"
        className="language-trigger"
        data-language={language}
        aria-label={`${t("Язык интерфейса")}: ${current.label}`}
        aria-haspopup="menu"
        aria-controls={menuId}
        aria-expanded={open}
        onClick={() => (open ? close() : show())}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            event.preventDefault();
            show(event.key === "ArrowDown" ? 0 : languages.length - 1);
          }
        }}
      >
        <Globe2 size={16} aria-hidden="true" />
        <span className="language-code-window" aria-hidden="true">
          <span className="language-code" key={language}>
            {language.toUpperCase()}
          </span>
        </span>
        <ChevronDown
          className="language-chevron"
          size={13}
          aria-hidden="true"
        />
      </button>
      <div
        id={menuId}
        className="language-menu"
        role="menu"
        aria-label={t("Язык интерфейса")}
        aria-hidden={!open}
        inert={!open}
        onKeyDown={navigate}
      >
        {languages.map((item, index) => (
          <button
            key={item.code}
            ref={(node) => {
              options.current[index] = node;
            }}
            type="button"
            role="menuitemradio"
            aria-checked={item.code === language}
            className="language-option"
            data-language={item.code}
            lang={item.code}
            tabIndex={-1}
            onClick={() => {
              setLanguage(item.code);
              close(true);
            }}
          >
            <span className="language-option-code" aria-hidden="true">
              {item.code.toUpperCase()}
            </span>
            <span>{item.label}</span>
            <Check
              className="language-option-check"
              size={17}
              aria-hidden="true"
            />
          </button>
        ))}
      </div>
    </div>
  );
}
