import { test, expect } from "@playwright/test";
import path from "node:path";

test("landing guides, FAQ and help open useful content and working routes", async ({
  page,
}) => {
  await page.goto("/");
  const guide = page.getByRole("button", {
    name: "Читать: Как подготовить остатки ткани к размещению",
  });
  await guide.click();
  await expect(page.getByRole("dialog")).toContainText("Начните с сортировки");
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(guide).toBeFocused();
  const question = page
    .locator(".home-faq")
    .filter({ hasText: "Можно ли отменить заявку?" });
  await expect(question.locator("p")).not.toBeVisible();
  await question.locator("summary").click();
  await expect(question.locator("p")).toBeVisible();
  await question.locator("summary").click();
  await expect(question.locator("p")).not.toBeVisible();
  await page.getByRole("button", { name: "Помочь с первым шагом" }).click();
  await page
    .getByRole("dialog")
    .getByRole("link", { name: /У меня есть остатки ткани/ })
    .click();
  await expect(page).toHaveURL(/\/create$/);
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(page.locator("#name")).toBeVisible();
});

test("process carousel updates its description, image and counter in both directions", async ({
  page,
}) => {
  await page.goto("/#how-it-works");
  const carousel = page.getByRole("region", { name: "Как работает ARTA" });
  await expect(carousel.getByRole("heading")).toHaveText(
    "Расскажите о материале",
  );
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await expect(carousel.getByRole("heading")).toHaveText("Найдите возможности");
  await expect(carousel.getByRole("img")).toHaveAttribute(
    "alt",
    "Деним для новых изделий и проектов",
  );
  await expect(carousel.locator(".home-process-counter")).toHaveText("02/03");
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await expect(carousel.getByRole("heading")).toHaveText(
    "Дайте ткани продолжение",
  );
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await expect(carousel.getByRole("heading")).toHaveText(
    "Расскажите о материале",
  );
  await carousel.getByRole("button", { name: "Предыдущий шаг" }).click();
  await expect(carousel.locator(".home-process-counter")).toHaveText("03/03");
  await page.setViewportSize({ width: 390, height: 844 });
  await carousel.getByRole("button", { name: "Предыдущий шаг" }).click();
  await expect(carousel.getByRole("heading")).toHaveText("Найдите возможности");
});

test("corrupted local demo offers reset without crashing", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() =>
    localStorage.setItem(
      "arta-web-demo-v1",
      JSON.stringify({ version: 1, materials: [{}], requests: [] }),
    ),
  );
  await page.goto("/requests");
  await expect(page.getByRole("alert")).toContainText(
    "Не удалось прочитать сохранённые данные",
  );
  await page
    .getByRole("button", { name: "Очистить данные", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Очистить данные", exact: true })
    .click();
  await expect(page.getByRole("alert")).toHaveCount(0);
  await page.goto("/catalog");
  await expect(page.locator(".material-card")).toHaveCount(6);
});

test("catalog filters, empty state and detail navigation work", async ({
  page,
}) => {
  await page.goto("/catalog");
  await expect(page.locator(".material-card")).toHaveCount(6);
  await page.getByRole("button", { name: "Деним", exact: true }).click();
  await expect(page.locator(".material-card")).toHaveCount(2);
  await page.getByLabel("Город", { exact: true }).selectOption("Бишкек");
  await expect(page.locator(".material-card")).toHaveCount(1);
  await page.getByRole("searchbox").fill("ничего-подходящего");
  await expect(
    page.getByRole("heading", { name: "Пока нет подходящих материалов" }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Сбросить фильтры", exact: true })
    .click();
  await expect(page.locator(".material-card")).toHaveCount(6);
  await page
    .getByRole("link", {
      name: "Открыть: Хлопок натуральных оттенков",
      exact: true,
    })
    .click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Хлопок натуральных оттенков",
  );
  await expect(
    page.getByRole("button", { name: "Оставить заявку" }),
  ).toBeVisible();
});

test("full request lifecycle persists and counts reuse only on final confirmation", async ({
  page,
}) => {
  await page.goto("/catalog/demo-cotton");
  await page.getByRole("button", { name: "Оставить заявку" }).click();
  await page.getByLabel(/Масса, кг/).fill("101");
  await page.getByLabel(/Название мастерской/).fill("Демо-мастерская QA");
  await page.getByRole("button", { name: "Создать заявку" }).click();
  await expect(page.getByRole("alert")).toContainText(
    "больше свободного остатка",
  );
  await page.getByLabel(/Масса, кг/).fill("12,5");
  await page.getByRole("button", { name: "Создать заявку" }).click();
  await page.getByRole("link", { name: "Перейти к заявке" }).click();
  await expect(page.locator(".request-card")).toHaveCount(1);
  for (const action of [
    "Подтвердить резерв",
    "Подтвердить передачу",
    "Подтвердить получение",
  ]) {
    await page.getByRole("button", { name: action, exact: true }).click();
    await page
      .getByRole("dialog")
      .getByRole("button", { name: action, exact: true })
      .click();
    await expect(page.locator(".stat-reuse > strong")).toHaveText("0 кг");
  }
  await page
    .getByRole("button", { name: "Подтвердить использование", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Подтвердить использование", exact: true })
    .click();
  await expect(page.locator(".stat-reuse > strong")).toHaveText("12,5 кг");
  await page.reload();
  await expect(page.locator(".stat-reuse > strong")).toHaveText("12,5 кг");
  await expect(
    page.getByRole("button", {
      name: "Подтвердить использование",
      exact: true,
    }),
  ).toHaveCount(0);
  await page.goto("/catalog/demo-cotton");
  await expect(page.locator(".spec-list")).toContainText("87,5 кг");
});

test("create form validates, previews uploaded image and persists the new batch", async ({
  page,
}) => {
  await page.goto("/create");
  await page.getByRole("button", { name: "Добавить в каталог" }).click();
  await expect(
    page.getByRole("alert").filter({ hasText: "Проверьте поля формы" }),
  ).toBeVisible();
  await expect(page.locator("#name")).toBeFocused();
  await page.locator("#name").fill("Хлопок для тестовой сумки");
  await page.locator("#material_type").selectOption("cotton");
  await page.locator("#condition").selectOption("unused");
  await page.locator("#total_kg").fill("7,250");
  await page.locator("#price_per_kg").fill("90");
  await page.locator("#city").fill("Бишкек");
  await page.locator("#organization_name").fill("Демо-цех QA");
  await page
    .getByLabel("Выбрать фото партии")
    .setInputFiles(path.resolve("public/images/cotton-offcuts.webp"));
  await expect(
    page.getByAltText("Предпросмотр фото новой партии"),
  ).toBeVisible();
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "Добавить в каталог" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Хлопок для тестовой сумки",
  );
  await page.reload();
  await expect(page.locator(".spec-list")).toContainText("7,25 кг");
  const image = page.locator(".detail-photo img");
  await expect(image).toBeVisible();
  expect(
    await image.evaluate((img) => img.complete && img.naturalWidth > 0),
  ).toBe(true);
});

test("mobile navigation, dialog keyboard close and reset confirmation work", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.getByRole("button", { name: "Открыть меню" }).click();
  await page
    .getByRole("navigation", { name: "Мобильная навигация" })
    .getByRole("link", { name: "Каталог тканей" })
    .click();
  await expect(
    page.getByRole("button", { name: "Открыть меню" }),
  ).toBeVisible();
  await page.goto("/catalog/demo-cotton");
  await page.getByRole("button", { name: "Оставить заявку" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Оставить заявку" }),
  ).toBeFocused();
  await page.goto("/requests");
  await page
    .getByRole("button", { name: "Очистить данные", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Вернуться" })
    .click();
  await page
    .getByRole("button", { name: "Очистить данные", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Очистить данные", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("Данные очищены");
});

for (const width of [320, 390, 768, 1440]) {
  test(`main routes fit ${width}px without JS errors`, async ({ page }) => {
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.setViewportSize({ width, height: 900 });
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
      const documentWidth = await page.evaluate(
        () => document.documentElement.scrollWidth,
      );
      expect(
        documentWidth,
        `${route} overflows at ${width}px`,
      ).toBeLessThanOrEqual(width);
    }
    expect(errors).toEqual([]);
  });
}
