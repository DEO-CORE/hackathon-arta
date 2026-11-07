import test from "node:test";
import assert from "node:assert/strict";
import {
  validateRegistrationProfile,
  registrationPayload,
} from "../src/lib/auth.js";

const profile = {
  role: "buyer",
  name: "",
  activity_type: "",
  contact_name: " Айдана ",
  city: " Ош ",
  email: " AIDANA@EXAMPLE.COM ",
  password: " unchanged password ",
};

test("buyers need only their name and city, sellers still need an organisation and activity", () => {
  assert.deepEqual(validateRegistrationProfile(profile), {});
  assert.deepEqual(
    Object.keys(
      validateRegistrationProfile({ ...profile, contact_name: " ", city: " " }),
    ).sort(),
    ["city", "contact_name"],
  );
  assert.deepEqual(
    Object.keys(
      validateRegistrationProfile({ ...profile, role: "enterprise" }),
    ).sort(),
    ["activity_type", "name"],
  );
  assert.deepEqual(
    validateRegistrationProfile({
      ...profile,
      role: "enterprise",
      name: "Жип",
      activity_type: "workshop",
      contact_name: "",
    }),
    {},
  );
  assert.ok(validateRegistrationProfile({ ...profile, role: "admin" }).role);
  assert.ok(
    validateRegistrationProfile({ ...profile, contact_name: "a".repeat(201) })
      .contact_name,
  );
});

test("buyer payload excludes retained organisation fields and preserves password verbatim", () => {
  assert.deepEqual(
    registrationPayload({
      ...profile,
      name: "Hidden company",
      activity_type: "recycler",
    }),
    {
      email: "aidana@example.com",
      password: profile.password,
      role: "buyer",
      profile: { name: "Айдана", city: "Ош" },
    },
  );
});

test("seller payload uses the existing organisation contract with optional contact", () => {
  const values = {
    ...profile,
    role: "enterprise",
    name: " Жип ",
    activity_type: "workshop",
  };
  assert.deepEqual(registrationPayload(values), {
    email: "aidana@example.com",
    password: profile.password,
    role: "enterprise",
    organization: {
      name: "Жип",
      city: "Ош",
      activity_type: "workshop",
      contacts: { contact_name: "Айдана" },
    },
  });
  assert.equal(
    Object.hasOwn(
      registrationPayload({ ...values, contact_name: " " }).organization,
      "contacts",
    ),
    false,
  );
});
