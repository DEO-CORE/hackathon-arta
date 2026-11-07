import { useI18n, materialText } from "../i18n";
import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowUpRight,
  Check,
  CheckCircle2,
  RotateCcw,
  Package,
  Recycle,
  ArrowRight,
} from "lucide-react";
import { ButtonLink, Dialog, EmptyState, ErrorMessage } from "../components/UI";
import { demoRepository, useDemo } from "../lib/store";
import { formatKg, formatPrice, requestTotal, summarize } from "../lib/domain";

const stages = ["pending", "confirmed", "transferred", "received", "reused"];
const labels = {
  pending: "Ожидает подтверждения",
  confirmed: "Зарезервировано",
  transferred: "Передано продавцом",
  received: "Получено покупателем",
  reused: "Использование подтверждено",
  cancelled: "Отменено",
};
const actions = {
  pending: {
    target: "confirmed",
    title: "Подтвердить резерв",
    role: "Продавец",
    description:
      "Этот объём будет зарезервирован. Свободный остаток партии уменьшится. Счётчик использования пока не изменится.",
  },
  confirmed: {
    target: "transferred",
    title: "Подтвердить передачу",
    role: "Продавец",
    description:
      "Подтвердите передачу материала. Передача сама по себе не означает повторного использования.",
  },
  transferred: {
    target: "received",
    title: "Подтвердить получение",
    role: "Покупатель",
    description:
      "Подтвердите получение материала. Факт использования фиксируется отдельным следующим шагом.",
  },
  received: {
    target: "reused",
    title: "Подтвердить использование",
    role: "Покупатель",
    description:
      "Подтвердите использование всего полученного объёма. Только после этого масса попадёт в счётчик повторного использования.",
  },
};

export default function Requests() {
  const { t, locale } = useI18n();

  const state = useDemo();
  const stats = summarize(state);
  const [filter, setFilter] = useState("all");
  const [dialog, setDialog] = useState(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const lock = useRef(false);
  const visible = state.requests.filter(
    (r) =>
      filter === "all" ||
      (filter === "active"
        ? !["reused", "cancelled"].includes(r.status)
        : ["reused", "cancelled"].includes(r.status)),
  );
  function openDialog(value) {
    setError("");
    lock.current = false;
    setDialog(value);
  }
  function confirm() {
    if (lock.current) return;
    lock.current = true;
    try {
      if (dialog.reset) {
        demoRepository.reset();
        setNotice("Данные очищены.");
      } else {
        demoRepository.transition(dialog.id, dialog.target);
        setNotice({ status: dialog.target });
      }
      setDialog(null);
    } catch (err) {
      setError(err.message);
    } finally {
      lock.current = false;
    }
  }
  return (
    <div className="page-blocks requests-page">
      <section className="page-heading page-block">
        <div>
          <p className="eyebrow">{t("Каждый шаг имеет значение")}</p>
          <h1>
            {t("От заявки")}
            <br />
            {t("к новой жизни.")}
          </h1>
          <p>{t("Пройдите путь материала и посмотрите на результат.")}</p>
        </div>
        <ButtonLink to="/catalog" variant="outline">
          {t("Найти материал ")}
          <ArrowUpRight size={18} />
        </ButtonLink>
      </section>
      <div className="stats-grid page-block">
        <article className="stat-card">
          <Package size={22} />
          <span>{t("Активных заявок")}</span>
          <strong>{stats.activeRequests}</strong>
          <p>{t("До подтверждения получения")}</p>
        </article>
        <article className="stat-card">
          <ArrowRight size={22} />
          <span>{t("Передано")}</span>
          <strong>{formatKg(stats.transferred)}</strong>
          <p>{t("Передача ещё не равна использованию")}</p>
        </article>
        <article className="stat-card stat-reuse">
          <Recycle size={24} />
          <span>{t("Повторно использовано")}</span>
          <strong>{formatKg(stats.reused)}</strong>
          <p>{t("Только отдельные подтверждения использования")}</p>
        </article>
      </div>
      {notice && (
        <div className="success-banner" role="status">
          <CheckCircle2 size={18} />
          {typeof notice === "string"
            ? t(notice)
            : t("{{0}}. Изменения сохранены.", {
                0: t(labels[notice.status]),
              })}
        </div>
      )}
      <section className="page-block requests-content">
        <div className="requests-toolbar">
          <div className="filter-chips">
            {[
              ["all", t("Все заявки")],
              ["active", t("В работе")],
              ["finished", t("Завершённые")],
            ].map(([key, text]) => (
              <button
                key={key}
                className={`filter-chip ${filter === key ? "selected" : ""}`}
                onClick={() => setFilter(key)}
                aria-pressed={filter === key}
              >
                {t(text)}
              </button>
            ))}
          </div>
          <button
            className="text-link reset-button"
            onClick={() =>
              openDialog({
                reset: true,
                title: "Очистить данные?",
                description:
                  "Созданные вами партии, фотографии и заявки будут удалены из этого браузера. Исходный каталог сохранится. Это действие нельзя отменить.",
              })
            }
          >
            <RotateCcw size={16} />
            {t("Очистить данные")}
          </button>
        </div>
        {!visible.length ? (
          <EmptyState
            title={
              filter === "all"
                ? t("Здесь начнётся новая история")
                : t("В этой группе пока нет заявок")
            }
            description={
              filter === "all"
                ? t("Выберите материал в каталоге и создайте первую заявку.")
                : t(
                    "Переключите группу или продолжите сценарий в активной заявке.",
                  )
            }
          >
            <ButtonLink to="/catalog" variant="dark">
              {t("Посмотреть каталог ")}
              <ArrowUpRight size={18} />
            </ButtonLink>
          </EmptyState>
        ) : (
          <div className="request-list">
            {visible.map((request) => {
              const material = state.materials.find(
                (m) => m.id === request.material_id,
              );
              if (!material) return null;
              const action = actions[request.status];
              return (
                <article className="request-card" key={request.id}>
                  <div className="request-card-top">
                    <Link
                      to={`/catalog/${material.id}`}
                      className="request-thumbnail"
                    >
                      <img
                        src={material.image}
                        alt={materialText(material, "name")}
                        width="120"
                        height="120"
                      />
                    </Link>
                    <div className="request-title">
                      <p className="text-xs text-muted">
                        {t("Заявка ·")}{" "}
                        {new Intl.DateTimeFormat(locale).format(
                          new Date(request.created_at),
                        )}
                      </p>
                      <h2>
                        <Link to={`/catalog/${material.id}`}>
                          {materialText(material, "name")}
                        </Link>
                      </h2>
                      <p>
                        {request.organization_name} ·{" "}
                        {formatKg(request.quantity_kg)} ·{" "}
                        {formatPrice(
                          requestTotal(
                            request.quantity_kg,
                            request.price_per_kg,
                          ),
                        )}
                      </p>
                    </div>
                    <span className={`status-badge status-${request.status}`}>
                      {request.status === "reused" && <Check size={14} />}
                      {t(labels[request.status])}
                    </span>
                  </div>
                  {request.purpose && (
                    <p className="request-purpose">
                      {t("Идея: ")}
                      {request.purpose}
                    </p>
                  )}
                  {request.status !== "cancelled" && (
                    <ol
                      className="request-progress"
                      aria-label={t("Этапы заявки")}
                    >
                      {[
                        t("Заявка"),
                        t("Резерв"),
                        t("Передача"),
                        t("Получение"),
                        t("Использование"),
                      ].map((label, index) => (
                        <li
                          key={label}
                          className={
                            stages.indexOf(request.status) >= index
                              ? "completed"
                              : ""
                          }
                        >
                          <span>
                            {stages.indexOf(request.status) >= index ? (
                              <Check size={12} />
                            ) : (
                              index + 1
                            )}
                          </span>
                          {t(label)}
                        </li>
                      ))}
                    </ol>
                  )}
                  {action && (
                    <div className="request-actions">
                      <p>
                        <span>{t("Следующий шаг")}</span>
                        <strong>{t(action.role)}</strong>
                      </p>
                      <div className="flex flex-wrap gap-3">
                        {["pending", "confirmed"].includes(request.status) && (
                          <button
                            className="button button-outline"
                            onClick={() =>
                              openDialog({
                                id: request.id,
                                target: "cancelled",
                                title: "Отменить заявку?",
                                description:
                                  "Заявка останется в истории со статусом «Отменено». Если материал был зарезервирован, этот объём снова станет доступен.",
                              })
                            }
                          >
                            {t("Отменить заявку")}
                          </button>
                        )}
                        <button
                          className="button button-dark"
                          onClick={() =>
                            openDialog({ id: request.id, ...action })
                          }
                        >
                          {t(action.title)}
                          <ArrowUpRight size={17} />
                        </button>
                      </div>
                    </div>
                  )}
                  {request.status === "reused" && (
                    <p className="reuse-confirmed">
                      <Recycle size={18} />
                      {formatKg(request.quantity_kg)}
                      {t(
                        " добавлено к повторному использованию. Спасибо за новый цикл!",
                      )}
                    </p>
                  )}
                </article>
              );
            })}
          </div>
        )}
      </section>
      {dialog && (
        <Dialog title={t(dialog.title)} onClose={() => setDialog(null)}>
          <p className="text-muted leading-relaxed">{t(dialog.description)}</p>
          <ErrorMessage>{error}</ErrorMessage>
          <div className="dialog-actions">
            <button
              className="button button-outline"
              onClick={() => setDialog(null)}
            >
              {t("Вернуться")}
            </button>
            <button
              className={`button ${dialog.reset || dialog.target === "cancelled" ? "button-danger" : "button-dark"}`}
              onClick={confirm}
            >
              {dialog.reset
                ? t("Очистить данные")
                : dialog.target === "cancelled"
                  ? t("Да, отменить")
                  : t(dialog.title)}
            </button>
          </div>
        </Dialog>
      )}
    </div>
  );
}
