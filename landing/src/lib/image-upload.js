export async function preparePhoto(file) {
  if (!["image/jpeg", "image/png", "image/webp"].includes(file.type))
    throw new Error("Выберите изображение JPG, PNG или WebP.");
  if (file.size > 10 * 1024 * 1024)
    throw new Error("Размер фото не должен превышать 10 МБ.");
  let bitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    throw new Error("Не удалось прочитать изображение. Выберите другой файл.");
  }
  try {
    if (bitmap.width * bitmap.height > 20_000_000)
      throw new Error(
        "Слишком большое разрешение. Максимум — 20 мегапикселей.",
      );
    const ratio = Math.min(1, 1200 / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(bitmap.width * ratio);
    canvas.height = Math.round(bitmap.height * ratio);
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#f5f3ee";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", 0.78);
  } finally {
    bitmap.close();
  }
}
