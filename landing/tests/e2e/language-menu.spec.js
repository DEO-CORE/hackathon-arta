import { test, expect } from "@playwright/test";

test("language menu supports arrows, typeahead, escape, tab and outside clicks", async ({
  page,
}) => {
  await page.goto("/");
  const trigger = page.locator(".language-trigger");
  const menu = page.getByRole("menu");
  const option = (label) =>
    page.getByRole("menuitemradio", { name: label, exact: true });
  await trigger.focus();
  await page.keyboard.press("ArrowDown");
  await expect(option("Русский")).toBeFocused();
  await expect(option("Русский")).toHaveAttribute("aria-checked", "true");
  await page.keyboard.press("ArrowUp");
  await expect(option("English")).toBeFocused();
  await page.keyboard.press("Home");
  await expect(option("Русский")).toBeFocused();
  await page.keyboard.press("End");
  await expect(option("English")).toBeFocused();
  await page.keyboard.press("k");
  await expect(option("Кыргызча")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("html")).toHaveAttribute("lang", "ky");
  await expect(trigger).toBeFocused();
  await expect(menu).toHaveCount(0);

  await page.keyboard.press("ArrowUp");
  await expect(option("English")).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(trigger).toBeFocused();
  await expect(trigger).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator("html")).toHaveAttribute("lang", "ky");
  await trigger.click();
  await page.getByRole("heading", { level: 1 }).click();
  await expect(menu).toHaveCount(0);

  await trigger.click();
  await page.keyboard.press("Tab");
  await expect(page.locator(".header-login")).toBeFocused();
  await expect(menu).toHaveCount(0);
  await trigger.click();
  await page.keyboard.press("Shift+Tab");
  await expect(page.locator(".desktop-nav a").last()).toBeFocused();
  await expect(menu).toHaveCount(0);
});

test("mobile language menu closes navigation and respects reduced motion", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await page.locator(".mobile-menu-toggle").click();
  await expect(page.locator(".mobile-nav")).toBeVisible();
  await page.locator(".language-trigger").click();
  await expect(page.locator(".mobile-nav")).toHaveCount(0);
  const menu = page.getByRole("menu");
  await expect(menu).toBeVisible();
  const bounds = await menu.boundingBox();
  expect(bounds.x).toBeGreaterThanOrEqual(0);
  expect(bounds.x + bounds.width).toBeLessThanOrEqual(320);
  expect(
    await menu.evaluate((node) => node.getAnimations({ subtree: true }).length),
  ).toBe(0);
  await page
    .getByRole("menuitemradio", { name: "English", exact: true })
    .click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await page.evaluate(() => document.fonts.ready);
  expect(
    await page
      .locator(".header .brand-type")
      .evaluate((node) => getComputedStyle(node).fontFamily),
  ).toContain("Montserrat");
  expect(
    await page.evaluate(() => document.fonts.check("700 39px Montserrat")),
  ).toBe(true);
  const credit = page.getByRole("img", { name: "Made by DEO" });
  await credit.scrollIntoViewIfNeeded();
  await expect(credit).toBeVisible();
  await expect
    .poll(() =>
      credit.evaluate((node) => node.complete && node.naturalWidth > 0),
    )
    .toBe(true);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(
    320,
  );
});
