import { useSyncExternalStore } from "react";
import { initialMaterials } from "../data/materials";
import {
  addMaterial,
  createRequest,
  summarize,
  toUnits,
  transitionRequest,
} from "./domain";

const STORAGE_KEY = "arta-web-demo-v1";
const fresh = () => ({
  version: 1,
  materials: structuredClone(initialMaterials),
  requests: [],
});
const listeners = new Set();

function read() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return fresh();
    const data = JSON.parse(raw);
    if (
      data.version !== 1 ||
      !Array.isArray(data.materials) ||
      !Array.isArray(data.requests)
    )
      throw new Error();
    const ids = new Set();
    data.materials = data.materials.map((material) => {
      if (
        !material ||
        typeof material.id !== "string" ||
        ids.has(material.id) ||
        typeof material.name !== "string" ||
        typeof material.image !== "string" ||
        !material.created_at
      )
        throw new Error();
      ids.add(material.id);
      toUnits(material.total_kg);
      toUnits(material.price_per_kg, 2);
      return {
        ...material,
        condition:
          { clean: "unused", mixed: "good" }[material.condition] ||
          material.condition,
      };
    });
    const requestIds = new Set();
    for (const request of data.requests) {
      if (
        !request ||
        !ids.has(request.material_id) ||
        typeof request.id !== "string" ||
        requestIds.has(request.id) ||
        ![
          "pending",
          "confirmed",
          "transferred",
          "received",
          "reused",
          "cancelled",
        ].includes(request.status) ||
        !Number.isFinite(Date.parse(request.created_at))
      )
        throw new Error();
      requestIds.add(request.id);
      if (toUnits(request.quantity_kg) <= 0) throw new Error();
      toUnits(request.price_per_kg, 2);
    }
    summarize(data);
    return data;
  } catch {
    return {
      ...fresh(),
      storageWarning:
        "Не удалось прочитать сохранённые данные. Их можно очистить на странице «Мои заявки».",
    };
  }
}

let state = read();
const emit = () => listeners.forEach((listener) => listener());
const subscribe = (listener) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};
export const useDemo = () => useSyncExternalStore(subscribe, () => state);

window.addEventListener("storage", (event) => {
  if (event.key === STORAGE_KEY || event.key === null) {
    state = read();
    emit();
  }
});

function mutate(transform) {
  const latest = read();
  if (latest.storageWarning) throw new Error(latest.storageWarning);
  const next = transform(latest);
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    throw new Error(
      "Не удалось сохранить изменения. Проверьте доступ к хранилищу браузера или уменьшите фото.",
    );
  }
  state = next;
  emit();
}

export const demoRepository = {
  createMaterial(input) {
    const id = crypto.randomUUID();
    mutate((state) => addMaterial(state, input, id, new Date().toISOString()));
    return id;
  },
  createRequest(input) {
    const id = crypto.randomUUID();
    mutate((state) =>
      createRequest(state, input, id, new Date().toISOString()),
    );
    return id;
  },
  transition(id, target) {
    mutate((state) => transitionRequest(state, id, target));
  },
  reset() {
    const next = fresh();
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch {
      throw new Error("Хранилище браузера недоступно.");
    }
    state = next;
    emit();
  },
};
