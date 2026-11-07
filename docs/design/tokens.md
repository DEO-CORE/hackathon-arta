# Design Tokens

Status: draft, Phase 1 mobile (Material 3, Russian UI). Brand primary is `#F08331` (given by the user). Everything else in the palette is a proposal derived from it. Token names follow M3 roles for the Flutter `ColorScheme` plus ARTA semantic extensions (kebab-case identifiers, as before).

## 0. Contrast method

- Standard: WCAG 2.1 (1.4.3 text >= 4.5:1; large text >= 24 px or >= 19 px bold, and 1.4.11 icons/component boundaries >= 3:1).
- Formula: for each sRGB channel c8 in 0..255, c = c8/255; lin = c/12.92 if c <= 0.04045, else ((c+0.055)/1.055)^2.4. L = 0.2126*R + 0.7152*G + 0.0722*B. Ratio = (L_light + 0.05) / (L_dark + 0.05).
- Values were calculated by hand (no script could be run in the design environment) and are shown to 3 decimals, not rounded up. Treat the third decimal as approximate (about +-0.01). Before the theme is approved, FE/QA must re-verify every pair with a tool (for example a WCAG contrast checker or a short script using the formula above). Any pair that comes out below its threshold overrides this document.
- Relative luminance used: `#F08331` L = 0.350; white L = 1.000; `#1C1B1F` L = 0.0113.

## 1. Key finding: `#F08331` as text or icon colour

| Pair | Ratio | Text 4.5 | Large text / icon 3.0 |
|---|---|---|---|
| `#F08331` on white `#FFFFFF` | 2.626 | FAIL | FAIL |
| `#F08331` on background `#FFFBF8` | 2.552 | FAIL | FAIL |
| `#F08331` on surfaceVariant `#F5EDE6` | 2.269 | FAIL | FAIL |
| `#F08331` on primaryContainer `#FFDCC2` | 2.035 | FAIL | FAIL |
| White `#FFFFFF` text on `#F08331` | 2.626 | FAIL | FAIL |
| `#1C1B1F` text on `#F08331` | 6.522 | PASS | PASS |
| `#000000` text on `#F08331` | 7.996 | PASS | PASS |
| `#F08331` on dark surface `#1C1B1F` | 6.522 | PASS | PASS |
| `#9A3F00` (primary-text) on white | 6.806 | PASS | PASS |
| `#9A3F00` on background `#FFFBF8` | 6.613 | PASS | PASS |
| `#9A3F00` on primaryContainer `#FFDCC2` | 5.272 | PASS | PASS |

Rules that follow:

1. `#F08331` is a FILL colour. Text on it is always dark (`onPrimary` = `#1C1B1F`). Never white text on it (M3 default `onPrimary` is white; the theme must override it).
2. `#F08331` is NOT used as text, link or thin icon colour on light surfaces, and not as the only boundary of a control (2.6:1 < 3:1). Use `primary-text` `#9A3F00` for links, text buttons, active-tab labels and meaningful icons.
3. Allowed uses of `#F08331`: filled button/FAB background with dark label, selected-state indicator bar combined with a dark label, large decorative shapes, progress fill when a text value is also shown, and the primary colour on dark theme surfaces.
4. Focus ring: `#1C1B1F`, 2 px, 2 px offset (contrast 17.1 on white); never the orange.
5. Hover/pressed overlays on the primary fill (M3 state layers 8%/12% of onPrimary) change the background slightly; contrast of the dark label stays far above 4.5 but must be re-checked after the theme is built.

## 2. Light theme (MVP)

| Role (token) | HEX | Checked pair | Ratio | Result |
|---|---|---|---|---|
| `primary` | `#F08331` | with onPrimary | 6.522 | PASS text |
| `onPrimary` | `#1C1B1F` | on primary | 6.522 | PASS text |
| `primaryContainer` | `#FFDCC2` | with onPrimaryContainer | 12.41 | PASS text |
| `onPrimaryContainer` | `#3A1800` | on primaryContainer | 12.41 | PASS text |
| `primary-text` (link, extension, `color-text-link`) | `#9A3F00` | on white / background | 6.806 / 6.613 | PASS text |
| `secondary` | `#5B5048` | on white | 7.819 | PASS text and icon |
| `onSecondary` | `#FFFFFF` | on secondary | 7.819 | PASS text |
| `secondaryContainer` | `#EFE6DE` | with onSecondaryContainer `#1C1B1F` | 13.90 | PASS text |
| `background` | `#FFFBF8` | with onBackground `#1C1B1F` | 16.65 | PASS text |
| `surface` | `#FFFFFF` | with onSurface `#1C1B1F` | 17.13 | PASS text |
| `surfaceVariant` (cards, inputs fill) | `#F5EDE6` | onSurface / onSurfaceVariant | 14.80 / 6.754 | PASS text |
| `onSurfaceVariant` (secondary text) | `#5B5048` | on white / background | 7.819 / 7.60 | PASS text |
| `outline` (input borders, control boundaries) | `#857A71` | on white / background / surfaceVariant | 4.184 / 4.065 / 3.614 | PASS 3.0 (non-text) |
| `outlineVariant` (dividers) | `#D8CCC2` | decorative only | not checked | Not used to convey meaning |
| `error` | `#B3261E` | on white / background | 6.536 / 6.35 | PASS text |
| `onError` | `#FFFFFF` | on error | 6.536 | PASS text |
| `errorContainer` (extension `status-error-bg`) | `#FCE4E1` | error on it | 5.392 | PASS text |
| `success` (`status-success-fg`) | `#1B6B3A` | on white | 6.541 | PASS text |
| `status-success-bg` | `#DDF3E4` | success on it | 5.611 | PASS text |
| `warning` (`status-warning-fg`, dark amber, not orange) | `#7A4A00` | on white | 7.481 | PASS text |
| `status-warning-bg` | `#FFF0CC` | warning on it | 6.622 | PASS text |
| `focus-ring` | `#1C1B1F` | on white | 17.13 | PASS 3.0 |

Disabled: `color-text-disabled` is exempt from WCAG contrast, but a disabled control is never the only carrier of an explanation (see `states.md` button rules).

Not yet defined (values not invented): `info`, `neutral` status pairs, `tertiary`, hover/pressed variants. They are to be derived and checked when first used.

## 3. Dark theme (post-MVP, "позже")

Not needed for MVP; the table fixes only what is already verified. Everything else is TBD and must be calculated and checked before dark mode ships.

| Role | HEX | Checked pair | Ratio | Result |
|---|---|---|---|---|
| `surface` / `background` | `#1C1B1F` | with onSurface | 16.65 | PASS text |
| `onSurface` | `#FFFBF8` | on `#1C1B1F` | 16.65 | PASS text |
| `primary` (also usable as text/icon here) | `#F08331` | on `#1C1B1F` | 6.522 | PASS text |
| `onPrimary` | `#1C1B1F` | on primary | 6.522 | PASS text |
| `primaryContainer`, `onPrimaryContainer`, `secondary`, `outline`, `error`, `success`, `warning` | TBD | not calculated | n/a | not checked |

## 4. Typography (Material 3 type scale)

Font family: brand font is not provided. **Ожидает пользователя.** Until then use the platform/Material default (Roboto on Android and Flutter web), which covers Cyrillic; this is a placeholder, not a brand decision. `font-family-mono` only for identifiers.

| M3 style | Size / line height (px) | Weight | ARTA use |
|---|---|---|---|
| `displaySmall` | 36 / 44 | 400 | Not used on phone |
| `headlineMedium` | 28 / 36 | 400 | Key metric number (tabular figures, see `dashboard.md`) |
| `headlineSmall` | 24 / 32 | 400 | Screen title on laptop |
| `titleLarge` | 22 / 28 | 400 | Screen title on phone (top app bar) |
| `titleMedium` | 16 / 24 | 500 | Card title, section header |
| `titleSmall` | 14 / 20 | 500 | List item title in dense lists |
| `bodyLarge` | 16 / 24 | 400 | Default body and form values; all required information |
| `bodyMedium` | 14 / 20 | 400 | Secondary descriptions, table cells |
| `bodySmall` | 12 / 16 | 400 | Helper text only; never required information |
| `labelLarge` | 14 / 20 | 500 | Button labels |
| `labelMedium` | 12 / 16 | 500 | Chip and badge labels (always with icon) |
| `labelSmall` | 11 / 16 | 500 | Not used for meaning; avoid |

Large-text threshold: `headlineSmall` and larger (>= 24 px) qualify for 3:1; `titleLarge` (22) does not and must meet 4.5:1. Text scale to 200% must not break layout (`accessibility.md`).

Note: `accessibility.md`/earlier draft said body not below 16. Resolution: required information uses `bodyLarge`; `bodyMedium` (14) is allowed only for supplementary text (accessibility owner to confirm, Q-T2).

## 5. Spacing, layout, shape, elevation

- Spacing scale (4 px grid): `space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16, `space-5` 24, `space-6` 32, `space-7` 48, `space-8` 64.
- Phone: horizontal screen margin `space-4` (16); gap between cards `space-3` (12); inside card padding `space-4`.
- Breakpoints (M3 window classes): compact < 600, medium 600-839 (existing draft said 600-1023, keep one definition in implementation), expanded >= 840 `[to reconcile with accessibility.md, Q-T2]`.
- Touch: minimum target 48 x 48 px (`size-touch-min`), gap between adjacent targets >= 8 px. Visible control smaller than 48 (icon 24, chip 32) gets padded hit area. Primary button height 48 (full-width on phone), bottom-bar items >= 48 high (M3 navigation bar is 80).
- Radius: `radius-sm` 8 (chips, inputs), `radius-md` 12 (cards), `radius-lg` 16 (sheets top corners 28 per M3), `radius-full` (pills, FAB-like).
- Elevation: M3 tonal surfaces; `elevation-0` flat, `elevation-1` cards (1 dp), `elevation-2` menus (3 dp), `elevation-3` dialogs/sheets (6 dp). No elevation alone for meaning.
- Borders: `border-width-default` 1, `border-width-focus` 2; `border-style-suggested` dashed, `border-style-forecast` dotted.
- Motion: short 150 ms, medium 250 ms, standard easing; reduced-motion removes animation.

## 6. Semantic value labels (from `ai-results.md`) bound to tokens and icons

Each kind has: colour pair (checked above), text label, icon, border style. Colour is never the only signal; label text and icon are always rendered, and the screen reader reads the label text.

| Kind | Label (RU) | fg / bg (HEX) | Pair ratio | Border | Icon (Material Symbols name) |
|---|---|---|---|---|---|
| Suggested (AI) | "Предложение ИИ" | `#3B4BA0` on `#E6E9F8` | 6.435 PASS | dashed 1 px | `auto_awesome` (outlined) |
| Confirmed | "Подтверждено" + author, date | `#1B6B3A` on `#DDF3E4` | 5.611 PASS | solid 1 px | `check_circle` (filled) |
| Forecast | "Ожидается" + caption "Прогноз, не факт" | `#7A4A00` on `#FFF0CC` | 6.622 PASS | dotted 1 px, italic caption | `schedule` |
| Fact | "Факт" (where mixed with forecast) | `#1C1B1F` on `#FFFFFF` | 17.13 PASS | solid 1 px `outline` | `fiber_manual_record` (filled dot) |
| Demo | "Демо" | `#5B5048` on `#EFE6DE` | 6.345 PASS | diagonal-stripe badge | `science` (flask) |

Tokens: `value-suggested-fg|bg|border`, `value-confirmed-*`, `value-forecast-*`, `value-fact-*`, `value-demo-*` take the values above. Borders use `outline` `#857A71` or the kind's fg colour. "Demo" combines with another kind (demo badge plus the other kind's chip). Indigo for suggestions and amber for forecast are deliberately not the brand orange, so a brand-coloured element is never mistaken for AI or forecast data. Stale confirmation ("Требует повторного подтверждения") uses the warning pair with icon `warning`.

Status chips for material, request and solver statuses (`status-*`, `material-*`, `request-*`, `plan-*`) reuse success/warning/error pairs plus neutral (secondary pair) and always include text plus an icon; assignment of each status to a pair is left to the screen specs.

## 7. Pending from the user

- Brand logo: **ожидает пользователя** (not invented; use plain text "ARTA" in the app bar until provided).
- Brand font family: **ожидает пользователя**.
- Approval of derived colours (secondary, containers, semantic hues) as the brand extension.

## Open questions

1. (user) Are the derived colours acceptable, in particular dark `#1C1B1F` text on orange buttons instead of white text? White cannot be used (2.626:1).
2. (user) Logo files and brand font: provide or confirm use of the platform default font.
3. (flutter-developer / qa-engineer) Re-verify all ratios with a tool and reconcile breakpoints (840 vs 1024) and body size (16 vs 14) with `accessibility.md` (Q-T2).
