# Visual system: Premium Industrial Tech

Status: draft, proposal for approval. Supersedes the neutral and primary-text values in `tokens.md` sections 2 and 4 (warm neutrals `#FFFBF8`, `#F5EDE6`, `#9A3F00`) because the customer fixed a new palette. Semantic kinds (suggested, confirmed, forecast, fact) and rules from `tokens.md` sections 1 and 6 and from `ai-results.md` stay valid. Mobile first (Flutter, Material 3 as the base, Roboto). UI copy Russian, identifiers English. No API changes. Server enforces every rule; a hidden or disabled button is a convenience.

Fixed by the customer: primary `#F08331`, text `#17191D`, background `#F7F8FA`, surface `#FFFFFF`, border `#E6E8EC`, font Roboto, style minimal B2B SaaS with restrained shadows and strong hierarchy.

## 1. Principles

1. Neutral canvas, one accent. Orange is a fill for the one primary action per screen, a progress fill and a small selected-state accent. Orange is never text.
2. Hierarchy by size and weight, not by colour: title > key value > body > meta.
3. Separate by whitespace and 1 px borders first; shadows are for things that float (bar, FAB, sheet, dialog).
4. Forecast, suggestion, confirmed fact and demo keep their own colour, label, icon and border style (`ai-results.md`). Brand orange never marks them.
5. Skeletons instead of full-screen spinners.

## 2. Colour

Contrast numbers are hand-calculated (formula in `visual-audit-2026-11-07.md` section 9) and must be re-verified by a tool. Pairs carried over from `tokens.md` are marked "carried" (not recalculated here).

### 2.1 Core

| Token | HEX | Role | Pair and ratio |
|---|---|---|---|
| `color-primary` | `#F08331` | Fill of the primary button, FAB, progress fill, selected-step bar | with `on-primary`: 6.70 |
| `color-on-primary` | `#17191D` | Label and icon on primary | 6.70 on primary |
| `color-primary-pressed` | `#D86F1F` | Pressed fill of primary | `#17191D` on it: 5.21 |
| `color-primary-soft` | `#FFF1E6` | Selected chip fill, soft highlight, empty-state icon circle | `#17191D` on it: 15.90; `accent-text` on it: 4.96 |
| `color-accent-text` | `#B04A00` | Links, text buttons, meaningful icons on light backgrounds | white 5.49; `#F7F8FA` 5.17; `primary-soft` 4.96 |
| `color-bg` | `#F7F8FA` | Page background | text 16.56 |
| `color-surface` | `#FFFFFF` | Cards, inputs, bars, dialogs | text 17.60 |
| `color-surface-sunken` | `#EEF0F3` | Photo placeholder, neutral badge fill, info plate | `text-secondary` on it: 5.37 |
| `color-border` | `#E6E8EC` | Card edges, dividers (decorative only: 1.23 on white) | not used for control boundaries |
| `color-border-strong` | `#7F8691` | Input and outlined-button boundary | 3.67 white; 3.45 `#F7F8FA` |
| `color-text` | `#17191D` | Primary text | 17.60 white; 16.56 `#F7F8FA` |
| `color-text-secondary` | `#5B6270` | Meta text, labels of rows | 6.13 white; 5.77 `#F7F8FA` |
| `color-text-tertiary` | `#6B7280` | Placeholder, helper under fields | 4.83 white; 4.55 `#F7F8FA` (smallest allowed margin: do not use on `surface-sunken` for text) |
| `color-text-disabled` | `#9AA0AA` | Disabled label (exempt from WCAG) | never the only explanation |
| `color-disabled-fill` | `#E6E8EC` | Disabled button fill | |
| `color-focus-ring` | `#17191D` | 2 dp ring, 2 dp offset | 17.60 on white |
| `color-scrim` | `#17191D` at 48% | Behind dialogs and sheets | |

### 2.2 Status and semantic

| Token | Foreground | Background | Ratio | Source |
|---|---|---|---|---|
| `status-success` | `#1B6B3A` | `#DDF3E4` | 5.61 (on white 6.54) | recalculated here |
| `status-warning` | `#7A4A00` | `#FFF0CC` | 6.62 | carried |
| `status-error` | `#B3261E` | `#FCE4E1` | on white 6.54; on bg 5.39 carried | white recalculated here |
| `status-neutral` | `#5B6270` | `#EEF0F3` | 5.37 | recalculated here |
| `status-accent` | `#B04A00` | `#FFF1E6` | 4.96 | recalculated here |
| `status-info-suggested` | `#3B4BA0` | `#E6E9F8` | 6.44 | carried |
| `on-error` | `#FFFFFF` | `#B3261E` | 6.54 | recalculated here |

### 2.3 Material statuses (six)

Text plus icon plus pair; colour is secondary. Chip height 28 dp, not interactive.

| API status | Label (RU) | Pair | Border | Icon |
|---|---|---|---|---|
| `draft` | Черновик | `status-neutral` | none | `edit_note` |
| `available` | Доступно | `status-success` | none | `storefront` |
| `partially_allocated` | Частично распределено | `status-accent` | none | `pie_chart` |
| `reserved` | Зарезервировано | `status-accent` | 1 dp `#B04A00` | `lock` |
| `completed` | Завершено | `status-neutral` | 1 dp `#7F8691` | `done_all` |
| `archived` | В архиве | `status-neutral` | none | `archive` |

`draft` and `archived` share a pair and differ by icon and label (as in `phase-2-materials.md`). Amber (`status-warning`) is not used for batch statuses because it is the forecast pair.

### 2.4 Value kinds (AI, forecast, demo)

| Kind | Label (RU) | Pair | Border | Icon |
|---|---|---|---|---|
| Suggested (AI) | Предложение ИИ | `status-info-suggested` | dashed 1 dp `#3B4BA0` | `auto_awesome` |
| Confirmed | Подтверждено + автор и дата | `status-success` | solid 1 dp | `check_circle` |
| Forecast | Ожидается | `status-warning` | dotted 1 dp | `schedule` |
| Fact | Факт | `#17191D` on white | solid 1 dp `#7F8691` | `fiber_manual_record` |
| Demo | Демо | `status-neutral` (changed from warm `#5B5048` on `#EFE6DE` to match the cool neutrals) | 8 dp diagonal-stripe strip on the left edge (decoration) | `science` |
| Stale | Требует повторного подтверждения | `status-warning` | solid 1 dp | `warning` |
| Not confirmed | Не подтверждено | `status-neutral` | solid 1 dp `#7F8691` | `radio_button_unchecked` |
| AI failed | Анализ не удался | `status-error` | solid 1 dp | `error` |
| AI running | Анализ выполняется… | `status-info-suggested` | dashed 1 dp | `auto_awesome` plus linear progress |
| AI unavailable | ИИ недоступен | `status-neutral` | solid 1 dp | `cloud_off` |

Brand orange does not appear in any value kind. The amber forecast pair is deliberately yellow-brown (`#7A4A00` on `#FFF0CC`), different from orange fills, and always carries the word "Ожидается" and the dotted border.

### 2.5 Flutter mapping (for the developer)

`ColorScheme` is defined explicitly, not from `fromSeed`: `primary` `#F08331`; `onPrimary` `#17191D`; `primaryContainer` `#FFF1E6`; `onPrimaryContainer` `#17191D`; `secondary` `#5B6270`; `surface` `#FFFFFF`; `onSurface` `#17191D`; `onSurfaceVariant` `#5B6270`; `surfaceContainerLowest` `#FFFFFF`; `surfaceContainerLow` `#F7F8FA`; `surfaceContainerHighest` `#EEF0F3`; `outline` `#7F8691`; `outlineVariant` `#E6E8EC`; `error` `#B3261E`; `onError` `#FFFFFF`; `surfaceTint` transparent (removes the pink tint). `scaffoldBackgroundColor` `#F7F8FA`. The M3 seed currently produces the pink background and peach surfaces seen in the audit.

## 3. Typography (Roboto)

Only weights 400, 500 and 700 are used. Flutter's bundled Roboto has Regular, Medium and Bold; weight 600 is not a separate file and would render inconsistently. Letter spacing 0 for titles, 0.1 for labels and body (the current build shows wide tracking from the M3 defaults). Numbers of mass and money use tabular figures. Scale in sp; Cyrillic is covered by Roboto.

| Token | Size / line | Weight | Use |
|---|---|---|---|
| `type-headline` | 28 / 36 | 700 | Login brand, hero number (free mass) |
| `type-title-xl` | 24 / 32 | 700 | Screen title inside content (batch name), form group title |
| `type-title-lg` | 20 / 28 | 700 | App bar title, dialog title |
| `type-title-md` | 16 / 24 | 700 | Card title, section heading |
| `type-body-lg` | 16 / 24 | 400 | Default text, input value, button label uses `type-label-lg` |
| `type-body-md` | 14 / 20 | 400 | Meta text, helper under fields, errors, row labels |
| `type-label-lg` | 16 / 24 | 500 | Button labels, key line in card ("Свободно: 45 кг") |
| `type-label-md` | 14 / 20 | 500 | Field labels, chip labels, text buttons in dense rows |
| `type-badge` | 12 / 16 | 500 | Badges only; always with an icon; never the only place for required information |

Rules: required information is 14 sp or larger (changes the earlier "helper at 12" to 14); the large-text threshold (24 sp or more) applies to `type-headline` and `type-title-xl`; all other text meets 4.5:1. The layout must survive 200% text scale (wrapping, no clipping, no fixed-height text containers).

### 3.5 Display formats (client formatting only, no arithmetic)

- Mass and money are server decimal strings. Display: replace "." with ",", remove trailing zeros after the decimal separator ("12.500" shows "12,5"; "7.000" shows "7"; "0.000" shows "0"), thousands separator is a no-break space ("1 250 кг"). Never round. Units always follow: "кг", "KGS", "KGS/кг".
- `null` price: "Цена не указана" (never 0). `null` composition: "Неизвестно". Other empty optional field: "Не указано".
- Dates: "07.11.2026".

## 4. Spacing, radius, elevation, touch, motion

### 4.1 Spacing (4 dp grid)

`space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16, `space-5` 20, `space-6` 24, `space-7` 32, `space-8` 40, `space-9` 48, `space-10` 64.
Fixed values: screen margin 16; card padding 16 (list cards 12); gap between cards 12; label-to-input 8; field-to-field 16; section-to-section 24; bottom bar padding 16 plus safe-area inset; list bottom padding with FAB 96; with sticky bar = bar height + 16. Content max width 560 dp centered on wider windows (the mobile client; laptop layouts remain as in `phase-2-materials.md`).

### 4.2 Radius

`radius-xs` 4 (skeleton lines), `radius-sm` 8 (photo thumb inside a card), `radius-md` 12 (buttons, inputs, photo tiles), `radius-lg` 16 (cards, gallery, plates), `radius-xl` 24 (dialogs, sheet top corners), `radius-full` (badges, chips, avatar circles). Buttons are 12 dp rounded rectangles, not pills.

### 4.3 Elevation (cool shadow colour `#17191D`)

| Level | Use | Style |
|---|---|---|
| `elevation-0` | Page, plates, banners | none |
| `elevation-1` | Cards | 1 px `#E6E8EC` border plus `0 1 2 rgba(23,25,29,0.06)` |
| `elevation-2` | Sticky bottom bar, FAB, app bar on scroll | `0 2 8 rgba(23,25,29,0.08)`; the bar adds a 1 px top border |
| `elevation-3` | Dialogs, bottom sheets, menus | `0 8 24 rgba(23,25,29,0.12)` |

Shadow never carries meaning. In Flutter, use `Material` elevation 0 with explicit `BoxShadow` and `surfaceTint` transparent.

### 4.4 Touch and focus

Minimum target 48 x 48 dp, gap between neighbours 8 dp or more. Smaller visuals (chip 40, icon 24, badge 28) get a padded hit area. Focus ring `color-focus-ring`, 2 dp, offset 2 dp, on every focusable control (keyboard and switch access); the ring is not orange.

### 4.5 Motion

| Token | Value | Use |
|---|---|---|
| `motion-fast` | 100 ms | Press feedback, ripple |
| `motion-base` | 200 ms | Chip select, banner appear, field state change, snackbar |
| `motion-slow` | 300 ms | Page transition, sheet and dialog enter |
| `motion-shimmer` | 1200 ms loop | Skeleton |
| Enter curve | `Curves.easeOutCubic` | Things appearing |
| Exit curve | `Curves.easeInCubic` (exit is 20% shorter) | Things leaving |
| Move curve | `Curves.easeInOutCubic` | Position changes |

When the system setting "disable animations" is on: transitions 0 ms, shimmer becomes a static `#E6E8EC` block, progress stays indeterminate but without sweeping motion (text "Анализ выполняется…" carries the state). Never animate the status of AI or forecast data in a way that implies progress that is not known.

## 5. Components and states

All components have a visible persistent label or text, an accessible name, and no colour-only meaning.

### 5.1 Buttons

Geometry: min height 48; full-width primary on a screen: 52; radius 12; horizontal padding 24 (16 in a bar); label `type-label-lg`; icon 20 dp, 8 dp gap. One primary (orange) per screen state.

| Variant | Default | Pressed | Focus | Disabled | Loading |
|---|---|---|---|---|---|
| Primary | fill `#F08331`, label `#17191D` (6.70) | fill `#D86F1F` (5.21) | 2 dp ring `#17191D`, offset 2 | fill `#E6E8EC`, label `#9AA0AA`; a reason line is always visible near it | fill kept, label replaced by the busy text ("Сохранение…" / "Отправка…"), 20 dp progress ring `#17191D`, same width, not tappable, announced as busy |
| Secondary | white fill, 1 dp `#7F8691`, label `#17191D` | fill `#EEF0F3` | ring | border `#E6E8EC`, label `#9AA0AA` | as primary, ring `#17191D` |
| Text | no fill, label `#B04A00` (5.49), 48 dp hit area | fill `#FFF1E6` | ring | label `#9AA0AA` | label replaced by busy text |
| Destructive | fill `#B3261E`, label `#FFFFFF` (6.54) | fill darker `#8C1D18` (white on it is higher than 6.54) | ring | as primary disabled | as primary, ring white |
| Text destructive | label `#B3261E` (6.54 on white; 6.15 on `#F7F8FA`) | fill `#FCE4E1` | ring | as text disabled | busy text |

Rules: a second tap while loading does nothing (and the server still protects against repeats). A disabled button is never the only explanation. The label states the action ("Опубликовать"), not "ОК".

### 5.2 Text input

Label above the field (`type-label-md`, 8 dp gap), field height 52, radius 12, white fill, value `type-body-lg`, placeholder `#6B7280`, unit suffix (кг, KGS/кг) inside on the right in `#5B6270`. "Обязательное" tag is shown at the right end of the label row only for fields required for a draft.

| State | Look |
|---|---|
| Default | 1 dp `#7F8691` border |
| Focus | 2 dp `#17191D` border plus a 4 dp ring `rgba(240,131,49,0.25)` (decorative) |
| Filled | as default; value `#17191D` |
| Error | 2 dp `#B3261E` border, icon `error` and text under the field in `type-body-md` `#B3261E`; programmatically tied to the field; announced assertively |
| Disabled | fill `#EEF0F3`, border `#E6E8EC`, value `#9AA0AA`; helper text gives the reason ("Нельзя изменить: есть резервы или переданный объём.") |
| Helper | `type-body-md` `#5B6270` under the field |

Dropdown fields look the same with a chevron-down icon (24 dp) and open a bottom sheet list with 56 dp radio rows (selected row shows `check` and `primary-soft` fill).

### 5.3 Badges (status and AI)

Height 28, horizontal padding 10, icon 16, gap 6, `type-badge`, pill. Material statuses and value kinds: tables in sections 2.3 and 2.4. Screen reader: "Статус: Доступно"; "Предложение ИИ". A badge is not interactive. Never put "Доступно" and "Подтверждено" in one badge (both green).

### 5.4 Batch card (catalog)

Container: white, radius 16, `elevation-1`, padding 12, whole card is one touch target (min 48; pressed fill `#F7F8FA`; focus ring). Layout: left photo 88 x 88, radius 8; right column top to bottom:
1. Title `type-title-md`, max 2 lines.
2. Status badge.
3. Key line `type-label-lg`: "Свободно: 45 кг" (draft: "Масса: 12,5 кг").
4. Meta line `type-body-md` `#5B6270`: "Трикотаж · Хорошее".
5. Meta line: "Ош · Цена не указана".

Height about 120 dp. Accessible name: "Партия {название}, {статус}, свободно {N} кг, {город}". No nested buttons. States: default, pressed, focus, skeleton (same geometry), archived (thumbnail 60% opacity; text unchanged).

### 5.5 Section card

White, radius 16, `elevation-1`, padding 16, heading `type-title-md`. Rows inside are label/value with 1 px `#E6E8EC` dividers, min height 44, label `#5B6270` (fixed 120 dp column), value `#17191D`. A section with no content is not rendered (no empty headings).

### 5.6 Photo upload

Tile 1:1, radius 12. Grid of 2 per row (phone), gap 12. Counter "Фото: N из 5" above the grid.

| State | Look |
|---|---|
| Draft not saved | Panel with text "Сначала сохраните черновик, затем добавьте фото."; the button of the form is the action |
| Empty (saved) | Upload zone: dashed 1.5 dp `#7F8691` border, radius 16, min height 128, icon `add_a_photo` (`#B04A00`), text button "Добавить фото", helper "До 5 фото. JPEG, PNG или WebP, не более 10 МБ каждое." |
| With photos | Tiles with thumbnails (alt "Фото партии {название}, {n} из {m}") plus a dashed "Добавить фото" tile as the last cell while fewer than 5 |
| Uploading | Tile with `#EEF0F3` skeleton, linear progress at the bottom, text "Загрузка фото…"; accessible name includes the percent when known |
| Error | Tile with 2 dp `#B3261E` border, icon `error`, "Не удалось загрузить фото." and text button "Повторить" |
| Limit | The add tile disappears; helper "Достигнут лимит: 5 из 5 фото." (icon `info`) |
| Expired link | Placeholder with text button "Обновить фото"; no error banner |

Remove is not shown until the API supports it (open question P2-3 in `phase-2-materials.md`).

### 5.7 Empty states

Placed in the upper third of the content area, centered, max 280 dp text width: icon 32 dp `#B04A00` in a 64 dp circle `#FFF1E6`; title `type-title-md`; one sentence `type-body-md` `#5B6270`; at most one button (primary if it is the screen's main action, otherwise secondary). No illustrations (no assets). Texts are in `phase-2-materials.md` section 8 (for example "Партий пока нет. Добавьте первую." with "Создать партию"; buyer: text only). A filtered empty state offers "Сбросить фильтры" as a text button.

### 5.8 Error states

| Kind | Component |
|---|---|
| Field | Section 5.2 |
| Page load failed | Panel in the content area: `#FCE4E1` fill, 1 dp `#B3261E` border, icon `error`, message `#17191D` (envelope message verbatim), 5xx: "Код обращения: {request_id}" in `type-body-md`, secondary button "Повторить" (not for 403/404) |
| 409 conflict | Banner under the app bar: `status-warning` pair, icon `warning`, text "Партия изменилась, обновить данные.", text button "Обновить данные"; stays until used |
| Form summary | "Проверьте поля формы." at the top, focus to the first invalid field |
| Success | Snackbar: fill `#17191D`, text white (17.60), icon `check_circle`, 4 s, announced politely; the bar sits above the sticky bar |
| Permission / not found | Full content panel with the text from `states.md` and "На главную" |

### 5.9 Loading

No full-screen spinner. Skeleton of the final layout: blocks `#E6E8EC` with a highlight `#F1F3F6`, radius 4 for lines, same radius as the real component for blocks; list: 4 card skeletons; detail: gallery block, title lines, two section cards. Show after 150 ms; once shown keep at least 300 ms to avoid flicker. Announce "Загрузка…" once (polite). A 20 dp ring is allowed only inside a button and for pull-to-refresh. Analysis uses an indeterminate linear bar plus text (no percent, no estimated time).

### 5.10 Confirmation dialogs

Centered dialog, width min(screen - 48, 360), radius 24, white, `elevation-3`, padding 24, scrim 48%. Title `type-title-lg`, body `type-body-lg`, one consequence sentence. Buttons in a row at the bottom (Cancel left, action right, 12 gap, each at least 48 high); when the labels do not fit (text scale) they stack with "Отмена" on top. Initial focus: "Отмена" (the safe action). While the request runs: the action shows the busy text, both buttons are inert, barrier tap and back do not close. Errors: the dialog closes and the result is shown by the screen banner (422, 409) or stays open with an inline error for network failures. Destructive action uses the destructive filled button; a non-destructive action uses primary. Texts in `visual-screens.md` S05.

### 5.11 Navigation

- App bar: 56 dp, white, bottom border 1 px `#E6E8EC` (shadow `elevation-2` only after scroll), title left-aligned `type-title-lg`, back arrow 48 dp with the accessible name "Назад", at most two actions (text buttons with a label or 48 dp icons with a tooltip and name). The home screen shows the text wordmark "ARTA" (no logo file; see question V-1) and "Выйти".
- Demo banner: fixed under the status bar, inside the safe area, 40 dp minimum, pair `status-neutral` with a stripe strip, icon `science`, text "Демо: синтетические данные, не реальные"; not dismissible; wraps at 200% text.
- No bottom navigation, for these reasons: (1) the current client has two destinations (batches and organization), and a one-item navigation bar is noise; (2) the flows are hierarchical (list, detail, form, analysis), not parallel tabs; (3) an 80 dp bar competes with the sticky action bars, the FAB and the keyboard on forms and on the batch screen; (4) the home screen already works as a hub. Reconsider when at least three peer destinations exist in the build (for example matching, plan, requests, analytics). This replaces "bottom bar (4 items)" in `accessibility.md` and `phase-2-materials.md` section 7 for the mobile client until then.
- Chips (filters): 40 dp visible, 48 dp hit; default white with a 1 dp `#7F8691` border and `#17191D` label; selected `#FFF1E6` fill, 1.5 dp `#B04A00` border, check icon, label `#17191D` medium.

## 6. Open questions

| # | Question | Who answers |
|---|---|---|
| V-1 | Logo file, app icon and splash: not provided. Until then the text wordmark "ARTA" is used. | customer |
| V-2 | Approve dark text `#17191D` on orange (white fails at 2.63) and the darker accent `#B04A00` for links and text buttons | customer |
| V-3 | Create form on phone: keep the existing single page with sections (faster to build) or the four-step flow of `phase-2-materials.md`? This spec supports the single page with sections for now. | customer, flutter-developer |
| V-4 | Is there an unarchive operation? If not, archiving is irreversible for the user and the dialog uses the destructive style as specified. | backend-engineer |
| V-5 | Re-verify every ratio in this file with a tool; confirm Roboto Medium (500) renders for Cyrillic on the test device | qa-engineer, flutter-developer |
| V-6 | Does the list API return a total count? If not, no count is shown ("Партий: N" is not invented). | backend-engineer |
