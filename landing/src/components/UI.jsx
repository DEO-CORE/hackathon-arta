import { useI18n, materialText } from "../i18n";
import { useEffect, useId, useRef } from "react";
import { Link } from "react-router-dom";
import {
  ArrowUpRight,
  MapPin,
  X,
  ArrowRight,
  Sparkles,
  AlertCircle,
} from "lucide-react";
import { materialTypes, reuseIdeas } from "../data/materials";
import {
  availableUnits,
  fromUnits,
  formatKg,
  formatPrice,
} from "../lib/domain";

export function Brand({ light = false }) {
  const { t } = useI18n();

  return (
    <Link
      to="/"
      aria-label={t("ARTA — главная")}
      className={`brand ${light ? "brand-light" : ""}`}
    >
      <span className="brand-type">
        arta<span className="brand-dot">.</span>
      </span>
      <span className="brand-caption">
        {t("вторая жизнь")}
        <br />
        {t("текстиля")}
      </span>
    </Link>
  );
}

export function ButtonLink({
  to,
  children,
  variant = "primary",
  className = "",
  ...rest
}) {
  const { t } = useI18n();

  return (
    <Link to={to} className={`button button-${variant} ${className}`} {...rest}>
      {t(children)}
    </Link>
  );
}

export function SectionHeading({ label, title, description, action, id }) {
  const { t } = useI18n();

  return (
    <div className="section-heading" id={id}>
      <div>
        <p className="eyebrow">{t(label)}</p>
        <h2>{t(title)}</h2>
      </div>
      {description && <p className="section-description">{t(description)}</p>}
      {action}
    </div>
  );
}

export function MaterialCard({ material, requests }) {
  const { t } = useI18n();

  const available = availableUnits(material, requests);
  return (
    <article className="material-card">
      <Link
        to={`/catalog/${material.id}`}
        className="material-image-link"
        aria-label={t("Открыть: {{0}}", { 0: materialText(material, "name") })}
      >
        <img
          src={material.image}
          alt={t("Иллюстрация партии: {{0}}", {
            0: materialText(material, "name"),
          })}
          loading="lazy"
          width="640"
          height="480"
        />
        <span className="photo-tag">
          {t(materialTypes[material.material_type] || material.material_type)}
        </span>
      </Link>
      <div className="material-card-body">
        <div className="flex items-center justify-between gap-3 text-xs text-muted">
          <span className="inline-flex items-center gap-1">
            <MapPin size={13} />
            {materialText(material, "city")}
          </span>
          {material.is_own && <span>{t("Ваша партия")}</span>}
        </div>
        <h3>
          <Link to={`/catalog/${material.id}`}>
            {materialText(material, "name")}
          </Link>
        </h3>
        <p className="text-sm text-muted">
          {materialText(material, "scrap_size")}
        </p>
        <div className="material-card-bottom">
          <p>
            <strong>{formatPrice(material.price_per_kg)}</strong>
            <span>{t(" / кг")}</span>
          </p>
          <span
            className={`stock-pill ${available === 0 ? "stock-empty" : ""}`}
          >
            {available > 0 ? formatKg(fromUnits(available)) : t("Нет остатка")}
          </span>
        </div>
        <Link
          to={`/catalog/${material.id}`}
          className="material-card-link"
          aria-label={t("Подробнее: {{0}}", {
            0: materialText(material, "name"),
          })}
        >
          {t("Подробнее ")}
          <ArrowRight size={16} />
        </Link>
      </div>
    </article>
  );
}

export function ErrorMessage({ children }) {
  const { t } = useI18n();

  return children ? (
    <div className="error-message" role="alert">
      <AlertCircle size={18} />
      <span>{t(children)}</span>
    </div>
  ) : null;
}

export function EmptyState({ title, description, children }) {
  const { t } = useI18n();

  return (
    <div className="empty-state">
      <span className="empty-symbol">
        <Sparkles size={30} />
      </span>
      <h2>{t(title)}</h2>
      <p>{t(description)}</p>
      {t(children)}
    </div>
  );
}

export function Dialog({ title, children, onClose, wide = false }) {
  const { t } = useI18n();

  const titleId = useId();
  const ref = useRef(null);
  const trigger = useRef(document.activeElement);
  useEffect(() => {
    const active = trigger.current;
    const element = ref.current;
    const bodyOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    element.showModal();
    return () => {
      element.close();
      document.body.style.overflow = bodyOverflow;
      active?.focus?.({ preventScroll: true });
    };
  }, []);
  return (
    <dialog
      ref={ref}
      aria-labelledby={titleId}
      className={`dialog ${wide ? "dialog-wide" : ""}`}
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onClick={(event) => {
        if (event.target === ref.current) {
          const box = ref.current.getBoundingClientRect();
          if (
            event.clientX < box.left ||
            event.clientX > box.right ||
            event.clientY < box.top ||
            event.clientY > box.bottom
          )
            onClose();
        }
      }}
    >
      <div className="dialog-inner">
        <div className="dialog-heading">
          <h2 id={titleId}>{t(title)}</h2>
          <button
            type="button"
            className="icon-button"
            onClick={onClose}
            aria-label={t("Закрыть")}
          >
            <X size={22} />
          </button>
        </div>
        {t(children)}
      </div>
    </dialog>
  );
}

export function ReuseIdeas({
  type,
  condition,
  heading = "Каким может быть следующий шаг",
}) {
  const { t } = useI18n();

  const ideas = reuseIdeas[type] || reuseIdeas.default;
  return (
    <section className="reuse-panel">
      <div className="flex items-center gap-2">
        <Sparkles size={20} />
        <span className="eyebrow">{t("Возможности материала")}</span>
      </div>
      <h2>{t(heading)}</h2>
      <p className="text-sm leading-relaxed text-muted">
        {t(
          "Идеи применения по типу и состоянию ткани. Перед работой проверьте состав и пригодность материала.",
        )}
      </p>
      {["worn", "damaged"].includes(condition) && (
        <p className="notice mt-4">
          {t(
            "Перед использованием потребуется сортировка и проверка состояния.",
          )}
        </p>
      )}
      <div className="reuse-list">
        {ideas.map((idea, index) => (
          <article key={idea.title}>
            <span className="reuse-number">0{index + 1}</span>
            <div>
              <h3>{t(idea.title)}</h3>
              <span className="buyer-label">{t(idea.buyer)}</span>
              <p>{t(idea.reason)}</p>
            </div>
            <ArrowUpRight size={19} aria-hidden="true" />
          </article>
        ))}
      </div>
      <p className="text-xs text-muted">
        {t("Категории покупателей — примеры, а не подтверждённый спрос.")}
      </p>
    </section>
  );
}

export function TextArrow({ children }) {
  const { t } = useI18n();

  return (
    <>
      {t(children)}
      <ArrowRight size={17} aria-hidden="true" />
    </>
  );
}
