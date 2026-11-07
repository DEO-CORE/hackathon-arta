import { useI18n, materialText } from "../i18n";
import { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import { Search, SlidersHorizontal, ArrowUpRight, X } from "lucide-react";
import { ButtonLink, EmptyState, MaterialCard } from "../components/UI";
import { materialTypes } from "../data/materials";
import { useStore, loadCatalog } from "../lib/store";
import { availableUnits, toUnits } from "../lib/domain";
import { languages, translate } from "../i18n/locale";

export default function Catalog() {
  const { t, locale } = useI18n();

  const state = useStore();
  const [params, setParams] = useSearchParams();
  const [limit, setLimit] = useState(6);
  const [page, setPage] = useState(1);
  const query = params.get("q") || "";
  const type = params.get("type") || "";
  const city = params.get("city") || "";
  const sort = params.get("sort") || "recent";
  const update = (key, value) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
    setLimit(6);
    setPage(1);
  };
  useEffect(() => {
    if (state.mode === "api") {
      const timer = setTimeout(
        () =>
          loadCatalog({
            page: String(page),
            page_size: "6",
            ...(query.trim() ? { q: query.trim() } : {}),
            ...(type ? { material_type: type } : {}),
            ...(city ? { city } : {}),
            sort:
              { "price-low": "price_asc", mass: "available_kg_desc" }[sort] ||
              "created_at_desc",
          }),
        200,
      );
      return () => clearTimeout(timer);
    }
  }, [query, type, city, sort, page, state.mode]);
  const cities =
    state.mode === "api"
      ? state.cities
      : [...new Set(state.materials.map((m) => m.city))];
  const materials =
    state.mode === "api"
      ? state.catalog
      : state.materials
          .filter((m) => {
            const text = languages
              .map(
                ({ code }) =>
                  `${materialText(m, "name", code)} ${translate(materialTypes[m.material_type], {}, code)} ${materialText(m, "city", code)} ${materialText(m, "description", code)}`,
              )
              .join(" ")
              .toLocaleLowerCase(locale);
            return (
              (!query ||
                text.includes(query.toLocaleLowerCase(locale).trim())) &&
              (!type || m.material_type === type) &&
              (!city || m.city === city) &&
              availableUnits(m, state.requests) > 0
            );
          })
          .sort((a, b) =>
            sort === "price-low"
              ? toUnits(a.price_per_kg, 2) - toUnits(b.price_per_kg, 2)
              : sort === "mass"
                ? availableUnits(b, state.requests) -
                  availableUnits(a, state.requests)
                : b.created_at.localeCompare(a.created_at),
          );
  const active = Boolean(query || type || city);
  return (
    <div className="catalog-page page-blocks">
      <section className="catalog-hero page-block">
        <div className="container catalog-hero-inner">
          <div>
            <h1>{t("Каталог материалов")}</h1>
            <p>{t("Найдите основу для вашей следующей идеи.")}</p>
            <ButtonLink to="/create">
              {t("Разместить партию ")}
              <ArrowUpRight size={18} />
            </ButtonLink>
          </div>
          <img
            src="/images/cotton-offcuts.webp"
            alt={t("Хлопковые лоскуты для повторного использования")}
            width="440"
            height="440"
          />
        </div>
      </section>
      <section className="page-block catalog-content">
        <div className="catalog-section-heading">
          <h2>{t("Подберите партию")}</h2>
          <p>
            {t("Найдите нужную ткань по материалу,")}
            <br className="desktop-break" />
            {t(" названию или городу.")}
          </p>
        </div>
        <div
          className="catalog-filter-panel"
          role="search"
          aria-label={t("Поиск партий")}
        >
          <div className="catalog-toolbar">
            <div className="search-field">
              <Search size={20} />
              <label className="sr-only" htmlFor="catalog-search">
                {t("Поиск материалов")}
              </label>
              <input
                id="catalog-search"
                type="search"
                placeholder={t("Название, материал или город")}
                value={query}
                onChange={(e) => update("q", e.target.value)}
              />
            </div>
            <div className="catalog-city">
              <SlidersHorizontal size={18} />
              <label className="sr-only" htmlFor="city-filter">
                {t("Город")}
              </label>
              <select
                id="city-filter"
                value={city}
                onChange={(e) => update("city", e.target.value)}
              >
                <option value="">{t("Все города")}</option>
                {cities.map((city) => (
                  <option key={city} value={city}>
                    {t(city)}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="filter-chips" aria-label={t("Тип материала")}>
            <button
              onClick={() => update("type", "")}
              className={`filter-chip ${!type ? "selected" : ""}`}
              aria-pressed={!type}
            >
              {t("Все материалы")}
            </button>
            {Object.entries(materialTypes).map(([key, label]) => (
              <button
                key={key}
                onClick={() => update("type", key)}
                className={`filter-chip ${type === key ? "selected" : ""}`}
                aria-pressed={type === key}
              >
                {t(label)}
              </button>
            ))}
          </div>
        </div>
        <div className="catalog-results-bar">
          <p aria-live="polite">
            {t("Найдено партий: ")}
            <strong>
              {state.mode === "api" ? state.catalogTotal : materials.length}
            </strong>
            {active && (
              <button
                className="clear-filter"
                onClick={() => {
                  setParams({});
                  setLimit(6);
                  setPage(1);
                }}
              >
                {t("Сбросить ")}
                <X size={13} />
              </button>
            )}
          </p>
          <label className="sort-select">
            {t("Сначала")}
            <select
              value={sort}
              onChange={(e) => update("sort", e.target.value)}
              aria-label={t("Сортировка")}
            >
              <option value="recent">{t("новые")}</option>
              <option value="price-low">{t("дешевле")}</option>
              <option value="mass">{t("больше объём")}</option>
            </select>
          </label>
        </div>
        {state.loading && <p role="status">{t("Загрузка каталога…")}</p>}
        {materials.length ? (
          <>
            <div className="material-grid">
              {materials.slice(0, limit).map((m) => (
                <MaterialCard
                  key={m.id}
                  material={m}
                  requests={state.requests}
                />
              ))}
            </div>
            {state.mode === "api" && (
              <div className="dialog-actions">
                <button
                  disabled={page === 1 || state.loading}
                  onClick={() => setPage(page - 1)}
                  className="button button-outline"
                >
                  Назад
                </button>
                <span>
                  {t("Страница")}
                  {page}
                </span>
                <button
                  disabled={page * 6 >= state.catalogTotal || state.loading}
                  onClick={() => setPage(page + 1)}
                  className="button button-outline"
                >
                  {t("Далее")}
                </button>
              </div>
            )}
            {state.mode !== "api" && materials.length > limit && (
              <div className="mt-9 text-center">
                <button
                  className="button button-outline"
                  onClick={() => setLimit(limit + 6)}
                >
                  {t("Показать ещё")}
                </button>
              </div>
            )}
          </>
        ) : (
          <EmptyState
            title={t("Пока нет подходящих материалов")}
            description={t(
              "Попробуйте другой материал, город или более короткий запрос.",
            )}
          >
            <button
              className="button button-dark"
              onClick={() => setParams({})}
            >
              {t("Сбросить фильтры")}
            </button>
          </EmptyState>
        )}
      </section>
    </div>
  );
}
