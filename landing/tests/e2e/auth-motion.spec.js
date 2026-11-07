import { test, expect } from "@playwright/test";

for (const [role, destination] of [
  ["Предлагаю ткань", "/create"],
  ["Ищу материал", "/catalog"],
]) {
  test(`registration validates both steps for ${role}`, async ({ page }) => {
    const submissions = [];
    page.on("request", (request) => {
      if (request.method() === "POST") submissions.push(request.url());
    });
    await page.goto("/register");
    await page.getByRole("radio", { name: new RegExp(role) }).check();
    const buyer = role === "Ищу материал";
    const profileName = page.getByLabel(
      buyer ? "Ваше имя" : "Название организации",
    );
    const name = buyer ? "Айдана" : "Мастерская QA";
    await expect(page.getByLabel("Название организации")).toHaveCount(
      buyer ? 0 : 1,
    );
    await expect(page.getByLabel("Направление работы")).toHaveCount(
      buyer ? 0 : 1,
    );
    await page.getByRole("button", { name: "Продолжить", exact: true }).click();
    await expect(profileName).toBeFocused();
    await expect(page.getByRole("alert")).toHaveCount(2);
    await profileName.fill(name);
    await page.getByLabel("Город", { exact: true }).fill("Бишкек");
    await page.getByRole("button", { name: "Продолжить", exact: true }).click();
    await expect(
      page.getByRole("heading", { name: "Настройте доступ к аккаунту" }),
    ).toBeFocused();
    await page.getByLabel("Email", { exact: true }).fill("ошибка");
    await page.getByLabel("Пароль", { exact: true }).fill("short");
    await page.getByLabel("Повторите пароль").fill("different");
    await page.getByRole("button", { name: "Зарегистрироваться" }).click();
    await expect(page.getByRole("alert")).toHaveCount(3);
    await expect(page.getByLabel("Email", { exact: true })).toBeFocused();
    await page.getByRole("button", { name: "Назад", exact: true }).click();
    await expect(profileName).toHaveValue(name);
    await expect(
      page.getByRole("radio", { name: new RegExp(role) }),
    ).toBeChecked();
    await page.getByRole("button", { name: "Продолжить", exact: true }).click();
    await page.getByLabel("Email", { exact: true }).fill("qa@example.com");
    await page.getByLabel("Пароль", { exact: true }).fill("Demo-password-2026");
    await page
      .getByRole("button", { name: "Показать пароль", exact: true })
      .click();
    await expect(page.getByLabel("Пароль", { exact: true })).toHaveAttribute(
      "type",
      "text",
    );
    await page
      .getByRole("button", { name: "Скрыть пароль", exact: true })
      .click();
    await page.getByLabel("Повторите пароль").fill("Demo-password-2026");
    await page.getByRole("button", { name: "Зарегистрироваться" }).click();
    await expect(
      page.getByRole("heading", { name: "Регистрация скоро откроется" }),
    ).toBeFocused();
    await expect(page.locator(".auth-complete")).toContainText(
      "Создание аккаунта пока недоступно",
    );
    const storage = await page.evaluate(() =>
      JSON.stringify({ ...localStorage, ...sessionStorage }),
    );
    expect(storage).not.toContain("Demo-password-2026");
    expect(storage).not.toContain("qa@example.com");
    expect(submissions).toEqual([]);
    await page.locator(".auth-complete .button").click();
    await expect(page).toHaveURL(new RegExp(`${destination}$`));
  });
}

test("switching registration roles clears stale errors and preserves each profile", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/register");
  await page.getByLabel("Название организации").fill("Цех Жип");
  await page.getByLabel("Направление работы").selectOption("recycler");
  await page.getByRole("button", { name: "Продолжить", exact: true }).click();
  await expect(page.getByRole("alert")).toHaveCount(1);
  await page.getByRole("radio", { name: /Ищу материал/ }).check();
  await expect(page.getByRole("alert")).toHaveCount(0);
  await expect(page.getByLabel("Название организации")).toHaveCount(0);
  await expect(page.getByLabel("Направление работы")).toHaveCount(0);
  await expect(page.locator(".auth-steps")).toContainText("О вас");
  await page.getByLabel("Ваше имя").fill("Айдана");
  await page.getByLabel("Город", { exact: true }).fill("Ош");
  await page.getByRole("button", { name: "Продолжить", exact: true }).click();
  await expect(page.locator(".auth-org-summary")).toContainText("Айдана");
  await expect(page.locator(".auth-org-summary")).toContainText("Ош");
  await expect(page.locator(".auth-org-summary")).not.toContainText("Цех Жип");
  await expect(page.locator(".auth-org-summary")).not.toContainText(
    "Переработка",
  );
  await page.getByRole("button", { name: "Назад", exact: true }).click();
  await page.getByRole("radio", { name: /Предлагаю ткань/ }).check();
  await expect(page.getByLabel("Название организации")).toHaveValue("Цех Жип");
  await expect(page.getByLabel("Направление работы")).toHaveValue("recycler");
  await expect(page.getByLabel("Контактное лицо")).toHaveValue("Айдана");
  await page.getByRole("button", { name: "Продолжить", exact: true }).click();
  await expect(page.locator(".auth-org-summary")).toContainText("Цех Жип");
  await expect(page.locator(".auth-org-summary")).toContainText(
    "Переработка текстиля",
  );
});

test("mobile login, recovery and reset show honest preview states without sending credentials", async ({
  page,
}) => {
  const submissions = [];
  page.on("request", (request) => {
    if (request.method() === "POST") submissions.push(request.url());
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.getByRole("button", { name: "Открыть меню" }).click();
  await page
    .getByRole("navigation", { name: "Мобильная навигация" })
    .getByRole("link", { name: "Войти", exact: true })
    .click();
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page.getByRole("alert")).toHaveCount(2);
  await page.getByLabel("Email", { exact: true }).fill("qa@example.com");
  await page.getByLabel("Пароль", { exact: true }).fill("Demo-password-2026");
  await page.getByRole("button", { name: "Войти" }).click();
  await expect(page.locator(".auth-complete")).toContainText(
    "Войти в аккаунт пока нельзя",
  );
  await page.goto("/login");
  await page.getByRole("link", { name: "Забыли пароль?" }).click();
  await page.getByRole("button", { name: "Восстановить доступ" }).click();
  await expect(page.getByRole("alert")).toHaveText("Укажите email.");
  await page.getByLabel("Email", { exact: true }).fill("qa@example.com");
  await page.getByRole("button", { name: "Восстановить доступ" }).click();
  await expect(page.locator(".auth-complete")).toContainText(
    "Не удалось отправить ссылку",
  );
  await page.getByRole("link", { name: "Посмотреть смену пароля" }).click();
  await page.getByLabel("Новый пароль", { exact: true }).fill("new");
  await page.getByLabel("Повторите пароль").fill("new");
  await page.getByRole("button", { name: "Сохранить пароль" }).click();
  await expect(page.getByRole("alert")).toContainText("не меньше 10 символов");
  await page
    .getByLabel("Новый пароль", { exact: true })
    .fill("Another-demo-password");
  await page.getByLabel("Повторите пароль").fill("Another-demo-password");
  await page.getByRole("button", { name: "Сохранить пароль" }).click();
  await expect(page.locator(".auth-complete")).toContainText(
    "Смена пароля пока недоступна",
  );
  await page
    .getByRole("link", { name: "Вернуться ко входу", exact: true })
    .click();
  await expect(page.getByLabel("Пароль", { exact: true })).toHaveValue("");
  const storage = await page.evaluate(() =>
    JSON.stringify({ ...localStorage, ...sessionStorage }),
  );
  expect(storage).not.toContain("password");
  expect(submissions).toEqual([]);
});

test("card shuffle survives rapid direction changes, keyboard and mobile swipes", async ({
  page,
}) => {
  await page.goto("/#how-it-works");
  const carousel = page.getByRole("region", { name: "Как работает ARTA" });
  await carousel.scrollIntoViewIfNeeded();
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  const activeAnimations = await carousel
    .locator("img")
    .evaluateAll(
      (images) =>
        images
          .flatMap((image) => image.getAnimations())
          .filter((animation) => animation.playState === "running").length,
    );
  expect(activeAnimations).toBe(3);
  await carousel.getByRole("button", { name: "Предыдущий шаг" }).click();
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await carousel.focus();
  await page.keyboard.press("ArrowRight");
  await expect(carousel.locator(".home-process-counter")).toHaveText("03/03");
  await carousel
    .locator("img")
    .evaluateAll((images) =>
      Promise.all(
        images
          .flatMap((image) => image.getAnimations())
          .map((animation) => animation.finished),
      ),
    );
  await expect(carousel.locator(".depth-0")).toHaveCSS("opacity", "1");
  await expect(carousel.locator(".depth-1")).toHaveCSS("opacity", "0.5");
  await expect(carousel.locator(".depth-2")).toHaveCSS("opacity", "0.25");
  await page.setViewportSize({ width: 390, height: 844 });
  const stack = carousel.locator(".motion-card-stack");
  await stack.dispatchEvent("pointerdown", {
    pointerType: "touch",
    clientX: 280,
    clientY: 300,
  });
  await stack.dispatchEvent("pointerup", {
    pointerType: "touch",
    clientX: 150,
    clientY: 305,
  });
  await expect(carousel.locator(".home-process-counter")).toHaveText("01/03");
  await stack.dispatchEvent("pointerdown", {
    pointerType: "touch",
    clientX: 150,
    clientY: 300,
  });
  await stack.dispatchEvent("pointerup", {
    pointerType: "touch",
    clientX: 150,
    clientY: 450,
  });
  await expect(carousel.locator(".home-process-counter")).toHaveText("01/03");
  await stack.dispatchEvent("pointerdown", {
    pointerType: "touch",
    clientX: 150,
    clientY: 300,
  });
  await stack.dispatchEvent("pointerup", {
    pointerType: "touch",
    clientX: 280,
    clientY: 305,
  });
  await expect(carousel.locator(".home-process-counter")).toHaveText("03/03");
});

test("shuffle reverses from the painted pose and clears motion on resize or preference change", async ({
  page,
}) => {
  await page.goto("/#how-it-works");
  const carousel = page.getByRole("region", { name: "Как работает ARTA" });
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  const poses = await carousel.evaluate(async (root) => {
    const images = [...root.querySelectorAll("img")];
    const pauseAt = (time) =>
      images.forEach((image) =>
        image.getAnimations().forEach((animation) => {
          animation.pause();
          animation.currentTime = time;
        }),
      );
    const read = () =>
      images.map((image) => {
        const style = getComputedStyle(image);
        return {
          transform: style.transform,
          height: style.height,
          opacity: style.opacity,
        };
      });
    pauseAt(320);
    const before = read();
    root.querySelector(".home-process-controls button").click();
    await new Promise(requestAnimationFrame);
    pauseAt(0);
    return { before, after: read() };
  });
  expect(poses.after).toEqual(poses.before);
  await expect(carousel.locator(".home-process-counter")).toHaveText("01/03");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(carousel.locator(".process-copy-ghost > *")).toHaveCount(0);
  expect(
    await carousel.evaluate(
      (root) => root.getAnimations({ subtree: true }).length,
    ),
  ).toBe(0);
  await expect(carousel.locator(".process-copy-current h3")).toHaveCSS(
    "opacity",
    "1",
  );
  await expect(carousel.locator(".depth-0")).toHaveCSS("opacity", "1");

  await page.emulateMedia({ reducedMotion: "no-preference" });
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await page.setViewportSize({ width: 320, height: 780 });
  await expect(carousel.locator(".process-copy-ghost > *")).toHaveCount(0);
  await expect(carousel.locator(".process-copy-current h3")).toHaveCSS(
    "opacity",
    "1",
  );
  await expect(carousel.locator(".home-process-counter")).toHaveText("02/03");
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(
    320,
  );
});

test("reduced motion keeps all content visible and disables card animation", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/#how-it-works");
  const carousel = page.getByRole("region", { name: "Как работает ARTA" });
  await carousel.getByRole("button", { name: "Следующий шаг" }).click();
  await expect(carousel.getByRole("heading")).toHaveText("Найдите возможности");
  expect(
    await carousel
      .locator("img")
      .evaluateAll(
        (images) => images.flatMap((image) => image.getAnimations()).length,
      ),
  ).toBe(0);
  await expect(page.locator('[data-reveal="pending"]')).toHaveCount(0);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.goto("/");
  await expect(page.locator('[data-reveal="pending"]').first()).toBeAttached();
  const guide = page.locator(".home-guide").first();
  await guide.scrollIntoViewIfNeeded();
  await expect(guide).toHaveAttribute("data-reveal", "visible");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(page.locator('[data-reveal="pending"]')).toHaveCount(0);
});
