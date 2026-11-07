import { useI18n } from "../i18n";
import { useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  ArrowLeft,
  ArrowUpRight,
  Upload,
  ImagePlus,
  X,
  Check,
  Sparkles,
} from "lucide-react";
import { ErrorMessage, ReuseIdeas } from "../components/UI";
import { conditions, materialTypes } from "../data/materials";
import { demoRepository } from "../lib/store";
import { toUnits } from "../lib/domain";
import { preparePhoto } from "../lib/image-upload";

const defaults = {
  name: "",
  material_type: "",
  total_kg: "",
  price_per_kg: "",
  city: "",
  condition: "",
  scrap_size: "",
  composition: "",
  organization_name: "",
  description: "",
  image: "",
  confirmed: false,
};

export default function CreateMaterial() {
  const { t } = useI18n();

  const [form, setForm] = useState(defaults);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState("");
  const [uploading, setUploading] = useState(false);
  const [saving, setSaving] = useState(false);
  const fileRef = useRef(null);
  const formRef = useRef(null);
  const lock = useRef(false);
  const navigate = useNavigate();
  const set = (key, value) => {
    setForm((previous) => ({
      ...previous,
      ...([
        "material_type",
        "total_kg",
        "condition",
        "city",
        "composition",
        "image",
        "scrap_size",
      ].includes(key)
        ? { confirmed: false }
        : {}),
      [key]: value,
    }));
    setErrors((previous) => ({ ...previous, [key]: "" }));
    setError("");
  };
  async function upload(file) {
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      set("image", await preparePhoto(file));
    } catch (err) {
      setErrors((previous) => ({ ...previous, image: err.message }));
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }
  function submit(event) {
    event.preventDefault();
    if (lock.current || uploading) return;
    const invalid = {};
    const required = {
      name: "Укажите название партии.",
      material_type: "Выберите тип материала.",
      city: "Укажите город.",
      condition: "Выберите состояние.",
      organization_name: "Укажите название организации.",
      image: "Добавьте хотя бы одно фото.",
    };
    Object.entries(required).forEach(([key, message]) => {
      if (!form[key].trim()) invalid[key] = message;
    });
    try {
      if (toUnits(form.total_kg) <= 0)
        invalid.total_kg = "Масса должна быть больше нуля.";
    } catch {
      invalid.total_kg =
        "Введите массу, например 12,5. Не больше трёх знаков после запятой.";
    }
    try {
      toUnits(form.price_per_kg, 2);
    } catch {
      invalid.price_per_kg =
        "Введите цену, например 80,50. Не больше двух знаков после запятой.";
    }
    if (!form.confirmed)
      invalid.confirmed = "Подтвердите характеристики партии.";
    setErrors(invalid);
    if (Object.keys(invalid).length) {
      setError("Проверьте поля формы.");
      requestAnimationFrame(() =>
        formRef.current?.querySelector('[aria-invalid="true"]')?.focus(),
      );
      return;
    }
    lock.current = true;
    setSaving(true);
    try {
      const id = demoRepository.createMaterial(form);
      navigate(`/catalog/${id}`, { state: { created: true } });
    } catch (err) {
      setError(err.message);
      lock.current = false;
      setSaving(false);
    }
  }
  const input = (key, label, options = {}) => (
    <label className="field" key={key} htmlFor={key}>
      {t(label)}
      <span className={options.optional ? "optional-label" : "required-label"}>
        {options.optional ? t("Необязательно") : t("Обязательное")}
      </span>
      <input
        id={key}
        value={form[key]}
        onChange={(e) => set(key, e.target.value)}
        aria-invalid={Boolean(errors[key])}
        aria-describedby={errors[key] ? `${key}-error` : undefined}
        maxLength={options.maxLength || 100}
        {...options.inputProps}
      />
      {errors[key] && (
        <span className="field-error" id={`${key}-error`}>
          {t(errors[key])}
        </span>
      )}
    </label>
  );
  const select = (key, label, values) => (
    <label className="field" htmlFor={key}>
      {t(label)}
      <span className="required-label">{t("Обязательное")}</span>
      <select
        id={key}
        value={form[key]}
        onChange={(e) => set(key, e.target.value)}
        aria-invalid={Boolean(errors[key])}
        aria-describedby={errors[key] ? `${key}-error` : undefined}
      >
        <option value="">{t("Выберите")}</option>
        {Object.entries(values).map(([value, label]) => (
          <option key={value} value={value}>
            {t(label)}
          </option>
        ))}
      </select>
      {errors[key] && (
        <span className="field-error" id={`${key}-error`}>
          {t(errors[key])}
        </span>
      )}
    </label>
  );
  return (
    <div className="page-blocks create-page">
      <section className="page-block create-heading-block">
        <Link to="/catalog" className="back-link">
          <ArrowLeft size={17} />
          {t("В каталог")}
        </Link>
        <div className="page-heading">
          <div>
            <p className="eyebrow">{t("Начните новый цикл")}</p>
            <h1>
              {t("Дайте материалу")}
              <br />
              {t("второй шанс.")}
            </h1>
            <p>{t("Несколько деталей — и ваша партия появится в каталоге.")}</p>
          </div>
        </div>
      </section>
      <form ref={formRef} onSubmit={submit} noValidate className="create-grid">
        <div className="create-main">
          <section className="form-section page-block">
            <div className="form-section-heading">
              <span>01</span>
              <h2>{t("О материале")}</h2>
            </div>
            {input("name", t("Название партии"), {
              maxLength: 200,
              inputProps: {
                placeholder: t("Например, остатки хлопка светлых оттенков"),
              },
            })}
            <div className="form-two-cols">
              {select("material_type", t("Тип материала"), materialTypes)}
              {select("condition", t("Состояние"), conditions)}
              {input("total_kg", t("Масса, кг"), {
                inputProps: { inputMode: "decimal", placeholder: "100" },
              })}
              {input("price_per_kg", t("Цена за кг, KGS"), {
                inputProps: { inputMode: "decimal", placeholder: "80" },
              })}
              {input("city", t("Город"), {
                inputProps: { placeholder: t("Бишкек") },
              })}
              {input("scrap_size", t("Размер отрезов"), {
                optional: true,
                inputProps: { placeholder: t("От 20 × 30 см") },
              })}
            </div>
            {input("composition", t("Состав, если известен"), {
              optional: true,
              maxLength: 200,
              inputProps: {
                placeholder: t("Оставьте пустым, если состав не подтверждён"),
              },
            })}
            {input("organization_name", t("Название организации"), {
              inputProps: {
                placeholder: t("Название вашего цеха или мастерской"),
              },
            })}
            <label className="field" htmlFor="description">
              {t("Описание")}
              <span className="optional-label">{t("Необязательно")}</span>
              <textarea
                id="description"
                rows={3}
                maxLength={1000}
                value={form.description}
                onChange={(e) => set("description", e.target.value)}
                placeholder={t(
                  "Расскажите о цвете, происхождении и особенностях материала",
                )}
              />
            </label>
          </section>
          <section className="form-section page-block">
            <div className="form-section-heading">
              <span>02</span>
              <h2>{t("Фото партии")}</h2>
            </div>
            <input
              ref={fileRef}
              className="sr-only"
              type="file"
              accept="image/jpeg,image/png,image/webp"
              aria-label={t("Выбрать фото партии")}
              onChange={(e) => upload(e.target.files?.[0])}
              tabIndex={-1}
            />
            {form.image ? (
              <div className="upload-preview">
                <img
                  src={form.image}
                  alt={t("Предпросмотр фото новой партии")}
                />
                <button
                  type="button"
                  className="icon-button"
                  onClick={() => set("image", "")}
                  aria-label={t("Удалить фото")}
                >
                  <X size={20} />
                </button>
              </div>
            ) : (
              <div
                className="upload-area"
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  if (!uploading) upload(e.dataTransfer.files?.[0]);
                }}
              >
                <ImagePlus size={32} strokeWidth={1.4} />
                <strong>
                  {uploading
                    ? t("Подготавливаем фото…")
                    : t("Покажите фактуру и цвет")}
                </strong>
                <p>{t("Перетащите фото сюда или выберите файл")}</p>
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  className="button button-outline"
                  disabled={uploading}
                  aria-invalid={Boolean(errors.image)}
                  aria-describedby="image-hint"
                >
                  <Upload size={17} />
                  {t("Загрузить фото")}
                </button>
                <span id="image-hint">
                  {t("JPG, PNG, WebP · до 10 МБ и 20 Мп")}
                </span>
              </div>
            )}
            {errors.image && (
              <p className="field-error" role="alert">
                {t(errors.image)}
              </p>
            )}
            <button
              className="text-link demo-photo-button"
              type="button"
              disabled={uploading}
              onClick={() => set("image", "/images/cotton-offcuts.webp")}
            >
              <Sparkles size={16} />
              {t("Выбрать фото хлопка")}
            </button>
          </section>
          <section className="form-section page-block">
            <div className="form-section-heading">
              <span>03</span>
              <h2>{t("Ваша проверка")}</h2>
            </div>
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={form.confirmed}
                onChange={(e) => set("confirmed", e.target.checked)}
                aria-invalid={Boolean(errors.confirmed)}
              />
              <span>
                {t(
                  "Я проверил(а) тип, массу, состояние и город. Неизвестный состав не выдаю за подтверждённый.",
                )}
              </span>
            </label>
            {errors.confirmed && (
              <p className="field-error">{t(errors.confirmed)}</p>
            )}
            <ErrorMessage>{error}</ErrorMessage>
            <button
              className="button button-dark w-full mt-5"
              type="submit"
              disabled={saving || uploading}
              aria-busy={saving}
            >
              {saving ? t("Сохраняем…") : t("Добавить в каталог")}
              {saving ? null : <ArrowUpRight size={19} />}
            </button>
          </section>
        </div>
        <aside className="create-aside page-block">
          <ReuseIdeas
            type={form.material_type}
            condition={form.condition}
            heading={
              form.material_type
                ? t("У этого материала есть будущее")
                : t("У каждой ткани есть возможности")
            }
          />
          <div className="form-tip">
            <Check size={20} />
            <p>
              {t(
                "Чем точнее параметры, тем проще найти подходящее применение. По фотографии нельзя достоверно определить состав ткани.",
              )}
            </p>
          </div>
        </aside>
      </form>
    </div>
  );
}
