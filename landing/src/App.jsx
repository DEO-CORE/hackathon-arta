import { useI18n } from "./i18n";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import { ButtonLink, EmptyState } from "./components/UI";
import Home from "./pages/Home";
import Catalog from "./pages/Catalog";
import MaterialDetail from "./pages/MaterialDetail";
import CreateMaterial from "./pages/CreateMaterial";
import Requests from "./pages/Requests";
import Auth from "./pages/Auth";

export default function App() {
  const { t } = useI18n();

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="catalog" element={<Catalog />} />
          <Route path="catalog/:id" element={<MaterialDetail />} />
          <Route path="create" element={<CreateMaterial />} />
          <Route path="requests" element={<Requests />} />
          <Route path="register" element={<Auth mode="register" />} />
          <Route path="login" element={<Auth mode="login" />} />
          <Route path="forgot-password" element={<Auth mode="forgot" />} />
          <Route path="reset-password" element={<Auth mode="reset" />} />
          <Route
            path="*"
            element={
              <div className="page-blocks">
                <div className="page-block empty-page-block">
                  <EmptyState
                    title={t("Эта страница пока не соткана")}
                    description={t(
                      "Вернитесь на главную или найдите материал в каталоге.",
                    )}
                  >
                    <ButtonLink to="/" variant="dark">
                      {t("На главную")}
                    </ButtonLink>
                  </EmptyState>
                </div>
              </div>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
