# Accessibility and Responsive Rules

Status: draft. Targets are WCAG 2.1 AA as design goals; compliance is not claimed until checked (QA / FE-06).

## Contrast and colour

- Text and its background >= 4.5:1; large text (>= 24 px, or >= 19 px bold) and UI component boundaries/icons >= 3:1. Check every `*-fg|bg` token pair.
- Meaning is never carried by colour alone: status chips have text + icon; suggested/confirmed/forecast/fact/demo differ by label, border style and icon (`ai-results.md`).
- Focus ring (`color-focus-ring`, `border-width-focus`) visible with >= 3:1 against adjacent colours.

## Touch and pointer

- Interactive target >= 48x48 logical px (`size-touch-min`), gap >= 8 px. Small icons get padded hit area.
- Destructive buttons are not adjacent to primary ones without spacing; confirmation dialog for destructive actions.

## Labels and screen reader

- Every input has a visible persistent label (not placeholder-only) and unit suffix (кг, KGS, KGS/кг). Required fields marked with text "Обязательное", not only an asterisk.
- Icon-only buttons have an accessible name ("Удалить фото", "Закрыть").
- Errors are linked to fields; on submit failure focus moves to the first invalid field and a summary is announced.
- Status changes announced via live region: loading finished, "Анализ завершён", "Заявка подтверждена", "Сохранено", 409 banners (assertive for errors, polite for success).
- Provenance labels are text, not only visual: "Подтверждено, Иванов, 12.03.2026"; "Ожидается: … KGS, прогноз".
- Photos have alt text: "Фото партии {название}, {n} из {m}". Metric cards: label, value, unit, kind in one reading order.
- Progress indicators have accessible names with percent where known.

## Forms and submit

- One submit per action: button disabled and `aria-busy` while in flight; Enter key obeys the same lock.
- Keyboard: all actions reachable by Tab; Esc closes dialogs/sheets and returns focus to the trigger; no keyboard traps.
- Sessions: expiry warning not time-limited-input destructive; form text kept.

## Focus order (per screen, top to bottom, left to right on laptop)

1. Skip to content link.
2. Navigation (sidebar/bottom bar).
3. Page title region, then page-level actions (primary).
4. Filters / form fields in visual order.
5. Content list or cards; within a card: title link, status, secondary actions.
6. Banners (errors/notices) are placed before the content they affect in the DOM/semantic order and receive focus only for blocking errors.
7. Dialogs: focus on first control (or the safest action, e.g. "Не отменять"); focus returns to trigger.
- S06: notice -> photos -> AI suggestions -> form -> confirm action. S09: tabs -> list -> detail -> actions.

## Responsive behaviour

| Aspect | Phone (< 600) | Tablet (600-1023) | Laptop (>= 1024) |
|---|---|---|---|
| Navigation | bottom bar (4 items) + "Ещё" | rail | sidebar |
| Content | single column | 1-2 columns | up to 3 columns, `content-max-width` |
| Primary action | sticky bottom bar within thumb reach (form screens), full width | inline top-right | inline top-right |
| Filters | bottom sheet | collapsible panel | persistent side panel/top row |
| Tables (plan, transactions) | cards with label/value rows | table | table |
| S06 | stacked, confirm bar sticky | two columns | two columns |
| Dashboard | 1 column, facts then forecast | 2 columns | 3 columns |
| Dialogs | full-screen sheet | centered | centered |

- Collapsed content on phone (reasons lists, excluded matches, assumptions) is expandable with a labelled toggle; expanded state announced.
- Text scale up to 200% without loss of function; no horizontal scroll at 320 px width except data tables turned into cards.
- Reduced motion respected.

## Open questions

- Required browser/screen-reader test set (qa-engineer).
- Is a language attribute `ru` set on the Flutter web page? (flutter-developer)
