import { ArrowUpRight, LockKeyhole } from "lucide-react";
import { useI18n } from "../i18n";
import { ButtonLink } from "./UI";

export default function AccountGate({ title, description, loading = false }) {
  const { t } = useI18n();
  return (
    <div className="page-blocks">
      <section className="page-block account-gate" aria-busy={loading}>
        <div className="account-gate-icon" aria-hidden="true">
          <LockKeyhole size={28} strokeWidth={1.5} />
        </div>
        <h1>{t(title)}</h1>
        <p role={loading ? "status" : undefined}>{t(description)}</p>
        {!loading && (
          <div className="account-gate-actions">
            <ButtonLink to="/login" variant="dark">
              {t("Войти")}
              <ArrowUpRight size={18} />
            </ButtonLink>
            <ButtonLink to="/catalog" variant="outline">
              {t("Каталог тканей")}
            </ButtonLink>
          </div>
        )}
      </section>
    </div>
  );
}
