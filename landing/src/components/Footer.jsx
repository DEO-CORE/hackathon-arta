import { Link } from "react-router-dom";
import { useI18n } from "../i18n";
import { Brand } from "./UI";

const sections = [
  {
    title: "Платформа",
    links: [
      ["О платформе", "/#about"],
      ["Каталог тканей", "/catalog"],
      ["Разместить партию", "/create"],
      ["Мои заявки", "/requests"],
    ],
  },
  {
    title: "Поддержка",
    links: [
      ["Как это работает", "/#how-it-works"],
      ["Частые вопросы", "/#faq"],
      ["Полезные материалы", "/#insights"],
      ["Помощь", "/#support"],
    ],
  },
];

export default function Footer() {
  const { t } = useI18n();
  return (
    <footer className="footer site-footer">
      <div className="container footer-card">
        <div className="footer-card-top">
          <div className="footer-intro">
            <Brand />
            <p className="footer-tagline">{t("Вторая жизнь текстиля")}</p>
            <p className="footer-message">
              {t("Соединяем тех, у кого остаётся ткань,")}{" "}
              {t("с теми, у кого есть идея.")}
            </p>
          </div>
          {sections.map((section) => (
            <nav
              key={section.title}
              className="footer-column"
              aria-label={t(section.title)}
            >
              <h2>{t(section.title)}</h2>
              {section.links.map(([label, to]) => (
                <Link key={to} to={to}>
                  {t(label)}
                </Link>
              ))}
            </nav>
          ))}
        </div>
        <img
          className="footer-credit"
          src="/images/made-by-deo.svg"
          alt="Made by DEO"
          width="632"
          height="128"
          loading="lazy"
        />
        <div className="footer-legal">
          <span>© {new Date().getFullYear()} ARTA</span>
          <span aria-hidden="true">·</span>
          <span>{t("Создано в Кыргызстане")}</span>
        </div>
      </div>
    </footer>
  );
}
