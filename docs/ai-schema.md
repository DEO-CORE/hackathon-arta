# ARTA — AI analysis schema (CON-02)

Status: specification only, no code. Owner: ai-engineer. Basis: `CLAUDE.md` §6, §11; `docs/decisions.md` D-07.
Schema version: `schema_version = "1.0"`. Any change of fields, enums or limits bumps the version.

## 1. Principles

- AI returns only suggestions about what is visible in the photo: colour, pattern, apparent texture, reuse ideas.
- Composition, weight, strength, safety and chemical properties cannot be determined from a photo. The schema has no fields for them. A provider response that contains any extra field is rejected (`extra="forbid"`).
- Unknown is expressed as `null` or the enum value `unknown`, never as a guess.
- The result is stored separately from confirmed material attributes. AI never writes confirmed attributes.
- The schema contains no prices, demand, CO2 or other economic or environmental figures.

## 2. Two models

1. `VisionModelOutput` is what the provider must return (validated strictly). It never contains `material_id`, status, provider or model: the backend sets those, so the model cannot spoof them.
2. `AnalysisResponse` is the API DTO for `GET /ai/analyses/{id}`: backend metadata plus the validated `VisionModelOutput` as `result`.

### 2.1 VisionModelOutput

| Field | Type | Rules |
| --- | --- | --- |
| `visual_features` | `VisualFeatures` | required |
| `reuse_options` | `list[ReuseOption]` | 0..5 items; no two items with the same `reuse_type` |
| `notes` | `str \| null` | max 500 chars; only visual remarks (e.g. "photo is blurry"); plain text, no markup |

`extra="forbid"` on every nested model.

### 2.2 VisualFeatures

Each of the three features is a `FeatureObservation`. A feature is never omitted: when it cannot be judged, `value` is `null` and `confidence` is `unknown`.

| Field | Type |
| --- | --- |
| `color` | `ColorObservation` |
| `pattern` | `PatternObservation` |
| `apparent_texture` | `TextureObservation` |

`ColorObservation`:
- `primary` : `ColorName | null` (enum below)
- `secondary` : `list[ColorName]`, max 3, no duplicates, must not contain `primary`
- `description` : `str | null`, max 120 chars
- `confidence` : `Confidence`

`PatternObservation`:
- `value` : `PatternType | null` (enum below)
- `description` : `str | null`, max 120 chars
- `confidence` : `Confidence`

`TextureObservation`:
- `value` : `ApparentTexture | null` (enum below)
- `description` : `str | null`, max 120 chars
- `confidence` : `Confidence`
- The field name `apparent_texture` and the text of the prompt state that this is the visual appearance only. It is not a statement about fibre or weave composition.

Consistency rule: if `value`/`primary` is `null`, then `confidence` must be `unknown`. If `confidence` is `unknown`, then `value`/`primary` must be `null`.

### 2.3 ReuseOption

| Field | Type | Rules |
| --- | --- | --- |
| `reuse_type` | `ReuseType` | enum below |
| `suitability` | `Suitability` | enum below |
| `reason` | `str` | required, 10..300 chars after trim, must be based on visible features |

Maximum number of options: **5**. Reason: the `ReuseType` enum has 7 values, and 5 keeps the screen readable on a phone and prevents the model from padding the list with weak ideas. The prompt asks for the best options, ordered by suitability. The backend sorts the list (suitability descending, then `reuse_type` alphabetically) so the order is stable.

### 2.4 Enums

String enums, lowercase snake_case, defined once in the backend and reused in tests and OpenAPI. They are not duplicated in material schemas: material fields (type, condition) use their own enums owned by the backend schemas.

- `Confidence`: `high`, `medium`, `low`, `unknown`. Coarse levels on purpose: a numeric confidence from an LLM would give false precision.
- `ColorName`: `white`, `black`, `gray`, `beige`, `brown`, `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `multicolor`, `other`.
- `PatternType`: `solid`, `striped`, `checked`, `floral`, `geometric`, `printed_other`, `mixed`, `other`.
- `ApparentTexture`: `smooth`, `ribbed`, `woven_looking`, `knit_looking`, `fleecy`, `fuzzy`, `glossy`, `rough`, `other`. The "looking" values mean visual impression only.
- `ReuseType`: `cleaning_rags`, `stuffing_filling`, `patchwork_crafts`, `accessories_small_goods`, `insulation_padding`, `recycling_shredding`, `other`.
- `Suitability`: `high`, `medium`, `low`, `unknown`. The model may not return "unsuitable" as a reuse idea: an unsuitable option is simply omitted.

## 3. AnalysisResponse (API DTO)

| Field | Type | Notes |
| --- | --- | --- |
| `analysis_id` | UUID | |
| `material_id` | UUID | set by backend |
| `status` | `AnalysisStatus` | `pending`, `running`, `succeeded`, `failed`, `interrupted` |
| `input_version` | int | material version the analysis was started for |
| `is_stale` | bool | computed on read: `input_version != material.version` |
| `schema_version` | str | `"1.0"` |
| `provider` | str \| null | e.g. `openai`, `anthropic`, `mock`; set when the run starts |
| `model` | str \| null | model name from configuration |
| `is_mock` | bool | true when provider is `mock`; UI must label it "демо / не реальный AI" |
| `result` | `VisionModelOutput \| null` | non-null only when `status == succeeded` |
| `requires_confirmation` | `Literal[True]` | always `true`, also for stale or failed analyses |
| `error_code` | `AnalysisErrorCode \| null` | non-null only for `failed` and `interrupted` |
| `created_at`, `started_at`, `finished_at` | UTC datetime | `started_at`/`finished_at` nullable |
| `confirmed_at`, `confirmed_by` | datetime \| UUID, nullable | filled only by the human confirmation endpoint, never by the AI module |

`requires_confirmation` is `Literal[True]`: the type does not allow `false`, and a test asserts that the serialized value is `true` for every status.

`AnalysisErrorCode` (error_code enum, safe to show to the user; no provider details):
`provider_timeout`, `provider_unavailable`, `provider_rate_limited`, `provider_auth_error`, `provider_refused`, `invalid_json`, `schema_violation`, `no_images`, `image_unavailable`, `interrupted_restart`, `internal_error`.

The `ai_analyses` row additionally stores `attempts` (int), and the original raw provider text is not stored for failures (see section 7).

## 4. Status lifecycle

```
pending -> running -> succeeded
                  \-> failed
pending|running -> interrupted   (set at application start for left-over jobs, D-07)
```

- `POST /ai/analyze`: check ownership, check that the material has at least one photo (else 422 `no_images`), save the row with `pending` and the current `input_version`, return 202 with `analysis_id`, then start a FastAPI background task.
- Transitions are one-way. `succeeded`, `failed` and `interrupted` are terminal. A new attempt creates a new analysis row.
- An AI outage ends in `failed` with `error_code`. It never blocks catalog access or manual entry/confirmation.

## 5. Validation rules (invalid output is never `succeeded`)

1. The provider response is parsed as JSON. Parse error leads to `failed`, `invalid_json`.
2. The parsed object is validated with `VisionModelOutput` (strict enums, `extra="forbid"`, string length limits, max 5 options, consistency rules from 2.2). Any violation leads to `failed`, `schema_violation`.
3. Text fields are trimmed; control characters are rejected; HTML/markdown is not interpreted. Fields are length-limited before storage and before display.
4. Only after step 2 passes is `validated_result` written and `status` set to `succeeded`. The write of `result` and the status change happen in one transaction.
5. No repair by guessing: the backend does not fill missing fields with defaults and does not auto-correct enums.
6. Retries: only for temporary errors (timeout, 5xx, 429), at most 2 retries with backoff; `invalid_json` and `schema_violation` are not retried by default (at most one re-ask is allowed and must be recorded in `attempts`). Authentication errors are not retried.
7. Timeout comes from `VISION_TIMEOUT_SECONDS` and covers one provider call; a timeout leads to `provider_timeout` after retries are exhausted.
8. A provider refusal or safety block leads to `failed`, `provider_refused`.

## 6. input_version rules

- `input_version` is the integer `materials.version` at the moment the analysis is created. The backend increments `materials.version` on any change that affects what the analysis saw: add/remove/reorder photo, change of material type, condition, declared composition, dimensions, or text description. Changes to fields that do not affect the analysis (e.g. price) follow the backend rule in the material service but must be listed there explicitly.
- The row also stores `input_fingerprint`: SHA-256 over the ordered list of photo object keys with each photo's content SHA-256 and the analysis-relevant material fields in canonical JSON. It is for audit and for detecting a photo replaced under the same key; the authoritative check is `input_version`.
- Confirmation (`POST /materials/{id}/confirm`) accepts an `analysis_id` only if all hold: the analysis belongs to this material and to the caller's organization, `status == succeeded`, `analysis.input_version == material.version`, and the client-sent `version` equals the current `material.version`. Otherwise 409 (`stale_analysis`).
- An old analysis therefore cannot confirm a new version of the material. After a change the user starts a new analysis or confirms manually without AI.
- The confirmation endpoint takes attributes from the human's request body. It never copies fields from `validated_result` automatically. The UI may prefill a form with suggestions, but the human submits the values. The AI module has no code path that writes to `materials` confirmed fields.
- Matching and the optimizer read only confirmed attributes of the current version, never `validated_result`.

## 7. What AI cannot do

- Write to the database other than its own `ai_analyses` row (status, provider, model, result, error_code). No write access to `materials` confirmed fields, stock, reservations, allocations, transactions or impact records. The job service uses a narrow function interface for this row only.
- Confirm a material or an analysis.
- Call tools. The provider request contains no tool/function definitions, no SQL, no secrets, no URLs to fetch.
- Follow instructions found in the photo (text on labels, handwritten notes, QR codes) or in user-entered text. The prompt states that all such content is data, not instructions. Any text visible in the image is not copied into structured fields beyond the length-limited `description`/`reason` fields, and is never executed or used as a prompt for another call.
- Produce composition, weight, strength, safety, chemical, price, demand or CO2 values. If the model returns such a field, the extra-field check fails the response with `schema_violation`.

On failure, the raw provider text is not stored and not logged in full. Only `error_code`, a hash of the response, and its length may be logged, together with `request_id` and `analysis_id`.

## 8. Data sent to the provider

Minimum data only:

- Images: bytes read by the backend from the private storage by the stored object key of this material (never a user-supplied URL; no downloading of arbitrary URLs). Images are sent as inline data, not as signed URLs, so no signed URL leaves the backend. Maximum 5 photos (the upload limit); optional downscale to a fixed long side to reduce size.
- Text: the fixed system prompt, and optionally the declared material type and condition from the material (enum values), as context. Free-text fields entered by users are not sent by default; if ever sent, they are wrapped as untrusted data and length-limited.
- Not sent: organization name, contacts, e-mail, phone, address, user IDs, prices, buyer data, internal UUIDs, object keys, JWT, signed URLs, other materials.
- Logging: never log API keys, signed URLs, image bytes, base64 data, or full request/response payloads. Log only `analysis_id`, `request_id`, provider, model, duration, attempt number and `error_code`.
- Provider, model, key and timeout come from `VISION_PROVIDER`, `VISION_MODEL`, `VISION_API_KEY`, `VISION_TIMEOUT_SECONDS`. The mock provider is allowed only in tests and in explicit `DEMO_MODE`; its results carry `provider = "mock"` and `is_mock = true`. Production refuses to start without a real provider configuration and does not silently fall back to mock.

## 9. Test requirements derived from this spec

- Valid JSON leads to `succeeded` with a stored `validated_result`.
- Invalid JSON, unknown enum, extra field (e.g. `composition`, `weight_kg`, `safe`), more than 5 options, over-long `reason`, duplicate `reuse_type`, `null` value with non-`unknown` confidence: all lead to `failed`, no `result`.
- Timeout leads to `failed` / `provider_timeout`; temporary errors are retried at most twice; auth error is not retried.
- Unknown composition: the output has no composition field and the stored material composition is unchanged.
- No auto-confirm: after a `succeeded` analysis, the material's confirmed fields and `confirmed_at` are unchanged.
- Stale analysis (`input_version != material.version`) cannot confirm (409).
- `requires_confirmation` is `true` for every status.
- Startup moves `pending`/`running` rows to `interrupted` with `interrupted_restart`.
- The request sent to the mock/fake provider contains no contacts, no signed URL and no object keys.

## 10. Open items

- Provider and model are not chosen (BLK-02). When chosen, record it in `docs/decisions.md`. The schema is provider-neutral; if the provider supports structured output/JSON schema, use it as an extra guard, but Pydantic validation stays mandatory.
- Which material fields bump `materials.version` is owned by backend-engineer; this document requires only that photo and analysis-relevant field changes do.

## 11. Mobile contract, Phase 3 (AI analysis)

Status: contract only, nothing here is implemented. Date: 2026-11-07. Owner: ai-engineer. Written for the mobile client (screen S06). Sections 1-10 stay valid; where section 11 differs, section 11 wins and the difference is named in 11.9. Endpoints are only those already in `docs/api.md` (sections 4, 10, 17.9): `POST /ai/analyze`, `GET /ai/analyses/{id}`, `POST /materials/{id}/confirm`. Nothing is invented. The provider is not chosen (BLK-02 is open); every statement about a provider is configuration-level.

### 11.1 POST /ai/analyze

Role: enterprise owner. Codes: 202, 401, 403, 404, 409 `PRECONDITION_FAILED` (`details.reason = "NO_IMAGES"`), 422, 429.

Request `AnalyzeIn` is unchanged and frozen: `{ "material_id": "<uuid>" }`. Two things the task asked for are deliberately NOT request fields:
- `images`: the client never sends images, keys or URLs. The backend takes the stored photos of this material by object key from private storage (CLAUDE.md §6, §11). A client-supplied key or URL would let a user point the analysis at somebody else's object.
- `input_version`: the server reads `materials.version` itself and returns it in the response. The client cannot choose which version it analyses.

Response 202 (header `Location: /ai/analyses/{analysis_id}`), frozen:

```json
{ "analysis_id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d", "status": "pending", "input_version": 4 }
```

Rules: the row is saved first, then the background task starts (D-07). If a `pending`/`running` analysis for the same material and the same `input_version` already exists, the server returns 202 with that existing `analysis_id` instead of creating a second job (A-AI-6). A material without photos gives 409 `NO_IMAGES`, no row is created.

### 11.2 GET /ai/analyses/{id}

Role: enterprise owner; somebody else's analysis is 404. Fields of `AnalysisOut` as in api.md 17.9, with the following fixed meaning:

| Field | Type | Meaning |
| --- | --- | --- |
| `id`, `material_id` | uuid | |
| `status` | `pending` / `running` / `succeeded` / `failed` / `interrupted` | wire names unchanged, see 11.3 |
| `input_version`, `is_current` | int, bool | `is_current` false means the material changed after the start; the result cannot confirm anything |
| `mode` | `live` / `mock` / `fallback` or null | null until `succeeded`; set by the server from configuration, never by the client or the model |
| `schema_version` | string or null | `"1.0"` after 11.9 |
| `provider`, `model` | string or null | for demo `provider = "mock"` |
| `result` | `VisionModelOutput` or null | only when `succeeded` and validated; shape in 2.1-2.3 |
| `requires_confirmation` | `true` | always, for every status, also failed and stale |
| `error_code` | string or null | only for `failed` / `interrupted`, list in 11.6 |
| `confirmed_at`, `confirmed_by` | datetime / uuid or null | |
| `created_at`, `updated_at` | datetime | |

`result` contents (the whole screen payload, no other source):
- `visual_features.color` { `primary`, `secondary[]`, `description`, `confidence` }, `visual_features.pattern` { `value`, `description`, `confidence` }, `visual_features.apparent_texture` { `value`, `description`, `confidence` }. `confidence` is `high` / `medium` / `low` / `unknown` (coarse on purpose, 2.4). Unknown: value `null` and confidence `unknown`.
- `reuse_options[]`: at most 5; each has `reuse_type`, `suitability` (`high` / `medium` / `low` / `unknown`) and `reason` (10..300 chars). An item without a valid `reason` makes the whole response invalid (no partial display).
- `notes`: optional, max 500 chars, visual remarks only.

Example of a successful response:

```json
{ "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d", "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70",
  "status": "succeeded", "input_version": 4, "is_current": true, "mode": "mock",
  "schema_version": "1.0", "provider": "mock", "model": "mock-fixture-1",
  "requires_confirmation": true,
  "result": {
    "visual_features": {
      "color": { "primary": "blue", "secondary": [], "description": "светло-синий", "confidence": "medium" },
      "pattern": { "value": "solid", "description": null, "confidence": "high" },
      "apparent_texture": { "value": null, "description": null, "confidence": "unknown" } },
    "reuse_options": [ { "reuse_type": "patchwork_crafts", "suitability": "high",
                         "reason": "Однотонные крупные обрезки удобно сшивать." } ],
    "notes": null },
  "error_code": null, "confirmed_at": null, "confirmed_by": null,
  "created_at": "2026-11-07T10:30:00Z", "updated_at": "2026-11-07T10:30:12Z" }
```

### 11.3 Statuses: decision

Decision: the wire statuses stay `pending` / `running` / `succeeded` / `failed` / `interrupted` (no rename of the frozen contract), and the client maps them to the four display states pending, processing, completed, failed.

Reasons: (1) `succeeded`/`running` are already frozen in api.md 4/10/17.9 and in CON-02; renaming would break the contract and every test derived from it for no new information. (2) `interrupted` must stay distinguishable on the wire: it is a server-side event (restart, D-07), the user did nothing wrong, and the retry rule differs (11.5). A subtype of `failed` would force the client to read `error_code` to know that. (3) A mapping is one small pure function in the client.

Client mapping (display state, not a second contract):

| Wire `status` | Display state | Screen behaviour |
| --- | --- | --- |
| `pending` | pending | "Анализ в очереди", poll |
| `running` | processing | "Анализ выполняется", poll |
| `succeeded` | completed | show suggestions (if `is_current`) |
| `failed` | failed | message by `error_code`, retry rule 11.5 |
| `interrupted` | failed | "Анализ прерван. Запустите заново." |
| unknown value | failed | neutral message, manual form stays usable |

Transitions (one-way; terminal: `succeeded`, `failed`, `interrupted`):

```
pending --(task starts)--> running --(valid result)--> succeeded
running --(error after retries, invalid output, refusal)--> failed
pending|running --(application start finds the job, D-07)--> interrupted  [error_code INTERRUPTED]
```

- A `pending` job whose task never started (process died between commit and task start) is also moved to `interrupted` at the next application start. There is no timer-based recovery while the process lives (A-AI-7), except the per-job deadline below, which ends a running job as `failed` / `PROVIDER_TIMEOUT`.
- A terminal row is never changed again. A new attempt is a new row with a new `analysis_id`.
- Polling is by the client, 2 s interval, ceiling 90 s (A17-2). After the ceiling the client stops polling and shows "Анализ занимает дольше обычного" with a "Проверить снова" button that resumes polling the same `analysis_id`; it does not create a new job.
- AI outage never blocks the catalog, manual entry or confirmation.

### 11.4 Human confirmation

- `POST /materials/{id}/confirm` body `MaterialConfirmIn`: `version` (required) and `analysis_id` (optional). The characteristic values being confirmed are the values already stored in the material fields by the human (via `PATCH /materials/{id}`); the confirm call does not carry copied AI values and the server never reads `result` to fill them.
- An AI result by itself confirms nothing. After `succeeded` the material's confirmed fields, `confirmed_at` and `confirmed_by` stay unchanged. "Принять в форму" on S06 only copies a suggestion into the editable form (still unconfirmed, marked "Взято из предложения ИИ"); the human then saves via PATCH and confirms.
- Stale check. With `analysis_id` set, the server requires: analysis belongs to this material and caller's organization; `status == succeeded`; `analysis.input_version == material.version`; request `version == material.version`. Any failure gives 409. In the frozen envelope this is `409 PRECONDITION_FAILED` with `details.reason`: `ANALYSIS_NOT_FOUND_FOR_MATERIAL`, `ANALYSIS_NOT_SUCCEEDED` or `ANALYSIS_STALE`; a stale request `version` gives `409 VERSION_CONFLICT`. The name `stale_analysis` used in sections 6 and 4 of this file and in the task is the logical name of `PRECONDITION_FAILED` / `ANALYSIS_STALE`; there is no separate envelope code (A-AI-1).
- Client behaviour on `ANALYSIS_STALE`: hide the old suggestions as outdated ("Данные партии изменились после анализа"), offer "Повторить анализ" and keep manual confirmation available (confirm without `analysis_id` is allowed).
- Confirm without any analysis is allowed. Unknown composition is allowed (`composition = null`).
- What AI never gives and the client never presents as a fact: composition, weight, strength, safety, chemical properties, price, demand, CO2. The response has no such fields (extra fields fail validation, 5.2). The client shows every item of `result` under the label "Предложение ИИ" (kind "Suggested" in `design/ai-results.md`) and the permanent S06 notice; only fields in the material's confirmed set are shown as "Подтверждено".

### 11.5 Retries and rate limit

Server-side, temporary errors only (timeout, provider 429, provider 5xx, connection error). Numbers are assumptions (A-AI-2):
- At most 3 attempts per analysis (1 + 2 retries), backoff 1 s then 3 s with random jitter up to 0.5 s.
- Per-call timeout `VISION_TIMEOUT_SECONDS`, default 20 s; whole-job deadline 75 s from start (fits the 90 s client ceiling). If the deadline is hit, the job ends `failed` / `PROVIDER_TIMEOUT`.
- A provider `Retry-After` longer than the remaining deadline ends the job as `failed` / `PROVIDER_RATE_LIMITED` without waiting.
- Not retried: `PROVIDER_AUTH_ERROR`, `PROVIDER_REFUSED`, `INVALID_PROVIDER_RESPONSE` (one re-ask is allowed by 5.6 and counts as an attempt), `IMAGE_UNAVAILABLE`.
- Concurrency: process-wide semaphore, 2 concurrent provider calls (A-AI-3); further jobs stay `pending`.

Client side:
- "Повторить анализ" calls `POST /ai/analyze` again and receives a new `analysis_id`. Shown only when the latest analysis is terminal and either `failed` with `PROVIDER_TIMEOUT`, `PROVIDER_UNAVAILABLE`, `PROVIDER_RATE_LIMITED`, `INVALID_PROVIDER_RESPONSE`, `IMAGE_UNAVAILABLE`, `INTERNAL_ERROR`, or `interrupted` (server fault, nothing for the user to fix). Not shown for `PROVIDER_AUTH_ERROR` and `PROVIDER_REFUSED` (retrying does not help; show the message and suggest manual entry).
- The button is disabled while the request is in flight (no double submit) and while a `pending`/`running` job exists.
- The client does not retry automatically and does not loop. After 3 consecutive failed manual attempts for the same `input_version` the client shows "Продолжите вручную" and keeps the button available but secondary (A-AI-4).
- Rate limit: `POST /ai/analyze` returns `429 RATE_LIMITED` with header `Retry-After: <seconds>` and `details.retry_after_seconds` (same format as api.md 18.9 Q3). Assumed limit: 6 analyses per user per 10 minutes and 30 per organization per day (A-AI-5; configuration, not contract). Client disables the button for `retry_after_seconds` and shows a countdown.

### 11.6 error_code for analysis (9 codes, maximum 12)

Wire format is UPPER_SNAKE (as in api.md 17.9). `error_code` is non-null only for `failed` / `interrupted`. The text is what the client shows; it never contains provider output, a request id of the provider, a key, a URL or a contact. The client chooses the text by code and ignores any other text.

| `error_code` | Status | Client text (RU) |
| --- | --- | --- |
| `PROVIDER_TIMEOUT` | failed | Сервис анализа не ответил вовремя. Попробуйте ещё раз или заполните данные вручную. |
| `PROVIDER_UNAVAILABLE` | failed | Сервис анализа временно недоступен. Вы можете продолжить вручную. |
| `PROVIDER_RATE_LIMITED` | failed | Сервис анализа перегружен. Повторите позже. |
| `PROVIDER_AUTH_ERROR` | failed | Анализ сейчас не настроен. Заполните характеристики вручную. |
| `PROVIDER_REFUSED` | failed | Сервис не смог проанализировать это фото. Заполните данные вручную или загрузите другое фото. |
| `INVALID_PROVIDER_RESPONSE` | failed | Ответ анализа не прошёл проверку и не сохранён. Повторите или продолжите вручную. |
| `IMAGE_UNAVAILABLE` | failed | Не удалось прочитать фото партии. Проверьте фото и повторите. |
| `INTERRUPTED` | interrupted | Анализ прерван. Запустите заново. |
| `INTERNAL_ERROR` | failed | Не удалось выполнить анализ. Повторите позже или продолжите вручную. |

Mapping from sections 3/5: `invalid_json` and `schema_violation` both become `INVALID_PROVIDER_RESPONSE` on the wire (the client needs no distinction; the internal reason is kept in logs only); `interrupted_restart` becomes `INTERRUPTED`; `no_images` is not an analysis code, it is the `409 NO_IMAGES` of `POST /ai/analyze`. `PROVIDER_AUTH_ERROR` and `PROVIDER_REFUSED` text deliberately does not blame the user or reveal configuration details. Unknown code: client shows the `INTERNAL_ERROR` text.

### 11.7 Demo mode and `mode`

- `mode` is mandatory in every `AnalysisOut` (key always present; null until `succeeded`). Values: `live` (real provider), `mock` (mock provider), `fallback` (prepared fixture shown because the live provider could not be used, CLAUDE.md §16).
- The three modes are never mixed: one analysis row has one `mode`; a `mock`/`fallback` result is never written as `live`, and `provider` of a mock result is `"mock"`. A `fallback` result is stored as its own row with `mode = "fallback"`; a live failure is never silently replaced by a mock result inside a `live` row.
- Client: for `mock` and `fallback` show the badge "Демо" and the banner "Демо-режим: результат получен не от реального сервиса ИИ" (for `fallback` add: "резервный пример, не анализ вашего фото"). For `live` no badge; the "Предложение ИИ" label stays always. Demo suggestions are not hidden from "Принять в форму", but they carry the badge into the form hint.
- Server: the mock provider can be selected only with `VISION_PROVIDER=mock` together with `DEMO_MODE=true` (or inside tests). `VISION_PROVIDER=mock` without `DEMO_MODE`, or `DEMO_MODE=true` combined with a real provider and no explicit mock choice, does not turn the mock on. In production (any non-test, non-demo environment) the application refuses to start if `VISION_PROVIDER`, `VISION_MODEL` or `VISION_API_KEY` is missing or the provider is `mock`; there is no silent fallback to mock (CLAUDE.md §13). The `fallback` fixture is available only in `DEMO_MODE` (A-AI-8).
- Health or startup logs state the active mode; the API never returns the key.

### 11.8 What the client gets for the S06 screen

From `GET /ai/analyses/{id}` plus the already known material (`GET /materials/{id}`), the client builds:
1. Header state by 11.3 and badge by 11.7.
2. Block A, suggestions (read-only): color, pattern, apparent texture, each with value, optional description and a confidence chip (`high`/`medium`/`low`); `null` / `unknown` shows "Не определено". Then `reuse_options` (0 to 5) in server order, each with name by `reuse_type`, suitability chip (text plus icon, never colour only) and "Почему: {reason}". An empty list shows "Предложений по применению нет".
3. Fields the human must confirm (Block B, from the material, not from AI): `material_type`, `condition`, `total_kg`, `city` (publish requirements, api.md 18.8) and optionally `composition`, `scrap_size`. AI covers none of the first four; there is no AI field for mass, type or condition at all.
4. Composition marker: composition is never in `result`. If `material.composition` is null the form shows "Состав: неизвестно", valid for confirmation; the client never writes the text "Неизвестно" into the value.
5. `is_current = false` hides Block A suggestions behind "Устарело" and disables "Принять в форму" and confirmation with this `analysis_id`.
6. `notes` is shown as plain text, never as markup. All strings from `result` are plain text, escaped on display.
7. Confirm bar: one action "Подтвердить характеристики" (`version` from the last loaded material, optional `analysis_id` of a `succeeded` and current analysis).

### 11.9 Differences from api.md and the earlier text of this file

Wire status names are NOT changed. Changes required in api.md 17.9 (and mirrored in 10.2); api.md is not edited by this document and must be updated by its owner:
1. `AnalysisOut.result`: replace the preliminary `AnalysisResult` by `VisionModelOutput` (2.1-2.3): `visual_features` become objects with `confidence`; drop `result.material_id`, `result.requires_confirmation` and `result.schema_version` from inside `result`.
2. Add top-level `AnalysisOut.requires_confirmation` (always `true`).
3. `reuse_options[].use` renamed to `reuse_type`; enum values per 2.4 (the api.md `ReuseUse` list is to be aligned with `ReuseType`). `visual_features.texture` renamed to `apparent_texture`.
4. `schema_version` value `"1"` becomes `"1.0"`.
5. `error_code`: set extended from 4 to 9 values (11.6): added `PROVIDER_RATE_LIMITED`, `PROVIDER_AUTH_ERROR`, `PROVIDER_REFUSED`, `IMAGE_UNAVAILABLE`, `INTERNAL_ERROR`; `INVALID_PROVIDER_RESPONSE` and `INTERRUPTED` and the two provider codes are kept. Replaces A17-12.
6. `POST /ai/analyze`: documented 202 for a repeat call with an existing active job (A-AI-6); 409 reason `NO_IMAGES` unchanged; `images` and `input_version` are not request fields.
7. `mode` stays as in A17-11; the `fallback` definition becomes final (11.7).
8. Not changed: `analysis_id`/`status`/`input_version` of the 202 body, `Location`, `GET` field names `id`, `is_current`, `provider`, `model`, `confirmed_*`, confirm body.

In this file: the lowercase `AnalysisErrorCode` list in section 3 is superseded for the wire by 11.6 (the internal reasons may stay as log values); `is_mock` in section 3 is superseded by `mode` (mock means `mode` is `mock` or `fallback`); `is_stale` is called `is_current` with inverted meaning on the wire; field `id` is used instead of `analysis_id` in `GET`.

### 11.10 Assumptions

- A-AI-1: `stale_analysis` is the logical name; on the wire it is `409 PRECONDITION_FAILED` with `details.reason = "ANALYSIS_STALE"`.
- A-AI-2: server retries: 3 attempts in total, backoff 1 s and 3 s plus jitter, per-call timeout 20 s by default, job deadline 75 s.
- A-AI-3: 2 concurrent provider calls per process.
- A-AI-4: after 3 failed manual attempts for one `input_version` the client suggests manual entry; the button is not blocked.
- A-AI-5: rate limit 6 analyses per user per 10 minutes, 30 per organization per day; configuration values.
- A-AI-6: a repeat `POST /ai/analyze` while a `pending`/`running` job for the same `input_version` exists returns 202 with the existing `analysis_id`.
- A-AI-7: no background watchdog; stuck jobs are closed only by the job deadline or at the next application start (D-07, not a reliable queue).
- A-AI-8: the `fallback` fixture exists only in `DEMO_MODE` and is a prepared example, not an analysis of the user's photo.
- A-AI-9: client polling is 2 s with a 90 s ceiling (A17-2 reused, not new).
- A-AI-10: the maximum of 5 `reuse_options` is the CON-02 value (2.3).
- Provider and model are not chosen; BLK-02 is open. Nothing in this section assumes a specific provider's behaviour, and nothing here has been checked against a live provider.

## 12. Provider-independent interface (client side, Phase 3)

Status: contract only, nothing implemented. Date: 2026-11-07. Owner: ai-engineer. Sections 1-11 are unchanged. This section describes the mobile client's abstraction, not the backend provider adapter (section 8 and `backend/app/ai/`).

### 12.1 AnalysisProvider

The client talks to analysis through one abstract interface, so screens do not know whether the data comes from the API or from the offline fixture.

```
AnalysisProvider
  start(material_id)   -> { analysis_id, status, input_version }
  status(analysis_id)  -> AnalysisOut            (shape: 11.2)
  confirm(material_id, version, analysis_id?)   -> Material   (client side of POST /materials/{id}/confirm)
```

Rules:
- `start` and `status` return data only; they never change the material.
- `confirm` is the client call that sends the human's confirmation. The provider has no authority to confirm: it forwards a user action and nothing else. No provider method is called automatically after `status` returns `succeeded`, and no provider copies `result` into material fields (6, 11.4).
- Any provider returns the same `AnalysisOut` shape, including `requires_confirmation = true`.
- The interface carries no images, object keys or URLs from the client (11.1).

### 12.2 Two providers

| Provider | Source | Used when |
| --- | --- | --- |
| `api` | `POST /ai/analyze`, `GET /ai/analyses/{id}`, `POST /materials/{id}/confirm` | default |
| `demo` | `docs/fixtures/demo-analysis.json` bundled with the app; no network | only when `USE_DEMO_DATA=true` |

- `demo.start` returns a local `analysis_id` and `status = pending`; `demo.status` returns `running` once, then the fixture with `status = succeeded` (a short fixed delay is allowed so the states are visible). The fixture's `material_id` is replaced by the current material id on the client; `result` is not modified.
- `demo.confirm` makes no network call and does not change server data. In demo mode the confirmation is local and the screen says so (12.3). It is not possible to confirm a real server material with a demo `analysis_id`: the `api` provider rejects unknown ids with 404/409, and the client does not send a demo id to the server.
- The demo fixture is synthetic and carries `_note`. The client ignores keys it does not know, including `_note`, but the screen shows its own demo label.

### 12.3 Rule for `mode`

Wire values from 11.2 are `live`, `mock`, `fallback`. The client adds a fourth, client-only value:

| `mode` | Origin | Label on screen |
| --- | --- | --- |
| `live` | `api` provider, real vision provider | no badge; "Предложение ИИ" stays |
| `mock` | `api` provider, server mock (tests / server `DEMO_MODE`) | badge "Демо" + banner (11.7) |
| `fallback` | `api` provider, server prepared example | badge "Демо" + banner "резервный пример, не анализ вашего фото" (11.7) |
| `demo` | `demo` provider, local fixture | badge "Демо" + banner "Демо-режим: офлайн-пример, не анализ вашего фото" |

Rules:
1. `demo` is produced only by the `demo` provider. The `api` provider never returns `demo` and the server never sends it; if the server sent `demo` or an unknown `mode`, the client treats it as not `live` (shows the "Демо" badge).
2. The client never shows `mock`, `fallback` or `demo` as `live`. It never shows a result without a mode label when `mode` is not `live`. A result with `mode = null` and `status = succeeded` is treated as not `live`.
3. The client never converts `demo` into `live`, and never uses a demo result in place of a failed live call without the user seeing the demo label. A live failure shows the failure (11.6), not a silent demo result.
4. `demo` is enabled only by the build/run setting `USE_DEMO_DATA=true`. It is not enabled by an error, by a missing network, by the server's `DEMO_MODE`, or by a user toggle in production. Without `USE_DEMO_DATA=true` the `demo` provider is not registered at all.
5. Demo suggestions follow 11.8; "Принять в форму" carries the demo badge into the form hint. Demo output does not change what is "Подтверждено".

### 12.4 Client states and mapping

Client display states: `pending`, `processing`, `completed`, `failed`. This restates 11.3 for the provider layer; wire names stay unchanged.

| Wire `status` | Client state |
| --- | --- |
| `pending` | pending |
| `running` | processing |
| `succeeded` | completed |
| `failed` | failed |
| `interrupted` | failed |
| unknown value | failed |

- `interrupted` is mapped to `failed` for display, but the client keeps the original wire value and `error_code = INTERRUPTED` to choose the text.
- `completed` shows suggestions only if `is_current` is true; otherwise "Устарело" (11.8).
- The `demo` provider uses the same wire names internally, so the mapping function is shared and has one test.

### 12.5 Assumptions A-AI-demo-n

All are assumptions made by ai-engineer for the offline demo. None has been confirmed by the product owner or checked against a device.

- A-AI-demo-1 (assumption): the new `mode = "demo"` is client-only and is not added to the wire enum (`live`/`mock`/`fallback`). If the backend owner prefers one shared enum, api.md 17.9 must be updated by its owner; this document does not edit api.md.
- A-AI-demo-2 (assumption): `USE_DEMO_DATA` is a client build/run flag (for example `--dart-define`), separate from the server `DEMO_MODE`. Setting one does not set the other.
- A-AI-demo-3 (assumption): the fixture keeps `composition = "unknown"` as a top-level key next to `result`, because `result` is `extra="forbid"` and has no composition field (1, 2.1). The client reads it only to show "Состав: неизвестно" and never writes it into the material.
- A-AI-demo-4 (assumption): fixture UUIDs and timestamps are placeholders (`00000000-...`, `2026-01-01T00:00:00Z`); the client substitutes the current `material_id`.
- A-AI-demo-5 (assumption): the fixture has `schema_version = "1.0"`, `input_version = 1`, `is_current = true`. In demo, `is_current` is not recomputed against a server material version.
- A-AI-demo-6 (assumption): the fixture contains four `reuse_options` (limit 5) with `reuse_type` values from `ReuseType`; the values are plausible for a cotton knit offcut but are invented, not measured, and the file says so in `_note`.
- A-AI-demo-7 (assumption): the delay in `demo.status` (one `running` response) is a client display choice and has no meaning for real analysis time.
- A-AI-demo-8 (assumption): the fixture is shipped inside the app bundle (asset), so the offline demo works without a network. Registering the asset is done by flutter-developer.
