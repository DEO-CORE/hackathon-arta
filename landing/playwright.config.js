import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  testMatch:
    process.env.PLAYWRIGHT_MODE === "demo"
      ? /^(?!.*live-api).*\.spec\.js$/
      : "**/live-api.spec.js",
  timeout: 60000,
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:5174",
    ...(process.env.PLAYWRIGHT_CHROMIUM_PATH
      ? {
          launchOptions: {
            executablePath: process.env.PLAYWRIGHT_CHROMIUM_PATH,
          },
        }
      : { browserName: "chromium" }),
    headless: true,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
});
