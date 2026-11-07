import { useSyncExternalStore } from "react";
import { MODE, api, json, mediaUrl } from "./api";
import { useDemo, demoRepository } from "./demo-store";
import { fromUnits, toUnits } from "./domain";

const listeners = new Set();
let state = {
  mode: "api",
  user: null,
  organization: null,
  ready: false,
  materials: [],
  catalog: [],
  requests: [],
  catalogTotal: 0,
  requestTotal: 0,
  requestPage: 1,
  publicStats: null,
  analytics: null,
  cities: [],
  loading: false,
  error: "",
};
const set = (change) => {
  state = { ...state, ...change };
  listeners.forEach((fn) => fn());
};
const subscribe = (fn) => {
  listeners.add(fn);
  return () => listeners.delete(fn);
};
export const useStore =
  MODE === "demo"
    ? useDemo
    : () => useSyncExternalStore(subscribe, () => state);
let sessionEpoch = 0,
  catalogSequence = 0,
  bootPromise;
let catalogParams = {};
const intents = new Map();
async function mutation(path, method, body) {
  const fingerprint = path + JSON.stringify(body);
  if (!intents.has(fingerprint)) intents.set(fingerprint, crypto.randomUUID());
  const result = await api(path, {
    ...json(method, body),
    headers: { "Idempotency-Key": intents.get(fingerprint) },
  });
  intents.delete(fingerprint);
  return result;
}
async function materialDTO(m, owner = false) {
  let image = "";
  if (m.images?.length) {
    const result = await api(
      `${owner ? "" : "/public"}/materials/${m.id}/images/${m.images[0].id}/url`,
    );
    image = mediaUrl(result.url);
  }
  return {
    ...m,
    image,
    is_own:
      owner ||
      Boolean(
        state.user?.organization_id &&
        m.organization_id === state.user.organization_id,
      ),
    available_kg: m.balance?.available_kg ?? m.available_kg,
    total_kg: m.balance?.total_kg ?? null,
    description: m.description || "",
    organization_name: m.organization_name || state.organization?.name || "",
    server: true,
  };
}
function mergeMaterials(items) {
  const map = new Map(state.materials.map((m) => [m.id, m]));
  items.forEach((m) => map.set(m.id, m));
  return [...map.values()];
}
export async function loadCatalog(params = catalogParams) {
  catalogParams = params;
  if (MODE === "demo") return;
  const seq = ++catalogSequence,
    epoch = sessionEpoch;
  set({ loading: true, error: "" });
  try {
    const filters = Object.fromEntries(
      Object.entries(params).filter(
        ([, value]) => value != null && String(value).trim() !== "",
      ),
    );
    const query = new URLSearchParams({
      page: "1",
      page_size: "6",
      ...filters,
    });
    const data = await api("/public/materials?" + query);
    const items = await Promise.all(data.items.map((m) => materialDTO(m)));
    if (seq === catalogSequence && epoch === sessionEpoch)
      set({
        catalog: items,
        materials: mergeMaterials(items),
        catalogTotal: data.total,
        loading: false,
      });
  } catch (error) {
    if (seq === catalogSequence)
      set({ error: error.message, loading: false, catalog: [] });
  }
}
export async function loadMaterial(id) {
  if (MODE === "demo") return;
  const epoch = sessionEpoch;
  try {
    let m,
      owner = false;
    try {
      m = await api("/public/materials/" + id);
      if (state.user?.organization_id === m.organization_id) {
        m = await api("/materials/" + id);
        owner = true;
      }
    } catch (error) {
      if (error.status !== 404 || state.user?.role !== "enterprise")
        throw error;
      m = await api("/materials/" + id);
      owner = true;
    }
    const result = await materialDTO(m, owner);
    if (epoch === sessionEpoch)
      set({ materials: mergeMaterials([result]), error: "" });
    return result;
  } catch (error) {
    set({ error: error.message });
    throw error;
  }
}
export async function refreshAccount(page = 1) {
  if (MODE === "demo" || !state.user) return;
  const epoch = sessionEpoch;
  try {
    const [data, analytics] = await Promise.all([
      api("/reservations?page=" + page),
      api("/analytics/summary"),
    ]);
    if (epoch !== sessionEpoch) return;
    const requests = data.items.map((r) => ({
      ...r,
      price_per_kg: r.agreed_price_per_kg,
      organization_name: r.counterparty_contacts?.contact_name || "",
      status:
        r.status === "completed"
          ? Number(r.transaction.confirmed_reuse_kg) >=
            Number(r.transaction.transferred_kg)
            ? "reused"
            : "received"
          : r.status,
      server_status: r.status,
    }));
    set({
      requests,
      requestTotal: data.total,
      requestPage: page,
      analytics,
      error: "",
    });
  } catch (error) {
    if (epoch === sessionEpoch) {
      if (error.status === 401)
        set({ user: null, organization: null, requests: [], analytics: null });
      set({ error: error.message });
    }
  }
}
export async function refreshPublic() {
  if (MODE === "demo") return;
  try {
    const [publicStats, cities] = await Promise.all([
      api("/public/statistics"),
      api("/public/material-cities"),
    ]);
    set({ publicStats, cities });
  } catch (error) {
    set({ error: error.message });
  }
}
export function bootstrap() {
  if (MODE === "demo") return Promise.resolve();
  if (bootPromise) return bootPromise;
  bootPromise = (async () => {
    try {
      const account = await api("/auth/me");
      set(account);
    } catch (error) {
      if (error.status !== 401) set({ error: error.message });
    } finally {
      set({ ready: true });
    }
    await Promise.all([refreshPublic(), loadCatalog(), refreshAccount()]);
  })();
  return bootPromise;
}
export async function login(email, password) {
  if (MODE === "demo") throw new Error("Для входа включите режим API.");
  await api(
    "/auth/session",
    json("POST", { email: email.trim().toLowerCase(), password }),
  );
  sessionEpoch++;
  intents.clear();
  const account = await api("/auth/me");
  set({
    ...account,
    materials: [],
    requests: [],
    analytics: null,
    error: "",
    ready: true,
  });
  await Promise.all([refreshAccount(), loadCatalog()]);
  return account;
}
export async function logout() {
  await api("/auth/session", { method: "DELETE" });
  sessionEpoch++;
  intents.clear();
  set({
    user: null,
    organization: null,
    requests: [],
    materials: [],
    analytics: null,
    error: "",
  });
  await loadCatalog();
}
export const register = (values) => api("/auth/register", json("POST", values));
export const forgotPassword = (email) =>
  api(
    "/auth/forgot-password",
    json("POST", { email: email.trim().toLowerCase() }),
  );
export const resetPassword = (token, password) =>
  api("/auth/reset-password", json("POST", { token, password }));

export async function saveDraft(input, existingId = null) {
  const fields = {
    name: input.name,
    material_type: input.material_type || null,
    condition: input.condition || null,
    city: input.city || null,
    total_kg: fromUnits(toUnits(input.total_kg)),
    price_per_kg: input.price_per_kg.trim()
      ? fromUnits(toUnits(input.price_per_kg, 2), 2)
      : null,
    composition: input.composition.trim() || null,
    scrap_size: input.scrap_size.trim() || null,
    description: input.description.trim() || null,
  };
  if (existingId) {
    const current = await api("/materials/" + existingId);
    return api(
      "/materials/" + existingId,
      json("PATCH", { ...fields, version: current.version }),
    );
  }
  return api("/materials", json("POST", fields));
}
export async function uploadPhoto(id, file) {
  const form = new FormData();
  form.append("file", file);
  return api(`/materials/${id}/images`, { method: "POST", body: form });
}
export async function analyze(id, onUpdate) {
  const accepted = await api("/ai/analyze", json("POST", { material_id: id }));
  const deadline = Date.now() + 90000;
  while (Date.now() < deadline) {
    const job = await api("/ai/analyses/" + accepted.analysis_id);
    onUpdate(job);
    if (["succeeded", "failed", "interrupted"].includes(job.status)) return job;
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error("Анализ ещё выполняется. Обновите состояние позже.");
}
export async function latestAnalysis(id) {
  return api("/materials/" + id + "/analysis");
}
export async function publishDraft(id, analysisId) {
  let m = await api("/materials/" + id);
  m = await api(
    `/materials/${id}/confirm`,
    json("POST", {
      version: m.version,
      ...(analysisId ? { analysis_id: analysisId } : {}),
    }),
  );
  m = await api(
    `/materials/${id}/publish`,
    json("POST", { version: m.version }),
  );
  const result = await materialDTO(m, true);
  set({ materials: mergeMaterials([result]) });
  await refreshPublic();
  return id;
}
const liveRepository = {
  async createRequest(input) {
    if (state.user?.role !== "buyer")
      throw new Error("Войдите с аккаунтом покупателя.");
    const result = await mutation("/reservations", "POST", {
      material_id: input.material_id,
      quantity_kg: fromUnits(toUnits(input.quantity_kg)),
      purpose: input.purpose?.trim() || null,
    });
    await refreshAccount();
    return result.id;
  },
  async transition(id, target, options = {}) {
    const request = state.requests.find((r) => r.id === id);
    if (!request) throw new Error("Обновите список заявок.");
    if (target === "reused") {
      await mutation(
        `/transactions/${request.transaction.id}/reuse-confirmation`,
        "POST",
        {
          reused_kg: fromUnits(toUnits(options.quantity)),
          basis: options.basis,
        },
      );
    } else {
      const action = {
        confirmed: "confirm",
        cancelled: "cancel",
        transferred: "transfer",
        received: "complete",
      }[target];
      await mutation("/reservations/" + id, "PATCH", {
        action,
        ...(target === "cancelled"
          ? { reason: options.basis || "Отмена участником" }
          : {}),
        ...(target === "transferred" && options.quantity
          ? { transferred_kg: fromUnits(toUnits(options.quantity)) }
          : {}),
      });
    }
    await Promise.all([refreshAccount(state.requestPage), refreshPublic()]);
  },
};
export const repository = MODE === "demo" ? demoRepository : liveRepository;
