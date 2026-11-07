import { chromium } from "@playwright/test";
import { mkdir } from "node:fs/promises";

await mkdir(".preview", { recursive: true });
const browser = await chromium.launch({ channel: "msedge", headless: true });
try {
  for (const [name, width, height] of [
    ["desktop", 1440, 1000],
    ["mobile", 390, 844],
  ]) {
    const page = await browser.newPage({
      viewport: { width, height },
      deviceScaleFactor: 1,
      reducedMotion: "reduce",
    });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.goto(
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:5173",
      { waitUntil: "networkidle" },
    );
    await page.evaluate(async () => {
      document.querySelectorAll("img").forEach((img) => {
        img.loading = "eager";
      });
      await document.fonts.ready;
      await Promise.all(
        Array.from(document.images, (img) => img.decode().catch(() => {})),
      );
    });
    await page.screenshot({
      path: `.preview/home-${name}.png`,
      fullPage: true,
    });
    await page.screenshot({ path: `.preview/home-${name}-viewport.png` });
    console.log(
      JSON.stringify({
        name,
        errors,
        width,
        documentWidth: await page.evaluate(
          () => document.documentElement.scrollWidth,
        ),
      }),
    );
    await page.close();
  }
} finally {
  await browser.close();
}
