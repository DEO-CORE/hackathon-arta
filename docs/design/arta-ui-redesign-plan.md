# ARTA UI redesign plan (reference-driven)

Status: draft for approval. Owner: ux-designer. Implementer: frontend-engineer. UI copy is Russian, identifiers English.

Inputs: `reference-analysis.md` (approved), screenshots `before/` (01-06) and `after/` (01-05) in the session scratchpad, `frontend/lib/app/theme.dart`, `frontend/lib/core/theme/app_tokens.dart`, `frontend/lib/core/ui/`, `frontend/lib/app/router.dart`, `frontend/test/`.
Not duplicated here: tokens and component rules already in `visual-system.md`, `visual-screens.md`, `visual-audit-2026-11-07.md`. This plan changes the visual language on top of them; where it contradicts them, it wins (listed in 4.9).
No code, API or backend is changed by this document. No new endpoints are needed.

## 0. Approved decisions (fixed, not reopened)

- Logo: text wordmark "ARTA" only. No logo file, no mascot.
- Login: email + password. No OTP code step, no social buttons.
- Bottom navigation: icon plus visible text label on every item.
- Accent: `#F08331`. Text on orange fills: `#17191D`. Links and orange text on light surfaces: `#B04A00`. The lime of the references is not used.

## 1. Reference analysis (short)

Full text: `reference-analysis.md`. Ten repeating patterns, used here by number:

1. Soft gradient background, translucent large-radius surfaces, depth by tint, almost no shadows.
2. Very large radii; pill controls; rounded-square icon buttons.
3. Neutral palette plus one action colour; pastel status pills with text.
4. Two-tone headlines (black + grey); big number with a small unit.
5. Floating bottom nav, distinct active tile; top bar without a background, back left, menu right, centred small title.
6. Bottom sheets with a drag handle; key-value rows with hairlines; primary + secondary pill pair.
7. Confirmation as a screen: check circle, heading, one line, summary, next actions; progress as bar + count + checklist.
8. Low density, photo-led cards, primary action pinned at the bottom and disabled until valid.
9. Non-colour markers: hatch for "remaining/free/not yet", solid for done; corner dot badges.
10. Stat triplet of labelled pills under a section title with a "Все" link.

Limits that apply to this plan: references are phone-only (no laptop layout); two screenshots were analysed from copies; colours there are estimated by eye; grey-on-grey contrast in references looks low and is not copied.

## 2. Audit of the current UI

Current state (from `after/` screenshots and theme.dart): neutral `#F7F8FA` page, white cards with 1 px border, 12 dp radius, 52 dp full-width orange button with dark text, white app bar with bottom border and shadow-free surface, floating-label outlined fields, extended FAB on the catalog, pinned bottom bar on detail. The previous refinement removed the dead zones and the orange-text contrast failures. What remains is mostly the gap to the references. Priority: P0 = visible on the demo path or accessibility risk, P1 = hierarchy and consistency, P2 = polish.

| Screen | Does not match references | Priority |
| --- | --- | --- |
| Login | Wordmark and title are left-aligned plain text with a flat background (no gradient, no brand moment, patterns 1, 4). Fields are 12 dp-radius outlined boxes with floating labels, not pills with a persistent label above and leading icon (pattern 2, registration reference). Button is 12 dp, not a pill. Demo-credentials card sits in the form flow. Disabled state of the button is not shown until valid. | P1 (demo-credentials placement P0 for demo clarity: it must stay visible and labelled) |
| Registration | Same as login. Role selection (enterprise / buyer / recycler) has no reference; needs a pill segmented control with text labels. | P1 |
| Home / dashboard | A heading with email, a role line, one button and a plain list "Разделы". No greeting, no priority card, no stat plates, white app bar with a logout icon (patterns 4, 5, 8, 10). No analytics API in this phase: the screen must not show zeros or invented metrics. | P0 (the main screen of the demo; first impression) |
| Catalog | White app bar with back arrow; filter chips are rectangular; cards are horizontal list rows with a small thumbnail and five text lines (about 145 dp). References use large photo cards with an overlay panel and an "open" arrow; FAB duplicates the nav's job. | P0 (catalog is the second demo step) |
| Batch card (detail) | Title and badge on a flat page; sections as stacked white boxes ("Характеристики", "Масса, кг") that are not full width and have uneven widths in the screenshot (`05_detail_draft.png`: boxes shrink to content); no photo hero; mass shown as four text lines instead of a stat triplet (pattern 10); checklist uses empty circles without progress or count (pattern 7); primary action competes with "Изменить". | P0 |
| Create | Long column of outlined boxes with floating labels; photo section is a text block plus a small outlined button, no photo tiles with drop zone look; no visible progress toward publish readiness. Pinned primary button is OK. | P0 |
| Edit | Same form as create (shared `MaterialFormFields`); additionally must show the version-conflict and lifecycle errors without redesign of their logic. | P1 |
| Publish / archive | Actions live as buttons on detail; confirmation uses a system dialog with a 16 dp radius. References use a sheet or a success screen (patterns 6, 7). No success state after publish. | P1 |
| AI analysis | Cards `_FeatureCard`, `_ReuseCard`, `_Plate`, `_HumanBlock`: boxes with equal weight. Needs a recommendation card where "ИИ предлагает" and "Подтверждено вами" are separate blocks (rules in `ai-results.md`), a non-colour marker for suggested values, and pending/failed/stale states as pills with text. | P0 (confirmation is a core safety step) |
| Organization (profile) | Plain form; no centred identity header, no link cards (pattern in "success and other" right phone). | P1 |
| Global | App bar with fill and border on every screen; demo banner is a dark full-width band at the very top. | P1 |

## 3. Visual differences: reference, ARTA, decision

| Reference (pattern) | ARTA now | Decision |
| --- | --- | --- |
| Gradient background (1) | Flat `#F7F8FA` | Base `#F7F8FA` plus a soft `primaryContainer` (`#FFF1E6`) wash from the top-right, fading out in the first third. Both colours already exist as tokens; the gradient itself is new. No lime. Light mode only. |
| Top bar without background, rounded-square icon buttons (5) | White bar with border | Transparent app bar, 48 dp rounded-square icon buttons (radius 16) for back / close / logout, centred 17-18 sp title on inner screens. No title on home (greeting instead). |
| Floating nav, icon-only (5) | None; section list on home | Floating pill with 3 items, each icon + label (approved). See 4.2. |
| Dark nav variant with dot badge (5) | n/a | Not used: one light nav. Dot badge is not used until a count exists to show (no requests screen yet). |
| Pill buttons, primary + secondary pair (2, 6) | 12 dp radius | Pills, 52 dp, orange fill with `#17191D` text; secondary on `surfaceSunken`. Pair side by side only when both fit; otherwise stacked. |
| Pill inputs with leading icon and label above (2) | Outlined, floating label | Pill (radius 999 for single-line) with persistent label above, helper below, focus border 2 px `focusRing`. Multi-line and dropdown fields use radius 20. Control border stays `controlBorder` (3:1), not the faint border of the references. |
| Two-tone headline (4) | Single tone | Greeting and section titles: first phrase `text`, second `textSecondary`. Only for headings, never for values. |
| Big metric with small unit (4) | Text line "Свободно: 45 кг" | 40-48 sp number, 14-16 sp unit baseline-aligned (see 4.1). Only for registered mass values already in the API. |
| Photo cards with frosted overlay and arrow button (3, 8) | Thumbnail list row | Full-width photo card, radius 28, overlay panel at the bottom with title, type · city, free kg and an "open" arrow tile. Overlay is a 92% opaque white fill, not a blur (assumption A2, see open question for engineer in 9 - not a customer question). |
| Stacked priority card (home) | None | One priority card on home. Content is chosen from data the app already has (for example "N черновиков без подтверждения"). If none, the card is not shown. Stacked-edge decoration is not copied. |
| Status pills with text (3) | `AppStatusBadge` already icon + text | Keep, restyle to pastel pills (4.1). |
| Stat triplet (10) | Text list | Three plates: Свободно / Зарезервировано / Передано (4.1). |
| Progress bar + count + checklist (7) | Checklist with empty circles | Hatched progress bar, "N из 6" chip, rows with check tile and "Изменить" link. |
| Success screen (7) | None | Used after publish and after confirm characteristics (D phase). Never mentions payment. |
| Bottom sheet with handle (6) | AlertDialog | Sheet for confirm of publish/archive and filters; AlertDialog stays for destructive confirmation (4.7). |
| Disabled grey button with white text (8) | Button enabled, errors on submit | Disabled until valid is allowed only where the reason is shown in helper text; disabled style uses `surfaceSunken` + `textSecondary` (not white on grey, whose contrast looks low in the references). |
| Social buttons, OTP boxes, ratings, calendar (not applicable) | n/a | Not used. |
| Cut-out portrait with fading (extra-2) | n/a | Not used: materials have rectangular photos; no cut-out processing. |
| Frosted/translucent surfaces (1) | n/a | Semi-opaque fills only; no `BackdropFilter` on lists or nav until measured on Flutter web. |

## 4. Proposed design system

All colours reuse `AppColors` unless marked NEW. A value marked "unverified" has not been checked with a contrast tool: no tool is available in this environment, so the ratios below are hand-calculated with the WCAG 2.1 formula (the `#B04A00` figures come from `visual-audit-2026-11-07.md`) and must be re-run with a tool before approval. A tool result overrides this file.

### 4.1 Tokens

Colour roles and pairs

| Role | Foreground / background | Hand-calculated ratio | Status |
| --- | --- | --- | --- |
| Body text | `text #17191D` on `background #F7F8FA` / `surface #FFFFFF` | not recalculated (very high) | unverified |
| Secondary text | `textSecondary #5B6270` on `#F7F8FA` | about 5.8 | unverified; not tested on the gradient wash or on `surfaceSunken` |
| Text on orange | `onPrimary #17191D` on `primary #F08331` | about 6.7 | unverified |
| Link / orange text | `linkText #B04A00` on `#FFFFFF` | 5.49 (audit) | unverified |
| Link on page | `#B04A00` on `#F7F8FA` | 5.17 (audit) | unverified |
| Control border | `controlBorder #7F8691` on `#FFFFFF` | 3.67 (audit), needs 3.0 | unverified |
| Orange as a fill on white (non-text) | `primary` vs `surface` | about 2.5 (audit) | fails 3:1: orange must never be the only boundary or the only carrier of meaning; it needs a text label or a dark outline |
| Disabled button | `textSecondary` on `surfaceSunken #EEF0F3` | not calculated | unverified; needed (readable disabled text is a design choice, WCAG exempts disabled) |
| Overlay panel text | `text` on 92% white over a photo | depends on the photo | cannot be guaranteed; panel opacity must stay opaque enough: verify on light and dark sample photos |
| Pastel status pills | existing `*Bg` / `*` pairs | per `visual-system.md` 2.2 | unverified |

New tokens (proposal, names only; values follow existing colours): `backgroundWash` (the `primaryContainer` wash at the top of the gradient), `navSurface` (white, 94% alpha), `overlaySurface` (white, 92% alpha), `hatch` (diagonal 45 degree stripes, 1.5 dp line, 6 dp period, colour `neutral` at 40% on the pill fill). Value kinds already in the system stay: forecast, demo, confirmed, suggested (`suggested #3B4BA0` on `suggestedBg #E6E9F8`), with text labels "ожидается", "демо", "подтверждено", "предложено ИИ".

Typography (Roboto, already in use; Cyrillic is supported): display 36/44 (greeting 32-36 on phone), metric 44/52 (NEW, medium) with unit 16/24 `textSecondary`, headline 24/32, headlineSmall 20/28 (section), screen title 17/24 (NEW, medium), title 16/24, body 16/24, label 14/20, caption 12/16. Hierarchy comes from size and black/grey tone, not many weights (regular, medium; bold only for the wordmark). Font change toward a neo-grotesque is not needed for MVP.

Spacing (4 dp grid): page side padding 20 (phone), 24 (tablet+); card inner 20; gap between blocks 24; gap in lists 12. Content max width 560 on phone/tablet columns; laptop: see 4.2.

Radius: card 28, list/link card 20, sheet top 28, icon button 16 (48 dp square), pill 999 (buttons, chips, single-line inputs, badges, nav), dialog 20, photo thumbnail 16.

Elevation: none by default (separation by tint and 1 px `border`). Floating nav and sheets only: `level2`. FAB is removed from the catalog.

Touch and focus: minimum 48 x 48 dp (nav items 56 high including label); focus ring 2 px `focusRing` on every interactive element, visible on the pill shape; decorations do not take focus.

Motion (durations proposed, not measured): tap feedback 100 ms, sheet slide-up 250 ms ease-out, success check fade 200 ms, tab switch 150 ms cross-fade, progress bar fill 300 ms. All animation disabled when `MediaQuery.disableAnimations` is true. No infinite animations other than the existing skeleton (see risk R5).

Values format (kept from `visual-system.md` 3.5): comma decimal, no trailing zeros, units always shown ("45 кг", "KGS").

### 4.2 Navigation and app bar

- App bar: transparent, no border; leading rounded-square back/close tile; centred title; trailing optional tile. Status-bar and demo-banner safe-area handling unchanged.
- Floating bottom nav (phone width below 600 dp): pill, 3 items, each icon above a 12 sp label, active item has a white rounded-square tile, filled icon and `text` label; inactive items have outline icons and `textSecondary` labels. Active state is also exposed to screen readers ("выбрано"). Items by role:
  - enterprise: Главная (`/`), Партии (`/materials`), Организация (`/organization`).
  - buyer / recycler: Главная (`/`), Каталог (`/materials`), Организация (`/organization`).
  - No tab for screens that do not exist yet (matching, plan, requests, analytics). They are added when the screens exist. This removes the need for a fourth, dead item.
- Create batch is an action on Главная and in the page header of Партии ("+" tile with label "Создать"), not a nav item and not a FAB.
- Nav is shown on `/`, `/materials`, `/organization`. It is hidden on `/login`, `/register`, `/materials/new`, `/materials/:id`, `/materials/:id/edit`, `/materials/:id/analysis`, where a pinned primary action takes the bottom edge. Scroll content gets bottom padding equal to nav height + safe area so nothing is covered.
- Laptop (600 dp and wider): the floating pill is replaced by a left rail (icon + label, 72-88 dp) or a top row; the references do not show a laptop layout, so this is a design extension, listed in section 9 only if the customer wants a different pattern. Default: left rail with the same three items and the same active tile.

### 4.3 Components

| Component | Spec |
| --- | --- |
| `AppTopBar` | See 4.2. Replaces `AppBar` in theme and screens. |
| `AppFloatingNav` | See 4.2. Items: icon, label, route, optional badge count (unused now). Semantics: role tab, selected state, label. |
| `AppButton` (primary / secondary / text / destructive) | Pill, 52 dp full-width / 48 dp inline. Primary: `primary` fill, `onPrimary` text, optional leading icon. Secondary: `surfaceSunken` fill, `text`. Text: `linkText`. Destructive: `error` fill, white text. Existing `loading` blocks double submit and keeps its labelled spinner. Public API of `AppButton` is unchanged. |
| `AppTextField` | Persistent label above, optional leading icon, pill / radius-20, helper and error below, error uses icon + text (not colour only). Public API unchanged; leading icon and label placement are internal. Keeps autofill hints and `textInputAction`. |
| `MaterialPhotoCard` (catalog) | Photo fills the card (4:3), radius 28; no photo: `surfaceSunken` with icon and "Нет фото"; overlay panel with title, "Тип · Город", "Свободно N кг" and an arrow tile. Status pill top-left on the photo with its own opaque fill. The whole card is one tap target with a combined semantics label. |
| `AppStatPlate` and `AppStatTriplet` | Three plates in one row: "Свободно", "Зарезервировано", "Передано"; number (medium) with unit inside each plate; labels above numbers. Fill: Свободно solid `successBg`, Зарезервировано `surface`, Передано hatched. Widths: equal by default; proportional to value only if values are real and a zero plate still has a minimum width and its label. Plate values come from `available_kg`, `held_kg`, `transferred_kg` as already shown in `_Balance`; "Всего" is shown as a caption line "Всего N кг". Hatch is never used for a confirmed fact. On phones narrower than 360 dp the triplet becomes three stacked rows. |
| `AppStatusBadge` / `MaterialStatusChip` | Pastel pill, icon + text, six material statuses unchanged. Text is the carrier, colour is secondary. |
| `AppPhotoTile` / `AppPhotoUpload` | Grid of 3 columns on phone (radius 16); first tile "Добавить фото" with dashed outline, camera icon and label; each photo tile has a 48 dp remove control with an accessible name; counter "N из 5"; limits text ("JPEG, PNG, WebP, до 10 МБ") below; per-tile states: uploading (progress and label), failed (retry), done. Demo note "фото сохраняется только на этом устройстве" stays. |
| `AiSuggestionCard` | Header "Предложено ИИ" pill (`suggested` pair) with the reason line under each item; separate section "Подтверждено вами" with the `success` pair and author/date; fixed notice that AI does not determine composition, weight, strength or safety. Items: feature or reuse option, suitability as text ("высокая / средняя / низкая / неизвестно"), reason. Confirm action is a primary button at the end, disabled while pending/failed/stale; the server validates `input_version` regardless of the button. Details in `ai-results.md`. |
| `AppBottomSheet` | Drag handle, radius 28, grey `surfaceSunken` body, title 22, close tile; used for confirm of publish/archive and for catalog filters. Keyboard: Esc closes; focus returns to the trigger. |
| `AppConfirmDialog` | Kept for destructive confirmation (archive with consequences); restyled radius 20, pill buttons; API unchanged. |
| `AppSuccessView` | Check circle (`success`), heading, one-line explanation, key-value summary rows with hairlines, primary + secondary pill pair. Text-only meaning (check circle has a text label). No payment wording. |
| `AppProgressChecklist` | Hatched progress bar (solid = done, hatch = remaining) + "N из 6" chip + rows (check tile or empty tile, title, grey sub-line, "Изменить" link). Items come from `publish_requirements.dart`. Done/not-done is shown by icon and text ("выполнено" / "не выполнено") for screen readers. |
| `AppKeyValueRow` | Label left, value right-aligned, hairline divider; secondary detail in `textSecondary`. |
| `AppLinkCard` | Icon tile + title + grey sub-line + arrow-up-right; radius 20; used on Организация and home. |
| `AppEmptyState` / `AppErrorState` / `AppSkeleton` | Keep API. Restyle: icon in a rounded tile, heading, one line, one action; error shows `code`/`request_id` text unchanged; skeletons use card radius 28/20. Existing error texts are not rewritten. |
| `DemoBanner` | Keeps full-width visibility; restyled as a `value-demo` pill/strip with the same text "Демо: синтетические данные, не реальные". It stays above the nav and the gradient. It is never removed or collapsed by the redesign. |

### 4.4 Screen layouts, phone and laptop

- Phone: one column, 20 dp side padding, gradient background, floating nav, pinned primary actions on forms and detail.
- Laptop (600 dp and wider): content column max 560 dp (forms) or 960 dp two columns for catalog (photo cards in a 2-3 column grid) and detail (left: photo and plates, right: characteristics and checklist); left rail instead of the floating nav; primary action stays in a sticky bottom area of the content column.

### 4.5 States (all screens)

Loading (skeleton, existing `AppSkeletonList`), empty (`AppEmptyState`), error (`AppErrorState`, existing messages), success (`AppSuccessView` or inline confirmation), 409 conflict (existing lifecycle error handling, text unchanged), permission denied, AI pending / failed / unavailable / stale (in `ai-results.md`). Each state keeps the nav visible on tab screens.

### 4.6 What is not shown

Ratings, CO2, revenue, prices and demand values are never mocked. Dashboard stat plates appear only for values the API returns. Forecast and demo values carry their labels.

### 4.7 Dialog vs sheet rule

Sheet: choose / review / filter / non-destructive confirm. Dialog: destructive or irreversible. Both close on Esc and return focus.

### 4.8 Assumptions in this plan

- A1. A subtle gradient does not reduce legibility of text on pages; checked only by eye, must be measured (section 7, phase F).
- A2. No `BackdropFilter`; frosted look is a semi-opaque fill.
- A3. Hatch can be drawn with a `CustomPainter` without images; performance on web not measured.
- A4. Proportional plate widths are optional.

### 4.9 Supersedes in older specs

`visual-system.md` 9.4 / 5.11 ("no bottom navigation"): replaced by 4.2 of this plan. `visual-system.md` radius 12 for buttons and inputs: replaced by pills. Card border 1 px stays. Everything else in the older specs stays.

## 5. Screen decomposition (what changes, what stays)

Common to all rows: routes, `authRedirect` guard, providers, repository calls, validation and error texts, demo-mode switch and fixtures, `AutofillGroup` hints, `autofocus`, `dispose` of controllers, double-submit blocking by `AppButton.loading` stay as they are. Server enforces every rule; the UI only reflects it.

| Screen / file | Changes | Stays |
| --- | --- | --- |
| Theme (`app/theme.dart`, `core/theme/app_tokens.dart`) | Radius scale, pill button shapes, transparent app bar theme, input theme (pill, label above), card radius 28, nav/overlay/hatch tokens, gradient background builder | Existing colour tokens and names (aliases kept so imports do not break), `buildTheme()` signature, `brandPrimary` |
| Shell (new `AppShell` wrapper; `core/ui/`) | Gradient background; floating nav / left rail; used by `/`, `/materials`, `/organization` | `go_router` route table in `router.dart` is unchanged in phase C; nav calls `context.go`; no `ShellRoute` until tests are checked (R2) |
| Login (`login_screen.dart`) | Gradient, centred wordmark block (`AppBrandBlock` restyled), pill fields with leading icon and persistent label, pill button, demo block as a labelled card below the register link | Texts, validation, error handling, "Заполнить", autofill, loading, redirect on success |
| Register (`register_screen.dart`) | Same as login; role as a pill segmented control with text ("Предприятие", "Мастерская", "Переработчик") bound to the existing role value | Fields, validators (`auth_validators.dart`), request payload |
| Home (`home_screen.dart`) | Two-tone greeting using organisation name (from `organizationProvider` if already loaded, else email; no new call), one priority card when data exists, link cards "Партии" / "Организация", primary "Создать партию" (enterprise) or "Открыть каталог" (buyer), stat triplet only when API data exists, logout moves to Организация as a labelled button (and keeps the tile on the top bar) | Role logic, `signOut`, routes |
| Catalog (`catalog_screen.dart`) | Photo cards, pill filter chips (`ChoiceChip` replaced by a pill chip widget keeping text and selected state), header with title and "Создать" tile (enterprise), FAB removed, list bottom padding for nav | Filter logic, pagination, empty and error states and their copy, role-based hiding of "Создать партию" |
| Batch card (`material_detail_screen.dart`) | Photo hero (first photo or placeholder), two-tone title, badge, stat triplet replacing `_Balance`, characteristics as `AppKeyValueRow` list, publish checklist as `AppProgressChecklist`, bottom sheet for publish/archive confirm, success view after publish/confirm | Lifecycle logic, `LifecycleErrorView` messages, 409 handling, role checks, button labels "Подтвердить характеристики", "Опубликовать", "Архивировать", "Изменить" |
| Create (`material_create_screen.dart`, `material_form_fields.dart`, `material_form_model.dart`) | Pill fields with label above, sections ("Основное", "Размеры и состав", "Цена", "Фото"), `AppPhotoUpload`, publish-readiness bar at the top | Form model, validators, partial-save banner logic (`_PartialBanner`), photo upload sequence, "Сохранить черновик" copy |
| Edit (`material_edit_screen.dart`) | Same field styling and sections as create; shared widget | Version handling, conflict messages, text "Изменить партию" |
| Publish / archive | Move confirmation to `AppBottomSheet` / restyled dialog; add `AppSuccessView` after publish | Same calls, same server checks, same error mapping |
| AI analysis (`analysis_screen.dart`) | Replace `_Plate`, `_FeatureCard`, `_ReuseCard`, `_HumanBlock` visuals with `AiSuggestionCard` and confirmed block; pending/failed/stale as pills; non-colour marker for suggested values | Polling provider, state machine, notice text, "Подтвердить характеристики", stale handling, `LinearProgressIndicator` for pending |
| Organization (`organization_screen.dart`) | Centred identity header, link cards, form in sections, logout button | Form logic, PATCH call, validators |
| Demo (`demo/`, `DemoBanner`, `demo_reset_section`) | Visual restyle only | Behaviour, isolation, fixtures |

## 6. Component list and owners

| Component | Owner (implement) | Reviewer |
| --- | --- | --- |
| Tokens + theme | frontend-engineer | ux-designer |
| `AppTopBar`, `AppFloatingNav`, `AppShell` (left rail on wide) | frontend-engineer | ux-designer, qa |
| `AppButton`, `AppTextField` restyle | frontend-engineer | ux-designer |
| `AppStatPlate`/`AppStatTriplet`, hatch painter | frontend-engineer | ux-designer |
| `MaterialPhotoCard`, `AppPhotoUpload`/`AppPhotoTile` | frontend-engineer | ux-designer, qa |
| `AiSuggestionCard` | frontend-engineer | ux-designer (copy and rules per `ai-results.md`) |
| `AppBottomSheet`, `AppConfirmDialog`, `AppSuccessView`, `AppProgressChecklist`, `AppKeyValueRow`, `AppLinkCard` | frontend-engineer | ux-designer |
| Empty / error / skeleton / `DemoBanner` restyle | frontend-engineer | ux-designer |
| Contrast and touch measurement with a tool; screen-reader pass | qa-engineer | ux-designer |
| Russian copy for new labels (nav, sheets, success) | ux-designer | product owner |
| Test updates (section 8) | frontend-engineer, qa-engineer | qa-engineer |

## 7. Implementation phases

Order is fixed: components first, screens next. Each phase is a small, shippable change that keeps `flutter analyze` and `flutter test` green; criteria are checks, not intentions. A criterion is met only after the command or measurement was actually run.

### Phase B. Design system and components

Work: tokens (radius, nav/overlay/hatch, type 17/44), theme (pill buttons, transparent app bar, pill inputs), `AppTopBar`, `AppFloatingNav`, `AppShell`, `AppStatTriplet`, `AppProgressChecklist`, `AppBottomSheet`, `AppSuccessView`, `AppKeyValueRow`, `AppLinkCard`, `AppPhotoUpload`, `MaterialPhotoCard`, `AiSuggestionCard`; a throwaway preview page is not added to the app (tested through widget tests).
Done when:
1. Each new component has a widget test covering normal, long text (Russian), text scale 200%, disabled and loading states.
2. Contrast of every pair in 4.1 is checked with a tool and recorded; any failing pair is fixed or the pair is removed.
3. `flutter analyze` and the existing `flutter test` pass with no test changed except those listed in section 8.
4. Public APIs of `AppButton`, `AppTextField`, `AppCard`, `AppStatusBadge`, `AppEmptyState`, `AppErrorState`, `AppConfirmDialog` unchanged.

### Phase C. Dashboard and catalog

Work: `AppShell` on `/`, `/materials`, `/organization`; Home redesign; Catalog photo cards, filter pills, header action; FAB removal.
Done when:
1. Nav shows icon + label for 3 items per role; active item is announced as selected; the nav never covers the last list item on a 640 dp-high screen and at text scale 130%.
2. Home shows no metric that the API does not return; no invented numbers.
3. Catalog states (loading, empty, error, role without create button) render; existing catalog and navigation tests pass or are updated per section 8.
4. Routes and `authRedirect` unchanged; router guard test passes unchanged.

### Phase D. Batch card, create, edit

Work: Detail redesign with stat triplet, checklist, bottom sheet, success view; Create and Edit sections; photo upload tiles; AI analysis screen with `AiSuggestionCard`; publish/archive confirmation.
Done when:
1. The demo path create -> photo -> analyse -> confirm -> publish -> archive runs in demo mode in tests and on a device with every button label from section 5 unchanged.
2. Suggested vs confirmed is distinguishable without colour (label text + marker) on the analysis screen; the "AI does not determine composition, weight, strength or safety" notice is visible in every AI state.
3. 409 and lifecycle error views still show their existing messages; double tap on a primary action sends one request (verified in a test).
4. Photo upload shows uploading, failed and done per tile; the remove control has an accessible name.

### Phase E. Login, registration, profile, rest

Work: Login and Register redesign (gradient, pill fields, role control), Organization as link cards, logout placement, demo block restyle, empty/error/skeleton restyle across remaining screens.
Done when:
1. Login/register tests pass (`Войти` tap targets, autofill, loading); keyboard open keeps the primary button visible on a 640 dp-high screen.
2. Role selection is operable by keyboard and has text labels.
3. No screen uses the old rectangular chip, FAB or filled white app bar (search in `lib/`).

### Phase F. Device check and regression

Work: run on a real phone and a laptop browser width; measurements; regression pass; update screenshots in `docs/`.
Done when:
1. Full `flutter analyze`, `dart format`, `flutter test` pass on the final tree (stated with the actual output).
2. Manual run of the demo scenario in `docs/demo.md` steps for this client scope on a device (login -> create with photo -> analyse -> confirm -> publish) with no ellipsis-cut text at 320 dp width and text scale 130%.
3. Contrast, touch targets (>= 48 dp) and focus order measured with tools and recorded; unmeasured items stay marked "not verified".
4. A frame-time check of the gradient, hatch painter and photo cards on the target phone and on Flutter web; if dropped frames are found, the gradient and hatch fall back to flat fills.
5. Screenshots before / after attached.

## 8. Risks to existing functionality and tests

| # | Change | What can break | Tests and checks |
| --- | --- | --- | --- |
| R1 | Theme: radius, pill buttons, transparent app bar | Visual only; `login_screen_test` reads `FilledButton` by type (`find.byType(FilledButton)`): keep `AppButton` primary as `FilledButton` | `login_screen_test`, `dev_defects_test` (AutofillGroup, TextField lookups) |
| R2 | Shell with nav on tab screens | Back stack: home currently opens the catalog with `context.push`, and the catalog has a back arrow. With a nav and `context.go` the back arrow disappears and `Navigator.pop` expectations fail. A `ShellRoute` would also change `go_router` behaviour for `authRedirect` | `material_navigation_test`, `router_guard_test` (pure function, should stay green), `demo_flow_test`. Mitigation: wrapper widget, no route change in phase C |
| R3 | Replace `ChoiceChip` in catalog filter | `material_catalog_test` asserts `find.byType(ChoiceChip)` is nothing for the buyer; filter selection tests may look for `ChoiceChip` | `material_catalog_test` |
| R4 | Move/rename texts ("Удержано" to "Зарезервировано" on plates; "Создать партию" now appears in header and on home) | Tests that use `find.text('Создать партию')`, `find.text('Изменить')` or "Подтвердить характеристики" fail when the same text appears twice or not at all (`findsOneWidget`, `.first`, `.last`) | `material_navigation_test` (uses `.first`), `material_lifecycle_test`, `analysis_screen_test`, `demo_flow_test`. Rule: keep each button label unique per screen; if "Создать партию" is duplicated by header and body, header uses "Создать" |
| R5 | Motion and hatch/gradient painters | `pumpAndSettle` hangs on infinite animations (existing tests call it widely); a looping shimmer or animated hatch would time out | Almost all widget tests. Rule: no infinite animations except what exists now; hatch is static |
| R6 | Photo cards and upload tiles | `MaterialPhoto` loading from signed URLs or demo store; overlay depends on image; layout changes may overflow in tests with default 800x600 surface | `material_create_photo_test`, `material_screens_test`, `demo_isolation_test` |
| R7 | Create/edit form restyle (label above, sections) | `material_form_validation_test` finds fields by label text inside `InputDecorator` (`find.text(label)` ancestor lookup): labels moved out of `InputDecoration` break this lookup | `material_form_validation_test`, `material_edit_test`, `material_create_photo_test` (`find.byType(TextField)`). Mitigation: keep `labelText` in the decoration as the accessible name or update the helper in one place |
| R8 | Lifecycle (publish/archive) moved to sheets | Confirmations tested by tapping a dialog button; sheet changes the widget tree and focus return | `material_lifecycle_test`, `demo_flow_test` |
| R9 | AI card restyle | Existing text assertions (notice, stale, failed) and `LinearProgressIndicator` count | `analysis_screen_test` |
| R10 | Demo banner restyle | Must stay visible on every screen including login; demo isolation | `demo_isolation_test`, `demo_flow_test` |
| R11 | Screen-reader and focus order | New nav and sheets change traversal; not covered by tests | Manual pass in phase F; add semantics assertions where cheap |
| R12 | Gradient and blur-free translucency on web | Performance, legibility of grey text on the wash | Phase F measurement; fallback to flat |

Top three risks for the schedule: R2 (navigation and back stack), R7 (form label tests), R5 (animations versus `pumpAndSettle`).

## 9. Open questions (max 3)

1. Customer: is a laptop layout with a left rail instead of the floating pill acceptable? The references show phone only, so this is a design extension.
2. Customer: may the stat plate say "Зарезервировано" in place of the current copy "Удержано" for the same `held_kg` value? Both mean confirmed reservation; the user-facing word needs to be one.
3. Customer / frontend-engineer: is a second tab on buyer's Home (requests, plan) expected before those screens exist? Default in this plan: no, only existing screens get tabs.

Not customer questions, recorded as dependencies: contrast measurement tool (qa-engineer); frame-time of gradient and hatch on web (frontend-engineer); no API additions are required by this plan, and metrics on Home appear only when `GET /analytics/summary` is integrated (backend-engineer owns that dependency).
