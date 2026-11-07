import { getLocale, translate } from "../i18n/locale.js";

export function toUnits(value, precision = 3) {
  const text = String(value).trim().replace(",", ".");
  if (!new RegExp(`^\\d{1,9}(?:\\.\\d{1,${precision}})?$`).test(text)) {
    throw new Error(
      `Введите положительное число: не больше ${precision} знаков после запятой.`,
    );
  }
  const [whole, fraction = ""] = text.split(".");
  return (
    Number(whole) * 10 ** precision + Number(fraction.padEnd(precision, "0"))
  );
}

export function fromUnits(units, precision = 3) {
  if (!Number.isSafeInteger(units) || units < 0)
    throw new Error("Некорректное значение.");
  const scale = 10 ** precision;
  return `${Math.floor(units / scale)}.${String(units % scale).padStart(precision, "0")}`;
}

export const formatNumber = (value, maximumFractionDigits = 3) =>
  new Intl.NumberFormat(getLocale(), { maximumFractionDigits }).format(
    Number(value),
  );
export const formatKg = (value) =>
  value == null ? "—" : translate("{{0}} кг", { 0: formatNumber(value) });
export const formatPrice = (value) =>
  value == null ? "Цена не указана" : `${formatNumber(value, 2)} KGS`;

export function requestTotal(quantity, price) {
  const cents =
    (BigInt(toUnits(quantity)) * BigInt(toUnits(price, 2)) + 500n) / 1000n;
  return `${cents / 100n}.${String(cents % 100n).padStart(2, "0")}`;
}

export function availableUnits(material, requests) {
  if (material.server) return toUnits(material.available_kg ?? "0");
  const consumed = requests
    .filter(
      (r) =>
        r.material_id === material.id &&
        ["confirmed", "transferred", "received", "reused"].includes(r.status),
    )
    .reduce((sum, r) => sum + toUnits(r.quantity_kg), 0);
  return toUnits(material.total_kg) - consumed;
}

export function createRequest(state, input, id, date) {
  const material = state.materials.find((m) => m.id === input.material_id);
  if (!material) throw new Error("Партия больше не доступна.");
  const quantity = toUnits(input.quantity_kg);
  if (quantity <= 0) throw new Error("Масса должна быть больше нуля.");
  if (quantity > availableUnits(material, state.requests))
    throw new Error("Запрошенная масса больше свободного остатка.");
  if (!input.organization_name?.trim())
    throw new Error("Укажите название мастерской.");
  if (state.requests.some((r) => r.id === id)) return state;
  return {
    ...state,
    requests: [
      {
        id,
        material_id: material.id,
        quantity_kg: fromUnits(quantity),
        price_per_kg: material.price_per_kg,
        organization_name: input.organization_name.trim(),
        purpose: input.purpose?.trim() || "",
        status: "pending",
        created_at: date,
      },
      ...state.requests,
    ],
  };
}

const nextStatus = {
  pending: "confirmed",
  confirmed: "transferred",
  transferred: "received",
  received: "reused",
};

export function transitionRequest(state, id, target) {
  const request = state.requests.find((r) => r.id === id);
  if (!request) throw new Error("Заявка не найдена.");
  if (request.status === target) return state;
  const canCancel =
    target === "cancelled" && ["pending", "confirmed"].includes(request.status);
  if (!canCancel && nextStatus[request.status] !== target)
    throw new Error("Это действие недоступно на текущем этапе.");
  if (target === "confirmed") {
    const material = state.materials.find((m) => m.id === request.material_id);
    if (
      !material ||
      toUnits(request.quantity_kg) > availableUnits(material, state.requests)
    ) {
      throw new Error(
        "Свободного материала уже недостаточно. Отмените заявку и выберите другой объём.",
      );
    }
  }
  return {
    ...state,
    requests: state.requests.map((r) =>
      r.id === id ? { ...r, status: target } : r,
    ),
  };
}

export function summarize(state) {
  if (state.mode === "api") {
    const a = state.analytics,
      p = state.publicStats;
    return {
      registered: p?.registered_kg ?? null,
      available: p?.available_kg ?? null,
      reused: p?.confirmed_reuse_kg ?? null,
      transferred: a?.transferred_kg ?? a?.received_kg ?? null,
      held: a?.held_kg ?? null,
      activeRequests: a?.active_reservations_count ?? 0,
    };
  }
  const sum = (statuses) =>
    state.requests
      .filter((r) => statuses.includes(r.status))
      .reduce((total, r) => total + toUnits(r.quantity_kg), 0);
  return {
    registered: fromUnits(
      state.materials.reduce((sum, m) => sum + toUnits(m.total_kg), 0),
    ),
    available: fromUnits(
      state.materials.reduce(
        (sum, m) => sum + availableUnits(m, state.requests),
        0,
      ),
    ),
    held: fromUnits(sum(["confirmed"])),
    transferred: fromUnits(sum(["transferred", "received", "reused"])),
    reused: fromUnits(sum(["reused"])),
    activeRequests: state.requests.filter((r) =>
      ["pending", "confirmed", "transferred"].includes(r.status),
    ).length,
  };
}

export function addMaterial(state, input, id, date) {
  if (!input.name?.trim()) throw new Error("Укажите название партии.");
  if (!input.material_type || !input.city?.trim() || !input.condition)
    throw new Error("Заполните тип, состояние и город.");
  if (!input.image) throw new Error("Добавьте хотя бы одно фото.");
  if (!input.confirmed) throw new Error("Подтвердите характеристики партии.");
  const mass = toUnits(input.total_kg);
  if (mass <= 0) throw new Error("Масса должна быть больше нуля.");
  const price = toUnits(input.price_per_kg, 2);
  const { confirmed, ...fields } = input;
  return {
    ...state,
    materials: [
      {
        ...fields,
        id,
        name: input.name.trim(),
        total_kg: fromUnits(mass),
        price_per_kg: fromUnits(price, 2),
        created_at: date,
        is_own: true,
      },
      ...state.materials,
    ],
  };
}
