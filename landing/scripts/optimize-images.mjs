import sharp from "sharp";
import { readdir } from "node:fs/promises";
import path from "node:path";

// Converts project image exports to delivery assets without changing the composition.
const input = path.resolve(process.argv[2] || ".preview/original-images");
for (const file of await readdir(input)) {
  if (!file.endsWith(".png")) continue;
  const output = path.join("public/images", file.replace(/\.png$/, ".webp"));
  await sharp(path.join(input, file))
    .resize({ width: 1440, withoutEnlargement: true })
    .webp({ quality: 86, effort: 6 })
    .toFile(output);
  console.log(output);
}
