import test from "node:test";
import assert from "node:assert/strict";
import {
  addMaterial,
  availableUnits,
  createRequest,
  fromUnits,
  requestTotal,
  summarize,
  toUnits,
  transitionRequest,
} from "../src/lib/domain.js";

const fresh = () => ({
  materials: [{ id: "cotton", total_kg: "100.000", price_per_kg: "80.00" }],
  requests: [],
});
const request = (state, quantity = "20", id = "r1") =>
  createRequest(
    state,
    { material_id: "cotton", quantity_kg: quantity, organization_name: "Демо" },
    id,
    "2026-11-07T12:00:00Z",
  );

test("reservation and transfer never count as reuse; reuse counts only once", () => {
  let state = request(fresh(), "20.125");
  assert.equal(summarize(state).available, "100.000");
  for (const status of ["confirmed", "transferred", "received"]) {
    state = transitionRequest(state, "r1", status);
    assert.equal(summarize(state).reused, "0.000");
    assert.equal(summarize(state).available, "79.875");
  }
  state = transitionRequest(state, "r1", "reused");
  state = transitionRequest(state, "r1", "reused");
  assert.equal(summarize(state).reused, "20.125");
  assert.equal(summarize(state).transferred, "20.125");
  assert.equal(summarize(state).available, "79.875");
});

test("competing requests cannot reserve more than the available stock", () => {
  let state = request(request(fresh(), "60", "r1"), "60", "r2");
  state = transitionRequest(state, "r1", "confirmed");
  assert.throws(
    () => transitionRequest(state, "r2", "confirmed"),
    /недостаточно/,
  );
  assert.equal(availableUnits(state.materials[0], state.requests), 40000);
  state = transitionRequest(state, "r1", "cancelled");
  state = transitionRequest(state, "r2", "confirmed");
  assert.equal(summarize(state).held, "60.000");
});

test("impossible transitions and cancellation after transfer are rejected", () => {
  const state = request(fresh());
  assert.throws(() => transitionRequest(state, "r1", "reused"), /недоступно/);
  const transferred = transitionRequest(
    transitionRequest(state, "r1", "confirmed"),
    "r1",
    "transferred",
  );
  assert.throws(
    () => transitionRequest(transferred, "r1", "cancelled"),
    /недоступно/,
  );
});

test("invalid, negative, overprecise and excessive amounts are rejected", () => {
  for (const input of [
    "0",
    "-1",
    "NaN",
    "Infinity",
    "0.0001",
    "",
    "101",
    "1e3",
  ])
    assert.throws(() => request(fresh(), input));
  assert.equal(toUnits("0,125"), 125);
  assert.equal(fromUnits(125), "0.125");
  assert.equal(requestTotal("0.125", "80.50"), "10.06");
});

test("publication requires a photo, positive mass and human confirmation", () => {
  const input = {
    name: "Остатки",
    material_type: "cotton",
    total_kg: "1",
    price_per_kg: "0",
    city: "Бишкек",
    condition: "unused",
    image: "/image.png",
    confirmed: true,
  };
  for (const patch of [
    { image: "" },
    { confirmed: false },
    { total_kg: "0" },
    { name: " " },
  ])
    assert.throws(() =>
      addMaterial(
        fresh(),
        { ...input, ...patch },
        "new",
        "2026-11-07T12:00:00Z",
      ),
    );
  const state = addMaterial(fresh(), input, "new", "2026-11-07T12:00:00Z");
  assert.equal(state.materials[0].total_kg, "1.000");
  assert.equal(state.materials[0].price_per_kg, "0.00");
});
