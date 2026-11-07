# Visual audit of the mobile client, 2026-11-07

Status: draft. Source: six real-phone screenshots in `.../scratchpad/before/` (01_login, 02_home, 03_catalog, 04_detail, 05_detail_draft, 06_create) plus `frontend/lib/app/theme.dart`. UI copy is Russian, identifiers English. The fixes refer to `visual-system.md` (tokens, components) and `visual-screens.md` (P0 screen specs). This file proposes no API changes.

## 0. Method and limits

- Screenshots are 1080 px wide. Device density is unknown, so sizes are given in screenshot pixels (px) and approximate dp (px / 2.6). Treat dp values as approximate.
- Pixel colours could not be sampled (no tool to run code in the design environment). Colours of the current app are stated by sight ("pinkish background") and by the Material 3 seed rule in `theme.dart`: `ColorScheme.fromSeed(seedColor: F08331)` tints background, surface and containers orange. Where a number for a current colour is used it is marked "assumed".
- All WCAG ratios below were calculated by hand with the WCAG 2.1 formula (section 9). They must be re-verified with a tool before the theme is approved; a result from a tool overrides this file.
- File names do not match content: `04_detail_available.png` shows an archived batch ("Test photo batch", "В архиве"); `05_detail_other.png` shows a draft ("Test cotton"). The first `06_create.png` showed the home screen; it was replaced and the new file (the create form) is audited below.
- The red DEBUG ribbon and the "2 устройства" pill are not app UI (debug build and device overlay) and are ignored.

## 1. Priority legend

P0 breaks usability, accessibility or hides content; fix before the next demo. P1 weakens hierarchy or consistency; fix in this refinement. P2 polish.

## 2. Top five problems (summary)

| # | Problem | Screens | Priority |
|---|---|---|---|
| 1 | Brand orange `#F08331` is used as text, link and icon colour on light backgrounds: 2.5-2.6:1, below even the 3:1 non-text threshold | 01, 05, 06 | P0 |
| 2 | Empty dead zone of about 600-800 px (about 230-300 dp) between the app bar and the content on login and home; the app bar title sits about 100 px lower than a standard 56 dp bar | 01, 02 | P0 |
| 3 | Content is hidden or touched by floating elements: the extended FAB covers the "Зарезервировано" badge and the last card; the "Сохранить черновик" button touches the bottom edge and the home indicator | 03, 06 | P0 |
| 4 | Flat hierarchy: every line has the same size and weight; a catalog card is about 385 px (about 145 dp) tall with five equal lines; on a draft, the primary action comes before the checklist it depends on and competes with "Изменить" | 03, 04, 05 | P1 |
| 5 | Inconsistent visual language: pink/peach M3-seed tints instead of the brand neutrals, saturated peach "Нет фото" blocks, pill buttons next to 4 px-radius inputs, a button visibly shorter than the inputs (113 px vs 130 px), floating labels used as placeholders | all | P1 |

Secondary P1: number and text formatting ("7 кг", "12.5 кг", "120.500 кг", "0.000 кг", "Bishkek" next to "Бишкек"); an empty "Анализ ИИ" heading on the archived batch.

## 3. Screen 01: login (`01_login.png`)

What is good
- One clear primary button, full width, dark label on orange (legible, see section 9).
- Password visibility toggle present; demo credentials with a "Заполнить" helper.
- Fields are tall enough (130 px, about 50 dp).

What is bad

| # | Finding | Priority | Fix |
|---|---|---|---|
| 1.1 | "Заполнить" and "Нет аккаунта? Зарегистрироваться" are orange text on a pinkish background: 2.55:1 (assumed background `#FFF8F5`), fail 4.5:1 and 3:1 | P0 | Text buttons use `accent-text` `#B04A00` (5.49 on white, 5.17 on `#F7F8FA`) |
| 1.2 | "ARTA" at y=350 and "Вход" at y=1025: about 600 px of empty space; the form starts below the fold of a 640 dp screen | P0 | Content top-aligned in a scroll view, 32-48 dp from the app bar; the form must be visible without scrolling. Check for Spacer, `Center`, or a fixed-height box in the screen (cause not visible from the screenshot) |
| 1.3 | The brand is a plain regular-weight word "ARTA" at the top-left, the title "Вход" is larger than the brand: no brand moment | P1 | Brand block: wordmark 28/36 bold, one descriptive line under it (see `visual-screens.md` S01). No logo file exists; do not invent one |
| 1.4 | Demo credentials sit between title and form and push the form down; they look like part of the form | P1 | Move to a labelled block below the registration link; label "Демо-вход" |
| 1.5 | The button is shorter than the fields (113 px vs 130 px) and fully rounded, fields use about 4 px radius | P1 | One radius family: buttons and inputs 12 dp, heights 52 dp for the full-width primary |
| 1.6 | Labels "Email"/"Пароль" are placeholder-style text inside the field; after typing they shrink to a floating label | P1 | Persistent label above the field (already required in `phase-2-materials.md` section 6) |
| 1.7 | Input borders are about 1 px grey-brown; contrast not verified | P2 | Border `#7F8691`: 3.67 on white (needs 3.0) |
| 1.8 | Demo banner is drawn as white text on a dark grey band in the status-bar zone. It does not use the demo token pair from `tokens.md` and it is not clear whether it sits in the safe area | P1 | Banner below the status bar inside the safe area, `value-demo` pair (see `visual-system.md` section 2.4) |

## 4. Screen 02: home (`02_home.png`)

What is good: short and simple; two clear destinations; icons with text.

| # | Finding | Priority | Fix |
|---|---|---|---|
| 2.1 | Same dead zone: content starts about 800 px below the app bar (y=1230) | P0 | As 1.2 |
| 2.2 | The screen has no primary action. The enterprise user's main job (create a batch) is two taps away | P1 | Full-width primary "Создать партию" for the `enterprise` role (buyer: no such button) |
| 2.3 | Email is the largest text; role is a plain line "Роль: Предприятие" | P1 | Account row: email 16/24 medium, role as a neutral badge |
| 2.4 | List tiles use heavy dark-brown icons and thin chevrons with no container; no divider or card; no pressed affordance | P2 | Single white card with 1 px dividers, icon in a 40 dp tinted circle, 56 dp rows |
| 2.5 | The logout icon has no visible label | P2 | Keep, with accessible name "Выйти" and tooltip; the confirmation is not needed (no data loss) |
| 2.6 | No metrics. This is correct: no analytics API in this phase, do not add placeholders with zeros | n/a | Keep the area empty until `GET /analytics/summary` is integrated; then follow `dashboard.md` |

## 5. Screen 03: catalog (`03_catalog.png`)

What is good: status badges carry icon and text; the whole card is one tap target; the photo thumbnail is on the left; horizontal filter chips.

| # | Finding | Priority | Fix |
|---|---|---|---|
| 3.1 | The extended FAB covers the "Зарезервировано" badge and part of the last card; the list has no bottom padding. The FAB is peach (container colour) with brown text, not the primary orange | P0 | List bottom padding 96 dp; FAB uses the primary fill with the dark label; hidden in the empty state where the empty-state button is the single action |
| 3.2 | Card is 385 px tall: five stacked lines (type and condition; mass; city; price) of equal weight; the title is the only emphasis | P1 | Title (bold) > badge > key mass line (medium) > one meta line "Город · Цена" (secondary). Card about 120 dp |
| 3.3 | The "Нет фото" placeholders are saturated peach blocks, repeated four times, the loudest element on the screen | P1 | Placeholder `#EEF0F3` with a grey icon and caption |
| 3.4 | Card background is peach, page background pink, with a soft brown shadow; the surfaces merge | P1 | Page `#F7F8FA`, card white, 1 px `#E6E8EC` border and a very light shadow |
| 3.5 | Filter chip "Частично распределено" is cut at the right edge with no cue that the row scrolls | P2 | 16 dp start padding, last chip partly visible plus an end fade; chips 40 dp visible, 48 dp hit area |
| 3.6 | Mixed formats: "Свободно: 7 кг", "Масса: 12.5 кг", "120.500 кг", "45.000 кг"; "Bishkek" and "Бишкек" | P1 | Display rule in `visual-system.md` section 3.5 (comma, no trailing zeros, no arithmetic). Latin city names and "Test ..." are fixture data: ask the backend/demo owner to use Russian demo fixtures |
| 3.7 | The archived batch shows "Свободно: 7 кг" next to the badge "В архиве" | P2 | Archived cards use "Масса: N кг" and a dimmed thumbnail (text stays full contrast) |
| 3.8 | Title row "Мои партии" with only a back arrow: no other action | P2 | Keep; see section 9.4 of `visual-system.md` (no bottom navigation) |

## 6. Screen 04: batch detail, archived (`04_detail_available.png`)

What is good: the structure (header, photos, characteristics, mass, AI) follows the spec; confirmation date is shown.

| # | Finding | Priority | Fix |
|---|---|---|---|
| 4.1 | The photo is a 378 px (about 145 dp) square at the left edge with the label "Фото: 1" above it; most of the width is empty | P1 | Full-width 4:3 image, radius 16, counter badge "1 из N" |
| 4.2 | "Подтверждено человеком, 07.11.2026" is a bold line with no icon or confirmed style; the spec requires the confirmed kind (icon, label, colour) | P1 | Confirmed badge (success pair, `check_circle`) plus date text |
| 4.3 | Characteristics are "bold label: value" lines with no rows or dividers | P1 | Label/value rows with 1 px dividers, label secondary, value primary text |
| 4.4 | Mass: "Всего: 7 кг" and "Удержано: 0.000 кг": same field shows two decimal formats; the key figure (free mass) is not emphasised | P1 | Hero "Свободно" 28/36 bold with "из N кг всего" (server values only); the three other balances in a compact list |
| 4.5 | The "Анализ ИИ" heading has nothing below it (archived batch) | P1 | Never render an empty section. Archived: hide the section, or show one line "Анализ недоступен для архивной партии" if the product wants it (ask backend whether the analysis is readable) |
| 4.6 | Section headings are bold at nearly body size; the page title is large | P2 | Section heading 16/24 bold; title 24/32 bold |

## 7. Screen 05: batch detail, draft (`05_detail_other.png`)

What is good: explains what is missing for publishing; the checklist uses icons plus text; "Не подтверждено" is explicit.

| # | Finding | Priority | Fix |
|---|---|---|---|
| 5.1 | The primary button "Подтвердить характеристики" comes before the checklist "Чтобы опубликовать, осталось" and before the data it asks to confirm; at the same time the checklist says a photo is missing and the draft cannot be published | P0 | Order: header, photos, checklist, characteristics, mass, AI; one next-step primary in a sticky bottom bar only when exactly one action remains (see `visual-screens.md` S05) |
| 5.2 | "Изменить" is a second full-width button with orange text and a grey outline: 2.6:1 text, competes with the primary | P0 | Move to the app bar as a text action "Изменить" (`accent-text`), or as a secondary button with a dark label |
| 5.3 | Checklist rows have empty circle icons and no action; "Добавьте хотя бы одно фото" is not tappable | P1 | Each open row gets a working 48 dp text action ("Добавить фото", "Изменить"), icon `cancel` plus the screen-reader text "Не выполнено" |
| 5.4 | Three separate plain sentences ("Не виден покупателям.", "У партии нет фото.", the confirmation explanation) appear as unrelated paragraphs | P1 | Badge caption under the status; "нет фото" becomes the photo empty state with its button |
| 5.5 | "Для анализа нужно фото." is plain text at the bottom | P2 | AI section card with the same text, no button (rule from `demo-and-ai.md` section 3) |

## 8. Screen 06: create form (`06_create.png`, replaced version)

What I see: app bar "Новая партия" with a back arrow; a single scrolling page (not the four-step flow of `phase-2-materials.md`); nine fields with floating-style labels inside the outline ("Название (обязательно)", "Тип материала" with a dropdown arrow, "Состояние", "Масса", "Город", "Размер обрезков (необязательно)", "Состав (необязательно)", "Цена за кг (необязательно)"); helper lines under mass, composition and price; the block "Фото партии (до 5)" with two caption lines and an outlined "Добавить фото" button with orange text and icon; a full-width orange "Сохранить черновик" button at the very bottom, in contact with the home-indicator area.

What is good: helper texts are present and in Russian; required and optional are marked; the demo photo note is shown; format hint for mass is given.

| # | Finding | Priority | Fix |
|---|---|---|---|
| 6.1 | "Добавить фото" is orange text on a near-white page: 2.55:1; its outline has the same low contrast | P0 | Secondary button with a dark label and `#7F8691` border, or an upload tile (see `visual-system.md` section 4.6) |
| 6.2 | The save button sits at the bottom of the scroll content with no safe-area padding; the button touches the screen edge and the home indicator | P0 | Sticky bottom action bar with safe-area inset; content gets bottom padding equal to the bar height |
| 6.3 | One long form of nine fields with no grouping; about 2.3 screens tall; the user cannot see what is required for publishing | P1 | Group into sections "Основное", "Масса и место", "Цена", "Фото" (cards with 16 dp padding). The four-step phone flow in `phase-2-materials.md` remains an option; see question V-3 in `visual-system.md` |
| 6.4 | Unit is not shown for "Масса" and "Цена за кг" (the label has "кг" only in the price); the spec requires a unit suffix on every numeric field | P1 | Suffix "кг" and "KGS/кг" inside the field, right side |
| 6.5 | "(обязательно)" / "(необязательно)" in the label text makes labels long and inconsistent; the spec says required for a draft is only the name | P1 | Label "Название" with the tag "Обязательное" at the right of the label row; optional fields carry no suffix, the section says "Необязательно" once |
| 6.6 | Helper text is indented to the text inset (77 px) while section headings sit at the field edge (38 px); two left edges | P2 | Helper and error text start at the field's left edge plus 16 dp (same as the input text) consistently; section headings at the screen margin |
| 6.7 | Dropdown arrows are small, dark filled triangles; no value is visible until chosen | P2 | Chevron-down icon 24 dp; selection opens a bottom sheet list of 56 dp rows |
| 6.8 | No photo empty state: only text and a button | P1 | Photo block component with empty, filled, error and limit states |

## 9. Contrast numbers (WCAG 2.1, calculated)

Formula: for each channel c = value/255; lin = c/12.92 if c <= 0.04045, else ((c + 0.055)/1.055)^2.4; L = 0.2126 R + 0.7152 G + 0.0722 B; ratio = (L_lighter + 0.05)/(L_darker + 0.05). Thresholds: text 4.5, large text (>= 24 px, or >= 18.66 px bold) 3, UI component boundaries and meaningful icons 3.

Relative luminance (L) of the colours used:

| Colour | HEX | L |
|---|---|---|
| Brand primary | `#F08331` | 0.3498 (R 0.8714, G 0.2270, B 0.0307) |
| Text | `#17191D` | 0.0097 |
| Page background | `#F7F8FA` | 0.9381 |
| Border | `#E6E8EC` | 0.8059 |
| White | `#FFFFFF` | 1.0000 |
| Assumed current M3 background | `#FFF8F5` | 0.9499 |
| Current `onPrimary` | `#1A1A1A` | 0.0103 |
| `accent-text` | `#B04A00` | 0.1413 |

Pairs:

| Pair | Ratio | Text 4.5 | Non-text 3.0 |
|---|---|---|---|
| `#17191D` on `#F08331` (label on orange button) | 6.70 | pass | pass |
| `#1A1A1A` on `#F08331` (current theme) | 6.63 | pass | pass |
| White on `#F08331` | 2.63 | fail | fail |
| `#F08331` on white (text, link, thin icon) | 2.63 | fail | fail |
| `#F08331` on `#F7F8FA` | 2.47 | fail | fail |
| `#F08331` on assumed current background `#FFF8F5` | 2.50 | fail | fail |
| `#17191D` on white / on `#F7F8FA` | 17.60 / 16.56 | pass | pass |
| `#E6E8EC` border on white / on `#F7F8FA` | 1.23 / 1.15 | n/a | fail as a control boundary; allowed for decorative card edges only |
| `#B04A00` on white / `#F7F8FA` / `#FFF1E6` | 5.49 / 5.17 / 4.96 | pass | pass |
| `#7F8691` on white / `#F7F8FA` | 3.67 / 3.45 | n/a | pass (input border) |

Findings:
- The dark label on the orange button is legible (6.70 and 6.63); this part of the current theme is correct. AAA (7:1) is not reached, AA is.
- White on orange must never be used (2.63).
- Every orange-coloured text or thin icon in screenshots 01, 05 and 06 fails: "Заполнить", "Нет аккаунта? Зарегистрироваться", "Изменить", "Добавить фото" (about 2.5-2.6).
- The orange-to-page boundary of a filled button (2.47-2.63) is below 3:1. This is acceptable because the button is identified by its 6.70:1 label and the fill is not the only cue; do not rely on the orange outline alone for any control.
- Chips, badges and status pairs are specified with their numbers in `visual-system.md` section 2.

## 10. Open questions

| # | Question | Who answers |
|---|---|---|
| A-1 | Which screen or widget causes the dead zone (1.2, 2.1)? Confirm after the fix at 1080x2400 and at 200% text scale | flutter-developer |
| A-2 | Is the dark banner in the screenshots the app banner or a device overlay? | flutter-developer |
| A-3 | Real device density (for dp values) | qa-engineer |
| A-4 | Demo fixtures in Russian (cities "Бишкек", names without "Test ...") | orchestrator, backend-engineer |
| A-5 | Is the archived batch's analysis readable (4.5)? | backend-engineer |
