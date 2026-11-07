import { useI18n, LanguageSwitch } from "../i18n";
import { useEffect, useState } from "react";
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { Plus, Menu, X } from "lucide-react";
import { Brand } from "./UI";
import Footer from "./Footer";
import { useStore, bootstrap, logout } from "../lib/store";

export default function Layout() {
  const { t, language } = useI18n();

  useEffect(() => {
    document.documentElement.lang = language;
    document.title = t("ARTA — вторая жизнь текстиля");
    document
      .querySelector('meta[name="description"]')
      ?.setAttribute(
        "content",
        t(
          "ARTA — вторая жизнь текстиля. Находите и размещайте остатки тканей для нового производства в Кыргызстане.",
        ),
      );
  }, [language, t]);

  const [menu, setMenu] = useState(false);
  const location = useLocation();
  const state = useStore();
  const [sessionError, setSessionError] = useState("");
  useEffect(() => {
    bootstrap();
  }, []);
  const signOut = async () => {
    try {
      await logout();
    } catch (e) {
      setSessionError(e.message);
    }
  };
  useEffect(() => {
    setMenu(false);
    if (location.hash)
      requestAnimationFrame(() =>
        document.getElementById(location.hash.slice(1))?.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)")
            .matches
            ? "instant"
            : "smooth",
        }),
      );
    else window.scrollTo({ top: 0, behavior: "instant" });
  }, [location.pathname, location.hash]);
  useEffect(() => {
    const close = (event) => {
      if (event.key === "Escape") setMenu(false);
    };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, []);
  return (
    <>
      <a className="skip-link" href="#main">
        {t("К содержимому")}
      </a>
      <header className="header">
        <div className="container header-inner">
          <Brand />
          <nav aria-label={t("Основная навигация")} className="desktop-nav">
            <NavLink to="/" end>
              {t("О платформе")}
            </NavLink>
            <NavLink to="/catalog">{t("Каталог тканей")}</NavLink>
            <NavLink to="/requests">
              {t("Мои заявки")}
              {state.requests.length > 0 && (
                <span className="nav-count">{state.requests.length}</span>
              )}
            </NavLink>
          </nav>
          <div className="header-tools">
            <LanguageSwitch key={location.key} onOpen={() => setMenu(false)} />
            <div className="header-auth">
              {state.user ? (
                <>
                  <Link to="/requests">
                    {state.user.profile_name ||
                      state.organization?.name ||
                      state.user.email}
                  </Link>
                  <button onClick={signOut} className="button button-dark">
                    {t("Выйти")}
                  </button>
                </>
              ) : (
                <>
                  <NavLink to="/login" className="header-login">
                    {t("Войти")}
                  </NavLink>
                  <Link to="/register" className="button button-dark">
                    {t("Регистрация")}
                  </Link>
                </>
              )}
            </div>
            <button
              className="icon-button mobile-menu-toggle"
              onClick={() => setMenu(!menu)}
              aria-label={menu ? t("Закрыть меню") : t("Открыть меню")}
              aria-expanded={menu}
              aria-controls="mobile-nav"
            >
              {menu ? <X /> : <Menu />}
            </button>
          </div>
        </div>
        {menu && (
          <nav
            className="mobile-nav container"
            id="mobile-nav"
            aria-label={t("Мобильная навигация")}
          >
            <NavLink to="/" end>
              {t("О платформе")}
            </NavLink>
            <NavLink to="/catalog">{t("Каталог тканей")}</NavLink>
            <NavLink to="/requests">{t("Мои заявки")}</NavLink>
            {state.user ? (
              <button onClick={signOut}>{t("Выйти")}</button>
            ) : (
              <>
                <NavLink to="/login">{t("Войти")}</NavLink>
                <NavLink to="/register">{t("Регистрация")}</NavLink>
              </>
            )}
            <Link className="button button-dark" to="/create">
              <Plus size={17} />
              {t("Разместить партию")}
            </Link>
          </nav>
        )}
      </header>
      {state.storageWarning && (
        <div className="container notice my-4" role="alert">
          {t(state.storageWarning)}
        </div>
      )}
      {state.mode !== "api" && (
        <div className="notice" role="status">
          {t("Демонстрационный режим: изменения хранятся только в браузере.")}
        </div>
      )}
      {(state.error || sessionError) && (
        <div className="container notice" role="alert">
          {state.error || sessionError}
        </div>
      )}
      <main id="main" tabIndex={-1}>
        <Outlet />
      </main>
      <Footer />
    </>
  );
}
