import { test, expect } from "@playwright/test";

const switchLanguage = async (page, language) => {
  const labels = { ru: "Русский", ky: "Кыргызча", en: "English" };
  await page.locator(".language-trigger").click();
  await page
    .getByRole("menuitemradio", { name: labels[language], exact: true })
    .click();
};

test("language preference persists across routes, reloads and tabs", async ({
  page,
  context,
}) => {
  await page.goto("/");
  await switchLanguage(page, "en");
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page).toHaveTitle("ARTA — a second life for textiles");
  await page.getByRole("link", { name: "Sign up", exact: true }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Start a new cycle",
  );
  await page.reload();
  await expect(page.locator(".language-trigger")).toHaveAttribute(
    "data-language",
    "en",
  );
  const second = await context.newPage();
  await second.goto("/login");
  await switchLanguage(second, "ky");
  await expect(page.locator("html")).toHaveAttribute("lang", "ky");
  await expect(
    page.getByRole("button", { name: "Улантуу", exact: true }),
  ).toBeVisible();
  await second.close();
  await switchLanguage(page, "ru");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Начнём новый цикл",
  );
});

test("switching language preserves registration values, step and translated validation", async ({
  page,
}) => {
  await page.goto("/register");
  await page.getByLabel("Название организации").fill("Мастерская автора");
  await page.getByLabel("Город", { exact: true }).fill("Бишкек");
  await switchLanguage(page, "en");
  await expect(page.getByLabel("Organisation name")).toHaveValue(
    "Мастерская автора",
  );
  await page.getByRole("button", { name: "Continue", exact: true }).click();
  await page.getByLabel("Email", { exact: true }).fill("qa@example.com");
  await page.getByLabel("Password", { exact: true }).fill("tiny");
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(
    page.getByRole("alert").filter({ hasText: "Use at least 10 characters." }),
  ).toBeVisible();
  await switchLanguage(page, "ky");
  await expect(page.getByLabel("Сырсөз", { exact: true })).toHaveValue("tiny");
  await expect(
    page.getByRole("alert").filter({ hasText: "Кеминде 10 белги колдонуңуз." }),
  ).toBeVisible();
  await expect(page.locator(".auth-org-summary")).toContainText(
    "Мастерская автора",
  );
  await page
    .getByRole("button", { name: "Сырсөздү көрсөтүү", exact: true })
    .click();
  await expect(page.getByLabel("Сырсөз", { exact: true })).toHaveAttribute(
    "type",
    "text",
  );
  await page.getByLabel("Сырсөз", { exact: true }).fill("Demo-password-2026");
  await page.getByLabel("Сырсөздү кайталаңыз").fill("Demo-password-2026");
  await page.getByRole("button", { name: "Катталуу" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Катталуу жакында ачылат",
  );
});

test("multilingual search preserves its query and city filter when language changes", async ({
  page,
}) => {
  await page.goto("/catalog");
  await switchLanguage(page, "en");
  await page.getByRole("searchbox").fill("cotton");
  await expect(page.locator(".material-card")).toHaveCount(2);
  await page
    .getByLabel("City", { exact: true })
    .selectOption({ label: "Bishkek" });
  await expect(page.locator(".material-card")).toHaveCount(1);
  await switchLanguage(page, "ky");
  await expect(page.getByRole("searchbox")).toHaveValue("cotton");
  await expect(page.getByLabel("Шаар", { exact: true })).toHaveValue("Бишкек");
  await expect(page.locator(".material-card")).toHaveCount(1);
  await page.getByRole("searchbox").fill("пахта");
  await expect(page.locator(".material-card")).toHaveCount(1);
  await switchLanguage(page, "ru");
  await expect(page.locator(".material-card")).toHaveCount(1);
});

test("user batch content stays unchanged while its controls and units translate", async ({
  page,
}) => {
  await page.goto("/create");
  await page.locator("#name").fill("Хлопок натуральных оттенков");
  await page.locator("#material_type").selectOption("cotton");
  await page.locator("#condition").selectOption("unused");
  await page.locator("#total_kg").fill("7,25");
  await page.locator("#price_per_kg").fill("80");
  await page.locator("#city").fill("Бишкек");
  await page.locator("#organization_name").fill("Моя мастерская");
  await page.locator("#description").fill("Описание от автора");
  await page.getByRole("button", { name: "Выбрать фото хлопка" }).click();
  await page.getByRole("checkbox").check();
  await switchLanguage(page, "en");
  await expect(page.locator("#name")).toHaveValue(
    "Хлопок натуральных оттенков",
  );
  await page.getByRole("button", { name: "Add to catalogue" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Хлопок натуральных оттенков",
  );
  await expect(page.locator(".detail-description")).toHaveText(
    "Описание от автора",
  );
  await expect(page.locator(".detail-location")).toContainText(
    "Моя мастерская",
  );
  await expect(page.locator(".spec-list")).toContainText("7.25 kg");
  await page.getByRole("button", { name: "Request this batch" }).click();
  await page.getByLabel(/Weight, kg/).fill("8");
  await page.getByLabel(/Workshop name/).fill("QA Workshop");
  await page.getByRole("button", { name: "Create request" }).click();
  await expect(page.getByRole("alert")).toHaveText(
    "The requested weight exceeds available stock.",
  );
});

for (const language of ["en", "ky"]) {
  for (const width of [320, 768, 1440]) {
    test(`${language} interface fits ${width}px on all routes`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ reducedMotion: "reduce" });
      const errors = [];
      page.on("pageerror", (error) => errors.push(error.message));
      await page.goto("/");
      await switchLanguage(page, language);
      for (const route of [
        "/",
        "/catalog",
        "/catalog/demo-cotton",
        "/create",
        "/requests",
        "/register",
        "/login",
        "/forgot-password",
        "/reset-password",
      ]) {
        await page.goto(route);
        await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
        await expect(page.locator("html")).toHaveAttribute("lang", language);
        expect(
          await page.evaluate(() => document.documentElement.scrollWidth),
          route,
        ).toBeLessThanOrEqual(width);
        if (language === "en") {
          const russian = await page.locator("#main").evaluate((root) => {
            const walker = document.createTreeWalker(
              root,
              NodeFilter.SHOW_TEXT,
            );
            const result = [];
            let node;
            while ((node = walker.nextNode()))
              if (
                /[А-Яа-яЁё]/.test(node.textContent) &&
                node.parentElement.getClientRects().length
              )
                result.push(node.textContent.trim());
            return result;
          });
          expect(russian, route).toEqual([]);
        }
      }
      expect(errors).toEqual([]);
    });
  }
}
