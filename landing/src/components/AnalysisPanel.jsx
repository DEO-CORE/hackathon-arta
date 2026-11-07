import { useI18n } from "../i18n";
import { useState } from "react";
const uses = {
  cleaning_rags: "Ветошь",
  stuffing_filling: "Наполнитель",
  patchwork_crafts: "Пэчворк и творчество",
  accessories_small_goods: "Аксессуары",
  insulation_padding: "Подкладка и изоляция",
  recycling_shredding: "Переработка",
  other: "Другое",
};
export default function AnalysisPanel({
  analysis,
  onAnalyze,
  disabled = false,
}) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function run() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await onAnalyze();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="reuse-panel">
      <p className="eyebrow">{t("Анализ фотографии")}</p>
      <h2>{t("Предложения ИИ")}</h2>
      <p>
        {t(
          "Цвет, рисунок, фактура и возможные применения. Состав, массу и пригодность подтверждает человек.",
        )}
      </p>
      {onAnalyze && (
        <button
          type="button"
          className="button button-outline"
          onClick={run}
          disabled={busy || disabled}
        >
          {t(busy ? "Анализируем…" : "Проанализировать фото")}
        </button>
      )}
      {error && <p role="alert">{t(error)}</p>}
      {analysis && (
        <>
          <p role="status">
            {t(
              {
                pending: "В очереди",
                running: "Анализируем фото",
                succeeded: "Анализ готов",
                failed: "Анализ недоступен. Можно заполнить данные вручную.",
                interrupted: "Анализ прерван. Повторите запрос.",
              }[analysis.status],
            )}
          </p>
          {analysis.mode && analysis.mode !== "live" && (
            <p className="notice">
              {t(
                "Демо: результат подготовлен заранее, это не реальный анализ фото.",
              )}
            </p>
          )}
          {analysis.is_current === false && (
            <p className="notice">
              {t(
                "Данные партии изменились. Анализ устарел — запустите заново.",
              )}
            </p>
          )}
          {analysis.status === "succeeded" && analysis.is_current !== false && (
            <>
              <dl>
                {Object.entries(analysis.result.visual_features).map(
                  ([key, v]) => (
                    <div key={key}>
                      <dt>
                        {t(
                          {
                            color: "Цвет",
                            pattern: "Рисунок",
                            apparent_texture: "Видимая фактура",
                          }[key],
                        )}
                      </dt>
                      <dd>
                        {v.description ||
                          v.primary ||
                          v.value ||
                          "Не определено"}{" "}
                        ·{" "}
                        {t(
                          {
                            high: "высокая уверенность",
                            medium: "средняя уверенность",
                            low: "низкая уверенность",
                            unknown: "неизвестно",
                          }[v.confidence],
                        )}
                      </dd>
                    </div>
                  ),
                )}
              </dl>
              <div className="reuse-list">
                {analysis.result.reuse_options.map((o) => (
                  <article key={o.reuse_type}>
                    <div>
                      <h3>{t(uses[o.reuse_type])}</h3>
                      <p>{o.reason}</p>
                    </div>
                  </article>
                ))}
              </div>
              <p>{analysis.result.notes}</p>
            </>
          )}
        </>
      )}
      {!analysis && (
        <p className="text-muted">
          {t("Результат появится после обработки фотографии сервером.")}
        </p>
      )}
    </section>
  );
}
