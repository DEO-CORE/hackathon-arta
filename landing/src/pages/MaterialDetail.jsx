import { useI18n, materialText } from "../i18n";
import { useRef, useState } from "react";
import { Link, useParams, useLocation } from "react-router-dom";
import {
  ArrowLeft,
  ArrowUpRight,
  MapPin,
  Package,
  CheckCircle2,
} from "lucide-react";
import {
  ButtonLink,
  Dialog,
  EmptyState,
  ErrorMessage,
  ReuseIdeas,
} from "../components/UI";
import { conditions, materialTypes } from "../data/materials";
import { useDemo, demoRepository } from "../lib/store";
import {
  availableUnits,
  fromUnits,
  formatKg,
  formatPrice,
  requestTotal,
} from "../lib/domain";

function RequestDialog({ material, available, onClose }) {
  const { t } = useI18n();

  const [quantity, setQuantity] = useState("1");
  const [organization, setOrganization] = useState("");
  const [purpose, setPurpose] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const lock = useRef(false);
  let total = "—";
  try {
    total = formatPrice(requestTotal(quantity, material.price_per_kg));
  } catch {
    /* Partial input has no estimate. */
  }
  function submit(event) {
    event.preventDefault();
    if (lock.current) return;
    lock.current = true;
    try {
      demoRepository.createRequest({
        material_id: material.id,
        quantity_kg: quantity,
        organization_name: organization,
        purpose,
      });
      setSuccess(true);
    } catch (err) {
      setError(err.message);
      lock.current = false;
    }
  }
  return (
    <Dialog
      title={success ? t("Заявка сохранена") : t("Начать новый цикл")}
      onClose={onClose}
    >
      {success ? (
        <div className="success-content">
          <span className="success-symbol">
            <CheckCircle2 size={35} />
          </span>
          <h3>{t("Первый шаг сделан.")}</h3>
          <p>
            {t(
              "Заявка сохранена. Откройте «Мои заявки», чтобы посмотреть её параметры и этапы работы с материалом.",
            )}
          </p>
          <ButtonLink to="/requests" variant="dark" onClick={onClose}>
            {t("Перейти к заявке ")}
            <ArrowUpRight size={18} />
          </ButtonLink>
        </div>
      ) : (
        <form onSubmit={submit} className="form-stack" noValidate>
          <p className="text-muted text-sm">
            {materialText(material, "name")}
            {t(" · доступно ")}
            {formatKg(fromUnits(available))}
          </p>
          <label className="field">
            {t("Масса, кг ")}
            <span className="required-label">{t("Обязательное")}</span>
            <input
              type="text"
              inputMode="decimal"
              required
              value={quantity}
              onChange={(e) => {
                setQuantity(e.target.value);
                setError("");
              }}
              maxLength={13}
            />
          </label>
          <label className="field">
            {t("Название мастерской")}{" "}
            <span className="required-label">{t("Обязательное")}</span>
            <input
              required
              maxLength={100}
              value={organization}
              onChange={(e) => {
                setOrganization(e.target.value);
                setError("");
              }}
              placeholder={t("Например, мастерская «Курак»")}
            />
          </label>
          <label className="field">
            {t("Для чего нужен материал")}{" "}
            <span className="optional-label">{t("Необязательно")}</span>
            <textarea
              rows={2}
              maxLength={500}
              value={purpose}
              onChange={(e) => setPurpose(e.target.value)}
              placeholder={t("Расскажите о вашей идее")}
            />
          </label>
          <div className="request-total">
            <span>{t("Стоимость партии")}</span>
            <strong>{total}</strong>
          </div>
          <p className="text-xs text-muted">
            {t(
              "Предварительная стоимость без доставки. Условия согласуйте с продавцом.",
            )}
          </p>
          <ErrorMessage>{error}</ErrorMessage>
          <button className="button button-dark w-full" type="submit">
            {t("Создать заявку ")}
            <ArrowUpRight size={18} />
          </button>
        </form>
      )}
    </Dialog>
  );
}

export default function MaterialDetail() {
  const { t } = useI18n();

  const { id } = useParams();
  const location = useLocation();
  const state = useDemo();
  const [requestOpen, setRequestOpen] = useState(false);
  const material = state.materials.find((m) => m.id === id);
  if (!material)
    return (
      <div className="page-blocks">
        <div className="page-block empty-page-block">
          <EmptyState
            title={t("Партия не найдена")}
            description={t(
              "Эта партия больше недоступна. Выберите другой материал в каталоге.",
            )}
          >
            <ButtonLink to="/catalog" variant="dark">
              {t("Открыть каталог")}
            </ButtonLink>
          </EmptyState>
        </div>
      </div>
    );
  const available = availableUnits(material, state.requests);
  return (
    <div className="page-blocks material-detail-page">
      <section className="page-block detail-block">
        <Link to="/catalog" className="back-link">
          <ArrowLeft size={17} />
          {t("Назад в каталог")}
        </Link>
        {location.state?.created && (
          <p className="success-banner" role="status">
            <CheckCircle2 size={18} />
            {t("Партия добавлена в каталог.")}
          </p>
        )}
        <div className="detail-grid">
          <div className="detail-photo">
            <img
              src={material.image}
              alt={t("Фото партии {{0}}", {
                0: materialText(material, "name"),
              })}
              width="900"
              height="1000"
            />
            {material.is_own && (
              <span className="photo-tag">{t("Ваша партия")}</span>
            )}
          </div>
          <div className="detail-info">
            <p className="eyebrow">
              {t(materialTypes[material.material_type])}
            </p>
            <h1>{materialText(material, "name")}</h1>
            <p className="detail-location">
              <MapPin size={17} />
              {materialText(material, "city")}
              <span>·</span>
              {materialText(material, "organization_name")}
            </p>
            <p className="detail-description">
              {materialText(material, "description")}
            </p>
            <dl className="spec-list">
              {[
                [t("Свободный остаток"), formatKg(fromUnits(available))],
                [t("Общая масса"), formatKg(material.total_kg)],
                [
                  t("Размер отрезов"),
                  materialText(material, "scrap_size") || t("Не указан"),
                ],
                [t("Состояние"), t(conditions[material.condition])],
                [
                  t("Состав"),
                  materialText(material, "composition") || t("Не подтверждён"),
                ],
              ].map(([key, value]) => (
                <div key={key}>
                  <dt>{key}</dt>
                  <dd>{value}</dd>
                </div>
              ))}
            </dl>
            <div className="detail-price">
              <strong>{formatPrice(material.price_per_kg)}</strong>
              <span>{t("за 1 кг")}</span>
            </div>
            {available > 0 ? (
              <button
                className="button button-dark w-full"
                onClick={() => setRequestOpen(true)}
              >
                {t("Оставить заявку ")}
                <ArrowUpRight size={19} />
              </button>
            ) : (
              <p className="notice">
                <Package size={18} />
                {t(
                  "Свободного остатка нет. Материал зарезервирован или уже передан.",
                )}
              </p>
            )}
          </div>
        </div>
      </section>
      <section className="page-block detail-reuse">
        <ReuseIdeas
          type={material.material_type}
          condition={material.condition}
        />
        <aside className="detail-aside">
          <span className="eyebrow">{t("Перед использованием")}</span>
          <h3>
            {t("Хорошая идея")}
            <br />
            {t("начинается с проверки.")}
          </h3>
          <p>
            {t(
              "Состав, плотность и прочность нужно подтвердить. Для детских изделий и других специальных задач действуют отдельные требования к материалам.",
            )}
          </p>
          <img
            src="/images/upcycled-bag.webp"
            alt={t("Пример нового изделия из ткани")}
            loading="lazy"
            width="400"
            height="300"
          />
        </aside>
      </section>
      {requestOpen && (
        <RequestDialog
          material={material}
          available={available}
          onClose={() => setRequestOpen(false)}
        />
      )}
    </div>
  );
}
