import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { parsers } from "prettier/plugins/babel";
import common from "../src/i18n/common.js";
import home from "../src/i18n/home.js";
import forms from "../src/i18n/forms.js";
import content from "../src/i18n/content.js";
import { messages } from "../src/i18n/messages.js";
import { translate } from "../src/i18n/locale.js";

test("all UI source strings have both translations with matching parameters", () => {
  const rows = [...common, ...home, ...forms, ...content];
  assert.equal(
    new Set(rows.map((row) => row[0])).size,
    rows.length,
    "Duplicate source keys",
  );
  const parameters = (value) =>
    [...value.matchAll(/\{\{(\w+)\}\}/g)].map((match) => match[1]).sort();
  for (const [source, en, ky] of rows) {
    for (const translation of [en, ky]) {
      assert.ok(translation.trim(), source);
      assert.deepEqual(parameters(translation), parameters(source), source);
    }
  }
  const missing = new Set();
  const files = fs
    .readdirSync("src", { recursive: true })
    .filter((file) => /\.(js|jsx)$/.test(file) && !file.startsWith("i18n"));
  for (const file of files) {
    const ast = parsers.babel.parse(fs.readFileSync(`src/${file}`, "utf8"), {});
    function walk(node) {
      if (!node || typeof node !== "object") return;
      if (
        ["StringLiteral", "JSXText"].includes(node.type) &&
        /[А-Яа-яЁё]/.test(node.value)
      ) {
        const source = node.value.replace(/\s+/g, " ").trim();
        if (!messages[source]) missing.add(`${file}: ${source}`);
      }
      for (const [key, value] of Object.entries(node)) {
        if (["loc", "comments", "tokens"].includes(key)) continue;
        if (Array.isArray(value)) value.forEach(walk);
        else if (value && typeof value === "object") walk(value);
      }
    }
    walk(ast);
  }
  assert.deepEqual([...missing], []);
});

test("translation parameters preserve user content and unknown values", () => {
  for (const language of ["ru", "en", "ky"]) {
    assert.equal(
      translate("Моя новая мастерская", {}, language),
      "Моя новая мастерская",
    );
    assert.ok(
      translate(
        "Открыть: {{0}}",
        { 0: "Хлопок натуральных оттенков" },
        language,
      ).endsWith("Хлопок натуральных оттенков"),
    );
  }
  assert.equal(translate("Войти", {}, "en"), "Log in");
  assert.equal(translate("Войти", {}, "ky"), "Кирүү");
});
