import { useI18n, materialText } from "../i18n";
import { useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowRight,
  ArrowDown,
  ArrowUpRight,
  Scissors,
  Package,
  Recycle,
  Store,
} from "lucide-react";
import { ButtonLink, Dialog } from "./UI";
import { guides, questions } from "../data/landing";
import {
  availableUnits,
  formatKg,
  formatPrice,
  fromUnits,
} from "../lib/domain";

export function HomeHeading({ title, children, action }) {
  const { t } = useI18n();

  return (
    <div className="home-heading">
      <h2>{t(title)}</h2>
      <p>{t(children)}</p>
      {action}
    </div>
  );
}

export function HomeMaterials({ materials, requests }) {
  const { t } = useI18n();

  return (
    <section className="home-section home-materials container" id="materials">
      <HomeHeading title={t("Материалы")}>
        {t("Подберите основу для следующей идеи.")}
        <br className="desktop-break" />
        {t(" Хорошая ткань заслуживает продолжения.")}
      </HomeHeading>
      <div className="home-material-showcase">
        <div className="home-material-list">
          {materials.slice(0, 3).map((material) => (
            <article className="home-material-row" key={material.id}>
              <div>
                <h3>
                  <Link to={`/catalog/${material.id}`}>
                    {materialText(material, "name")}
                  </Link>
                </h3>
                <p>
                  {formatPrice(material.price_per_kg)}
                  {t(" / кг ·")}{" "}
                  {formatKg(fromUnits(availableUnits(material, requests)))}
                </p>
                <ButtonLink to={`/catalog/${material.id}`}>
                  {t("Подробнее ")}
                  <ArrowRight size={17} />
                </ButtonLink>
              </div>
              <img
                src={material.image}
                alt={t("Иллюстрация: {{0}}", {
                  0: materialText(material, "name"),
                })}
                loading="lazy"
                width="240"
                height="240"
              />
            </article>
          ))}
          {materials.length === 0 && (
            <div className="home-material-empty">
              <h3>{t("Свободных партий пока нет")}</h3>
              <p>{t("Добавьте материал, чтобы начать новый цикл.")}</p>
              <ButtonLink to="/create">
                {t("Разместить партию ")}
                <ArrowRight size={17} />
              </ButtonLink>
            </div>
          )}
        </div>
        <Link to="/catalog" className="home-material-feature">
          <img
            src="/images/textile-hero.webp"
            alt={t("Коллекция тканей для новых проектов")}
            loading="lazy"
            width="720"
            height="900"
          />
          <span>
            {t("Больше")}
            <br />
            {t("материалов")}{" "}
            <span>
              <ArrowRight size={24} />
            </span>
          </span>
        </Link>
      </div>
    </section>
  );
}

export function HomeAudience({ reused }) {
  const { t } = useI18n();

  const items = [
    {
      icon: Package,
      name: "Швейному цеху",
      text: "После заказа остались лоскуты и отрезы. Вместо того чтобы занимать склад, их можно описать, взвесить и предложить другим производствам.",
      to: "/create",
      link: "Разместить остатки",
    },
    {
      icon: Scissors,
      name: "Небольшой мастерской",
      text: "Для сумок, игрушек или декора не всегда нужен целый рулон. В каталоге можно подобрать материал под размер изделия, нужную массу и бюджет.",
      to: "/catalog",
      link: "Найти материал",
    },
    {
      icon: Store,
      name: "Новому производству",
      text: "Идея начинается с материала. Посмотрите доступные партии и возможные направления использования, чтобы выбрать основу для своего проекта.",
      to: "/catalog",
      link: "Посмотреть партии",
    },
  ];
  return (
    <section className="home-section container" id="for-whom">
      <HomeHeading title={t("Кому подходит ARTA")}>
        {t("Разные задачи — общий ресурс.")}
        <br className="desktop-break" />
        {t(" Примеры использования платформы.")}
      </HomeHeading>
      <div className="home-audience-grid">
        {items.map(({ icon: Icon, ...item }) => (
          <article className="home-audience-card" key={item.name}>
            <p>{t(item.text)}</p>
            <ArrowUpRight
              className="home-audience-mark"
              size={28}
              aria-hidden="true"
            />
            <h3>
              <span>
                <Icon size={20} strokeWidth={1.5} />
              </span>
              {t(item.name)}
            </h3>
            <Link to={item.to}>
              {t(item.link)} <ArrowRight size={15} />
            </Link>
          </article>
        ))}
        <article className="home-audience-card">
          <p>
            {t(
              "Результат можно увидеть в цифрах. Считаем массу материала только после подтверждения использования, отдельно от резерва и передачи.",
            )}
          </p>
          <strong className="home-audience-result">{formatKg(reused)}</strong>
          <h3>
            <span>
              <Recycle size={20} strokeWidth={1.5} />
            </span>
            {t("Повторно использовано")}
          </h3>
          <Link to="/requests">
            {t("Посмотреть результат ")}
            <ArrowRight size={15} />
          </Link>
        </article>
      </div>
    </section>
  );
}

export function HomeBusiness() {
  const { t } = useI18n();

  return (
    <section className="home-section container" id="business-model">
      <HomeHeading title={t("Расти вместе")}>
        {t("Простой старт сегодня.")}
        <br className="desktop-break" />
        {t(" Варианты развития платформы завтра.")}
      </HomeHeading>
      <div className="home-plans">
        <img
          className="home-plans-background"
          src="/images/cotton-offcuts.webp"
          alt=""
          loading="lazy"
          width="1400"
          height="800"
        />
        <article className="home-plan">
          <h3>{t("Знакомство")}</h3>
          <strong>{t("Бесплатно")}</strong>
          <span>{t("для первого знакомства")}</span>
          <ul>
            <li>{t("Просмотр материалов")}</li>
            <li>{t("Размещение партий")}</li>
            <li>{t("Заявки и учёт результата")}</li>
          </ul>
          <p>
            <b>{t("Для кого:")}</b>
            {t(
              " мастерские и предприятия, которые хотят проверить, как работает ARTA.",
            )}
          </p>
          <ButtonLink to="/catalog" variant="outline">
            {t("Открыть каталог")}
          </ButtonLink>
        </article>
        <article className="home-plan home-plan-featured">
          <h3>{t("После сделки")}</h3>
          <strong>5%</strong>
          <span>{t("планируемая комиссия")}</span>
          <ul>
            <li>{t("Доход платформы от сделки")}</li>
            <li>{t("Связь цехов и покупателей")}</li>
            <li>{t("Развитие сервиса подбора")}</li>
            <li>{t("Учёт использования сырья")}</li>
          </ul>
          <p>
            <b>{t("Идея модели:")}</b>
            {t(" платформа зарабатывает, когда материал находит покупателя.")}
          </p>
          <ButtonLink to="/create" variant="dark">
            {t("Попробовать размещение")}
          </ButtonLink>
        </article>
        <article className="home-plan">
          <h3>{t("Для предприятий")}</h3>
          <strong>{t("Подписка")}</strong>
          <span>{t("альтернативная бизнес-модель")}</span>
          <ul>
            <li>{t("Для регулярных партий")}</li>
            <li>{t("Для производственных команд")}</li>
            <li>{t("Условия после проверки спроса")}</li>
            <li>{t("Стоимость ещё не определена")}</li>
          </ul>
          <p>
            <b>{t("В перспективе:")}</b>
            {t(
              " отдельный формат для предприятий с постоянным потоком текстильных остатков.",
            )}
          </p>
          <ButtonLink to="/#benefits" variant="outline">
            {t("Возможности ARTA")}
          </ButtonLink>
        </article>
      </div>
    </section>
  );
}

export function HomeInsights() {
  const { t } = useI18n();

  const [selected, setSelected] = useState(null);
  return (
    <section className="home-section home-insights" id="insights">
      <div className="container">
        <HomeHeading title={t("Полезное о материалах")}>
          {t("От первого лоскута до новой партии:")}
          <br className="desktop-break" />
          {t(" короткие подсказки для работы с ARTA.")}
        </HomeHeading>
        <div className="home-guide-grid">
          {guides.map((guide) => (
            <article className="home-guide" key={guide.id}>
              <img
                src={guide.image}
                alt={t(guide.alt)}
                loading="lazy"
                width="600"
                height="480"
              />
              <h3>{t(guide.title)}</h3>
              <button
                className="button button-primary"
                onClick={() => setSelected(guide)}
                aria-label={t("Читать: {{0}}", { 0: t(guide.title) })}
              >
                {t("Читать статью ")}
                <ArrowRight size={17} />
              </button>
            </article>
          ))}
        </div>
      </div>
      {selected && (
        <Dialog
          title={t(selected.title)}
          onClose={() => setSelected(null)}
          wide
        >
          <div className="home-guide-body">
            <img
              src={selected.image}
              alt={t(selected.alt)}
              width="800"
              height="440"
            />
            {selected.paragraphs.map((text) => (
              <p key={text}>{t(text)}</p>
            ))}
            <ButtonLink to={selected.to} onClick={() => setSelected(null)}>
              {t(selected.action)} <ArrowRight size={17} />
            </ButtonLink>
          </div>
        </Dialog>
      )}
    </section>
  );
}

export function HomeFAQ() {
  const { t } = useI18n();

  return (
    <section className="home-section container" id="faq">
      <HomeHeading title={t("Частые вопросы")}>
        {t("Всё, что поможет разобраться")}
        <br className="desktop-break" />
        {t(" перед первым шагом.")}
      </HomeHeading>
      <div className="home-faq-grid">
        {[questions.slice(0, 4), questions.slice(4)].map((column, index) => (
          <div key={index}>
            {column.map((item, index) => (
              <details
                className="home-faq"
                key={item.question}
                open={index === 0}
              >
                <summary>
                  <span>
                    <ArrowDown size={18} />
                  </span>
                  {t(item.question)}
                </summary>
                <p>{t(item.answer)}</p>
              </details>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}

export function HomeSupport() {
  const { t } = useI18n();

  const [open, setOpen] = useState(false);
  return (
    <section className="home-section home-support" id="support">
      <div className="container">
        <HomeHeading title={t("С чего начать?")}>
          {t("Поможем сделать первый шаг.")}
        </HomeHeading>
        <div className="home-story">
          <div className="home-story-image">
            <img
              src="/images/workshop.webp"
              alt={t(
                "Мастерицы сортируют ткань в швейной мастерской; иллюстрация проекта",
              )}
              loading="lazy"
              width="1000"
              height="650"
            />
          </div>
          <div className="home-support-copy">
            <p>
              {t(
                "У вас осталась ткань или есть идея для нового изделия? Выберите свой путь: разместить партию, найти материал или посмотреть, как работает платформа.",
              )}
            </p>
            <button
              className="button button-primary"
              onClick={() => setOpen(true)}
            >
              {t("Помочь с первым шагом")}
            </button>
          </div>
        </div>
      </div>
      {open && (
        <Dialog
          title={t("Какой у вас первый шаг?")}
          onClose={() => setOpen(false)}
        >
          <div className="home-help-options">
            <Link to="/create" onClick={() => setOpen(false)}>
              <Package size={24} />
              <span>
                <strong>{t("У меня есть остатки ткани")}</strong>
                <small>{t("Подготовьте фото, массу и описание партии.")}</small>
              </span>
              <ArrowRight size={19} />
            </Link>
            <Link to="/catalog" onClick={() => setOpen(false)}>
              <Scissors size={24} />
              <span>
                <strong>{t("Мне нужен материал")}</strong>
                <small>{t("Выберите ткань, город и нужное количество.")}</small>
              </span>
              <ArrowRight size={19} />
            </Link>
            <Link to="/requests" onClick={() => setOpen(false)}>
              <Recycle size={24} />
              <span>
                <strong>{t("Хочу проверить результат")}</strong>
                <small>{t("Посмотрите заявки и этапы использования.")}</small>
              </span>
              <ArrowRight size={19} />
            </Link>
          </div>
        </Dialog>
      )}
    </section>
  );
}
