import { useI18n } from "../i18n";
import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowUpRight,
  ArrowRight,
  ArrowLeft,
  Recycle,
  Scissors,
  Spool,
  Leaf,
} from "lucide-react";
import { ButtonLink } from "../components/UI";
import {
  HomeHeading,
  HomeMaterials,
  HomeAudience,
  HomeBusiness,
  HomeInsights,
  HomeFAQ,
  HomeSupport,
} from "../components/HomeSections";
import { useDemo } from "../lib/store";
import { summarize, formatKg, availableUnits } from "../lib/domain";
import { useCardShuffle, useSectionReveal } from "../lib/motion";

const steps = [
  {
    title: "Расскажите о материале",
    text: "Добавьте фотографию, тип ткани, массу и город. Подтвердите характеристики партии — то, что осталось у вас, может стать началом чужой идеи.",
    image: "/images/workshop.webp",
    alt: "Мастерицы подготавливают остатки ткани для нового использования",
  },
  {
    title: "Найдите возможности",
    text: "Подберите материал в каталоге или посмотрите варианты применения своих остатков. Рекомендации учитывают тип и состояние ткани.",
    image: "/images/denim-offcuts.webp",
    alt: "Деним для новых изделий и проектов",
  },
  {
    title: "Дайте ткани продолжение",
    text: "Оставьте заявку и согласуйте партию. Подтвердите передачу, получение и использование — результат появится в счётчике повторно использованного сырья.",
    image: "/images/upcycled-bag.webp",
    alt: "Готовая сумка из текстильных остатков",
  },
];

function ProcessCarousel() {
  const { t } = useI18n();

  const [step, setStep] = useState(0);
  const carousel = useRef(null);
  const pointer = useRef(null);
  const capture = useCardShuffle(step, carousel);
  const changeStep = (direction) => {
    capture(direction);
    setStep((current) => (current + direction + steps.length) % steps.length);
  };
  return (
    <div
      ref={carousel}
      className="home-process-layout"
      role="region"
      aria-label={t("Как работает ARTA")}
      aria-roledescription={t("карусель")}
      tabIndex={0}
      onKeyDown={(event) => {
        if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return;
        event.preventDefault();
        changeStep(event.key === "ArrowRight" ? 1 : -1);
      }}
    >
      <div className="home-process-content">
        <div className="home-process-text">
          <div aria-live="polite" aria-atomic="true">
            <div key={step} className="process-copy process-copy-current">
              <span className="home-process-number">0{step + 1}</span>
              <h3>{t(steps[step].title)}</h3>
              <p>{t(steps[step].text)}</p>
            </div>
          </div>
          <div className="process-copy-ghost" aria-hidden="true" inert />
        </div>
        <div className="home-process-controls">
          <button
            type="button"
            aria-label={t("Предыдущий шаг")}
            onClick={() => changeStep(-1)}
          >
            <ArrowLeft size={20} />
          </button>
          <button
            type="button"
            aria-label={t("Следующий шаг")}
            onClick={() => changeStep(1)}
          >
            <ArrowRight size={20} />
          </button>
        </div>
        <span className="home-process-counter" aria-hidden="true">
          <span className="process-counter-window">
            <span className="process-counter-outgoing" />
            <span key={step} className="process-counter-current">
              0{step + 1}
            </span>
          </span>
          <span>/03</span>
        </span>
      </div>
      <div
        className="home-process-photos motion-card-stack"
        onPointerDown={(event) => {
          if (event.pointerType !== "mouse")
            pointer.current = { x: event.clientX, y: event.clientY };
        }}
        onPointerCancel={() => {
          pointer.current = null;
        }}
        onPointerUp={(event) => {
          const start = pointer.current;
          pointer.current = null;
          if (!start) return;
          const dx = event.clientX - start.x;
          const dy = event.clientY - start.y;
          if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) * 1.3)
            changeStep(dx < 0 ? 1 : -1);
        }}
      >
        {steps.map((item, index) => (
          <img
            key={item.image}
            className={`home-process-photo depth-${(index - step + steps.length) % steps.length}`}
            data-depth={(index - step + steps.length) % steps.length}
            src={item.image}
            alt={index === step ? t(item.alt) : ""}
            aria-hidden={index !== step}
            loading="lazy"
            width="500"
            height="640"
            draggable={false}
          />
        ))}
      </div>
    </div>
  );
}

export default function Home() {
  const { t } = useI18n();

  const page = useRef(null);
  useSectionReveal(page);
  const state = useDemo();
  const summary = summarize(state);
  const materials = state.materials.filter(
    (material) => availableUnits(material, state.requests) > 0,
  );
  return (
    <div className="home-page home-blocks" ref={page}>
      <section className="home-hero">
        <div className="container">
          <div className="home-hero-intro">
            <h1>
              {t("Дайте остаткам ткани")}
              <br />
              {t("новую жизнь вместе с ARTA")}
            </h1>
            <p>{t("Материалы находят мастерские. Идеи становятся вещами.")}</p>
            <div className="home-hero-ornaments" aria-hidden="true">
              <span>
                <Scissors />
              </span>
              <span>
                <Leaf />
              </span>
              <span>
                <Spool />
              </span>
              <span>
                <Recycle />
              </span>
            </div>
          </div>
          <div className="home-hero-collage">
            <div className="home-hero-stock">
              <div>
                <strong>
                  {materials.length}
                  {t(" партий")}
                </strong>
                <p>
                  {t("Для новых идей")}
                  <br />
                  {t("в каталоге")}
                </p>
              </div>
              <img
                src="/images/cotton-offcuts.webp"
                alt={t("Натуральные хлопковые лоскуты")}
                width="300"
                height="380"
              />
            </div>
            <img
              className="home-hero-fabric"
              src="/images/textile-hero.webp"
              alt={t("Ткани природных оттенков для повторного использования")}
              width="400"
              height="680"
            />
            <div className="home-hero-center">
              <div className="home-hero-actions">
                <ButtonLink to="/catalog" variant="outline">
                  {t("Найти материал")}
                </ButtonLink>
                <ButtonLink to="/create">{t("Разместить партию")}</ButtonLink>
              </div>
              <div className="home-hero-metric">
                <strong>{formatKg(summary.available)}</strong>
                <span>{t("Доступно в каталоге")}</span>
              </div>
            </div>
            <div className="home-hero-product">
              <img
                src="/images/upcycled-bag.webp"
                alt={t("Пример сумки из текстильных остатков")}
                width="400"
                height="450"
              />
              <div>
                <strong>{t("Новый цикл")}</strong>
                <p>
                  {t("Из лоскутов —")}
                  <br />
                  {t("в любимые вещи.")}
                </p>
              </div>
            </div>
            <img
              className="home-hero-denim"
              src="/images/denim-offcuts.webp"
              alt={t("Деним с необработанными краями")}
              width="400"
              height="700"
            />
          </div>
        </div>
      </section>

      <section className="home-section home-about" id="about">
        <div className="container">
          <HomeHeading title={t("Знакомьтесь, ARTA")}>
            {t("Соединяем швейные цеха и мастерские,")}
            <br className="desktop-break" />
            {t(" чтобы хороший материал находил новое дело.")}
          </HomeHeading>
          <div className="home-story">
            <Link
              to="/catalog"
              className="home-story-image"
              aria-label={t("Посмотреть материалы в каталоге")}
            >
              <img
                src="/images/textile-hero.webp"
                alt={t(
                  "Текстильные остатки, из которых можно создать новые вещи",
                )}
                loading="lazy"
                width="900"
                height="600"
              />
            </Link>
            <p className="home-story-quote">
              {t("Сегодня — остатки.")}
              <br />
              {t("Завтра — сумки,")}
              <br />
              {t("игрушки и новые")}
              <br />
              {t("возможности")}
              <br />
              {t("для бизнеса.")}
            </p>
          </div>
        </div>
      </section>

      <section className="home-section home-process" id="how-it-works">
        <div className="container">
          <HomeHeading title={t("Как это работает")}>
            {t("Три шага от остатков производства")}
            <br className="desktop-break" />
            {t(" до материала для следующей идеи.")}
          </HomeHeading>
          <ProcessCarousel />
        </div>
      </section>

      <section className="home-section container" id="benefits">
        <HomeHeading title={t("Больше возможностей")}>
          {t("Остатки одного производства —")}
          <br className="desktop-break" />
          {t(" ценный ресурс для другого.")}
        </HomeHeading>
        <div className="home-benefits">
          <div className="home-benefit-column">
            <article className="home-benefit home-capsule home-capsule-orange">
              <h3>
                {t("Доступное")}
                <br />
                {t("сырьё")}
              </h3>
              <p>
                {t(
                  "Выбирайте материалы под свою задачу: от небольших лоскутов до крупных партий для производства.",
                )}
              </p>
            </article>
            <article className="home-benefit">
              <h3>
                {t("Новый доход")}
                <br />
                {t("для цехов")}
              </h3>
              <p>
                {t(
                  "Предложите остатки тем, кому они нужны, и освободите место для следующего заказа.",
                )}
              </p>
            </article>
          </div>
          <div className="home-benefit-column">
            <img
              className="home-capsule home-benefit-photo"
              src="/images/upcycled-bag.webp"
              alt={t("Сумка из остатков хлопка")}
              loading="lazy"
              width="400"
              height="560"
            />
            <article className="home-benefit">
              <h3>
                {t("Идеи для")}
                <br />
                {t("продолжения")}
              </h3>
              <p>
                {t(
                  "Узнайте, что можно сделать из выбранной ткани и каким мастерским она может подойти.",
                )}
              </p>
              <Link to="/create" className="text-link">
                {t("Посмотреть ")}
                <ArrowRight size={17} />
              </Link>
            </article>
          </div>
          <div className="home-benefit-column">
            <article className="home-benefit">
              <h3>
                {t("Удобный")}
                <br />
                {t("поиск")}
              </h3>
              <p>
                {t(
                  "Материал, город, масса и цена — вся информация для первого шага собрана в одном месте.",
                )}
              </p>
            </article>
            <article className="home-benefit home-capsule home-capsule-dark">
              <h3>
                {t("Связи между")}
                <br />
                {t("мастерскими")}
              </h3>
              <p>
                {t(
                  "Швейные цеха, ремесленники и переработчики могут находить друг друга через подходящий материал.",
                )}
              </p>
            </article>
          </div>
          <div className="home-benefit-column">
            <article className="home-benefit home-capsule home-capsule-paper">
              <h3>
                {t("Бережнее")}
                <br />
                {t("к ресурсам")}
              </h3>
              <p>
                {t(
                  "Каждая повторно использованная партия — это материал, который продолжает приносить пользу.",
                )}
              </p>
            </article>
            <img
              className="home-benefit-round"
              src="/images/cotton-offcuts.webp"
              alt={t("Лоскуты хлопка для нового производства")}
              loading="lazy"
              width="400"
              height="400"
            />
          </div>
        </div>
      </section>

      <HomeMaterials materials={materials} requests={state.requests} />
      <HomeAudience reused={summary.reused} />
      <HomeBusiness />
      <HomeInsights />
      <HomeFAQ />
      <HomeSupport />
    </div>
  );
}
