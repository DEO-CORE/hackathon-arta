import { test, expect } from "@playwright/test";
import { randomUUID } from "node:crypto";
import sharp from "sharp";

// Run only against a disposable database: this test creates accounts and a sale.
test("real API: personal buyer, publication, reservation, partial transfer and reuse", async ({
  browser,
  baseURL,
  request,
}) => {
  const id = randomUUID();
  const password = "Browser-test-password-123";
  const sellerEmail = `seller-${id}@example.test`;
  const buyerEmail = `buyer-${id}@example.test`;
  const registered = await request.post("/api/auth/register", {
    data: {
      email: sellerEmail,
      password,
      role: "enterprise",
      organization: {
        name: "Browser factory",
        city: "Бишкек",
        activity_type: "garment_factory",
      },
    },
  });
  expect(registered.status()).toBe(201);
  const sellerContext = await browser.newContext({ baseURL });
  const buyerContext = await browser.newContext({ baseURL });
  const seller = await sellerContext.newPage();
  const buyer = await buyerContext.newPage();
  const errors = [];
  for (const page of [seller, buyer])
    page.on("pageerror", (error) => errors.push(error.message));
  async function login(page, email) {
    await page.goto("/login");
    await page.getByLabel("Email", { exact: true }).fill(email);
    await page.locator("#auth-password").fill(password);
    await page.getByRole("button", { name: "Войти", exact: true }).click();
    await page.waitForURL("**/requests");
  }
  async function transition(page, title, quantity, basis) {
    await page.goto("/requests");
    await page.getByRole("button", { name: title, exact: true }).click();
    const dialog = page.getByRole("dialog");
    if (quantity)
      await dialog.getByLabel("Фактическая масса, кг").fill(quantity);
    if (basis) await dialog.getByLabel("Основание использования").fill(basis);
    await dialog.getByRole("button", { name: title, exact: true }).click();
    await expect(dialog).not.toBeVisible();
  }
  try {
    await login(seller, sellerEmail);
    await buyer.goto("/register");
    await buyer.getByText("Ищу материал", { exact: true }).click();
    await buyer.getByLabel("Ваше имя").fill("Айжан");
    await buyer.getByLabel("Город", { exact: true }).fill("Бишкек");
    await buyer.getByRole("button", { name: "Продолжить" }).click();
    await buyer.getByLabel("Email", { exact: true }).fill(buyerEmail);
    await buyer.locator("#auth-password").fill(password);
    await buyer.getByLabel("Повторите пароль").fill(password);
    await buyer
      .getByRole("button", { name: "Зарегистрироваться", exact: true })
      .click();
    await expect(
      buyer.getByText("Аккаунт создан", { exact: true }),
    ).toBeVisible();
    await login(buyer, buyerEmail);
    expect(
      (await (await buyerContext.request.get("/api/auth/me")).json())
        .organization,
    ).toBeNull();
    const before = await (await request.get("/api/public/statistics")).json();
    await seller.goto("/create");
    await seller.getByLabel("Название партии").fill(`Browser cotton ${id}`);
    await seller.locator("#material_type").selectOption("cotton");
    await seller.locator("#condition").selectOption("good");
    await seller.locator("#total_kg").fill("20");
    await seller.locator("#price_per_kg").fill("10");
    await seller.locator("#city").fill("Бишкек");
    const photo = await sharp({
      create: { width: 400, height: 400, channels: 3, background: "#aabbcc" },
    })
      .png()
      .toBuffer();
    await seller
      .locator("input[type=file]")
      .setInputFiles({
        name: "fabric.png",
        mimeType: "image/png",
        buffer: photo,
      });
    await expect(
      seller.getByAltText("Предпросмотр фото новой партии"),
    ).toBeVisible();
    await seller.locator("input[type=checkbox]").check();
    await seller.getByRole("button", { name: "Добавить в каталог" }).click();
    await seller.waitForURL("**/catalog/*");
    const materialId = seller.url().split("/").at(-1);
    await buyer.goto(`/catalog/${materialId}`);
    await buyer.getByRole("button", { name: "Оставить заявку" }).click();
    await buyer.getByRole("dialog").getByLabel("Масса, кг").fill("10");
    await buyer.getByRole("button", { name: "Создать заявку" }).click();
    await expect(
      buyer.getByText("Заявка сохранена", { exact: true }),
    ).toBeVisible();
    await transition(seller, "Подтвердить резерв");
    await transition(seller, "Подтвердить передачу", "8");
    await transition(buyer, "Подтвердить получение");
    await transition(buyer, "Подтвердить использование", "3", "Сшиты сумки");
    const reservation = (
      await (await buyerContext.request.get("/api/reservations")).json()
    ).items[0];
    expect(reservation.transaction.confirmed_reuse_kg).toBe("3.000");
    expect(reservation.transaction.sale_amount_kgs).toBe("80.00");
    const material = await (
      await request.get(`/api/public/materials/${materialId}`)
    ).json();
    expect(material.available_kg).toBe("12.000");
    const after = await (await request.get("/api/public/statistics")).json();
    expect(
      Number(after.confirmed_reuse_kg) - Number(before.confirmed_reuse_kg),
    ).toBe(3);
    await buyer.reload();
    await expect(
      buyer.getByText("Получено покупателем", { exact: true }),
    ).toBeVisible();
    expect(
      await buyer.evaluate(() =>
        JSON.stringify({ ...localStorage, ...sessionStorage }),
      ),
    ).not.toContain(password);
    expect(errors).toEqual([]);
  } finally {
    await sellerContext.close();
    await buyerContext.close();
  }
});
