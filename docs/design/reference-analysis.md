# ARTA reference analysis

Status: draft. Source folder: `/Users/sm1le/Desktop/ARTA/docs/design/referance/` (8 files).

## 0. Coverage

UPDATE: the two "Снимок экрана" files were copied by the orchestrator as `extra-1.png` and `extra-2.png` and both opened. They are analysed in section 1b. The "NO / not opened" rows in the table below are superseded by this note; the originals still fail to open by their Unicode names, but their content is covered through the copies (assumption: the copies are the same images; this was not verified).

| File | Opened |
| --- | --- |
| home.png | yes |
| statistic.png | yes |
| success and other.png | yes |
| bottom_navigation.png | yes |
| registration.png | yes |
| code verify.png | yes |
| `Снимок экрана — 2026-11-07 в 11.17.12.png` | NO. Read returned "File does not exist" on every attempt, although Glob lists it. Most likely the filename contains special Unicode characters (normalisation form or non-breaking spaces) that I cannot reproduce in a path. Nothing in this document is derived from it. |
| `Снимок экрана — 2026-11-07 в 11.17.23.png` | NO. Same failure and same likely cause. |

Action for the owner: rename both files to ASCII names (for example `extra-1.png`, `extra-2.png`) and re-run the analysis, or tell me what they show. Until then the two files are a gap in this analysis.

Notes on provenance: home, statistic, success/profile are healthcare-app mockups (doctors, lab results, appointments). Registration and code verify carry a third-party brand ("Budgetly", a finance app). That logo, the mascot, the Google/Apple buttons and all photos and copy are proprietary or stock content and must not be reproduced. Only the visual language is used as direction.

Colour values below are estimated by eye from the images, not measured. They are marked "approx.".

## 1. Observed (per file)

### home.png
- Phone frame with a dynamic island, status bar 9:41. Single column, full-bleed screen.
- Background: soft vertical gradient from neutral light grey to a pale yellow-green in the top-right corner. Text sits directly on it.
- Top bar: a pill-shaped profile chip (round avatar + name) on the left; a rounded-square button with a hamburger icon on the right. No page title in the bar.
- Greeting headline, about 34-36 px, two tones in one sentence: first part near-black, second part mid grey. Two lines.
- A stacked card: a main card with a very large radius (about 28-32 px), off-white, with a second and a third card edge visible behind it. Content: title (two lines, regular weight), a light-green pill chip ("45 min"), a row with a small rounded-square photo, name (medium), role (grey), and time on the right.
- Section header, two-tone ("Let's find" grey, "your doctor" black), with two rounded-square icon buttons on the right (search, filter).
- A horizontal carousel of photo cards, radius about 28 px. The second card is cropped at the screen edge, which signals scrolling. A frosted, translucent info panel overlaps the bottom of each photo: name, grey subtitle, and a lime (yellow-green) rounded-square button with a diagonal arrow.
- Bottom navigation: a floating wide pill, light translucent surface, 4 icon-only items. The active item is a white rounded-square with a filled dark icon. Inactive items are thin grey outline icons. No text labels. Content scrolls under it.
- Density: low. Large gaps, few elements per screen, one idea per block.

### statistic.png
- Header: a rounded-square back button on the left, centred title "Vitamin D Lab Results", no bar background.
- Metric block: a small label, a grey caption "Summary", a very large number (about 56-60 px, medium weight) with a small unit beside it, baseline-aligned.
- A status pill at the top right (peach/orange fill, dark text, text label "Insufficient").
- A segmented range bar with four colours (red, peach, green, blue), rounded ends, with range labels below (<50, 50-75, 75-125). The current value's position is not marked on the bar in the visible crop.
- Below, a bottom-sheet style panel with a large top radius, light grey surface. Title (about 22 px), grey explanatory text of two lines.
- Inside it, a white card with an orange line chart: dashed light grid, vertical dashed guides, round markers with a halo. Value labels in rounded tags: the selected/latest point is a solid orange tag with white text; the others are light peach tags with orange text.
- The image is cropped; axis labels and anything below the chart are not visible.

### success and other.png (two phones)
Left, "Appointment" confirmation:
- Close (X) rounded-square button on the left, centred title.
- A green filled circle with a check, a large bold heading ("You're booked in"), grey one-line subtitle. Centred layout.
- A grey bottom sheet with a drag handle. Row: avatar, name, role, and a green "Confirmed" pill. Key-value rows (Date, Time, Visit cost), label on the left, value right-aligned, hairline dividers. A secondary detail inline in lighter grey ("45 min").
- Two pill buttons side by side: primary lime/yellow-green fill with icon + label, secondary light grey fill with icon + label. Same height, large radius.
- A white card below: title, a "1 of 3" count chip, a striped green progress bar (solid fill part + diagonal hatch for the remaining part), a checklist row with a check circle, title, grey sub-line and an "Edit" text link.

Right, "Profile":
- Back button left, menu button right, centred title.
- Centred round avatar, large name, a grey meta line with a dot separator.
- Section title "My Info". A vertical list of cards: icon in a small white rounded-square tile, title (medium), grey sub-line, an arrow-up-right icon on the right. Cards are light grey translucent, radius about 20 px.
- Section "Appointment History" with a "View All" text link at the right. A card with a title and a green "Confirmed" pill, then a row (avatar, name, date).
- The floating bottom navigation (same as home.png) overlaps the lower content with a translucent surface.

### bottom_navigation.png
- A dark (near-black) floating pill with 4 circular items, on a white screen. Active item: white circle with a dark outline icon and a small lime dot at its top-right corner (a badge/indicator). Inactive items: dark-grey circles with light-grey outline icons. Icons (observed shapes): house, monitor/screen, note/sticker, hexagon with a dot. No text labels. The home indicator bar sits below.
- This is a dark variant of the nav in home.png; the two files do not show the same nav style.

### registration.png
- Gradient at the top: peach/orange fading into an off-white background in the first third. The rest is flat off-white.
- Brand logo centred at the top (proprietary; not to be used).
- Heading, bold, about 22-24 px, two lines, left-aligned; grey two-line subtitle.
- Field label "Email" (bold, small), above a pill-shaped input with a leading envelope icon, grey placeholder, soft inset look. An orange circle on the right edge is a screen-recording touch indicator, not a UI element.
- Helper text under the input, small grey.
- A divider with the word "Or" in the middle.
- Two full-width pill buttons "Continue with Google" / "Continue with Apple", very light peach-tinted fill, provider icon on the left, centred label.
- At the bottom: legal text, small, with orange links ("User Agreement", "Privacy Policy"), then a full-width pill "Continue" in disabled grey (grey fill, white text) pinned to the bottom.
- Accent colour on this screen: orange, not lime.
- No password field is shown: the flow is email + 6-digit code, or social login.

### code verify.png
- Same gradient and off-white background. A round back button at the left, centred brand logo.
- Heading "Verify your email", grey explanatory text with a masked email.
- Six separate rounded code boxes in one row. The first is focused: orange border and a text cursor. Others are plain, light.
- Under the boxes, centred "Didn't get the code?" with a bold countdown timer (1:25).
- Full-width disabled grey "Continue" pill above the system numeric keypad. The keypad is the OS keyboard.
- A large empty area between the boxes and the button. The orange dot at the right edge is again a touch indicator.

### 1b. Added files

#### extra-1.png (crop of the booking sheet, same content as the left phone in "success and other.png", at higher zoom)
Observed:
- Row: rounded-square portrait, name, grey role, green "Confirmed" pill. Hairline divider under it.
- Key-value rows (Date, Time, Visit cost) with right-aligned values; the secondary detail "(45 min)" in lighter grey; "Pay after visit" as plain text next to the price.
- Primary lime pill button with a calendar icon and bold label; secondary light-grey pill with a refresh icon. The lime button is wider than the secondary one (about 55/45).
- White card with a large top radius: title, "1 of 3" chip, progress bar with a solid light-green part and a diagonal-hatch part for the remainder, checklist row with a check in a rounded-square tile, title, grey sub-line "4 questions answered", and an "Edit" text link at the right. A second row is cut off.
- Confirms the detail level only; no new screen.
Assumption: the hatch means "not yet done"; the second checklist row is unchecked (its tile is empty, but it is cropped).

#### extra-2.png (doctor profile screen, top part)
Observed:
- Top row: rounded-square back button at the left; two rounded-square icon buttons at the right (calendar and chat), each with a small red dot badge in the corner.
- A rating pill (star icon + "5.0 Rating") in a translucent grey chip.
- Large name in two lines (about 48-52 px, medium weight, near-black), grey role below, left-aligned. A cut-out portrait on the right half, fading at the bottom into the sheet below (no card around it; the image blends into the background).
- A grey translucent sheet with a large top radius: title "Patient Status", "View All" link at right; three labelled stats with different widths proportional-looking to the values: a large green pill "464" (label "Recovered Patients"), a white pill "12" ("In Care"), and a hatched circle-like pill "8" ("Free"). Thin vertical hairlines separate the columns.
- A white card starting below: "Select Date" with a month switcher (chevrons and "April"). Cut off.
Assumptions: pill widths are proportional to the values (looks so, not stated); the hatch fill marks the "free/available" state; red dots mean unread/new items; the cut-out photo is a separate image layer.

## 2. Summary of the visual language (observed, then assumptions marked)

Composition: one column, one primary idea per block, generous whitespace, large rounded containers stacked vertically, content sitting directly on a soft gradient background.

Palette and proportions (approx.):
- About 80-85 percent neutral: light grey-to-off-white gradient background, translucent light-grey and white cards, near-black text, mid-grey secondary text.
- About 10 percent accent that signals action or success: lime/yellow-green (primary buttons, arrow buttons, active dot), soft green (Confirmed pill, progress), orange (chart line, focus ring, links on the finance screens), peach (warning/insufficient pill).
- Status/range colours are pastel: red, peach, green, blue.
- Black is used for the dark nav variant and for headline text, never for large fills except the nav.

Typography:
- One geometric/grotesque sans family (looks like a modern neo-grotesque; the exact font is unknown). Regular and medium weights dominate; bold appears in headings on the finance screens.
- Hierarchy by size and by tone (black vs grey), not by many weights. Two-tone headlines are a signature.
- Sizes (approx.): greeting 34-36, big metric 56-60, screen title 17-18, section title 20-22, card title 18-20, body 14-16, caption 12-13.

Grid and spacing:
- Side padding about 24-28 px on the phone mock (about 7 percent of the width). Card inner padding 20-24 px. Vertical gaps between blocks 24-32 px.
- Cards almost touch the screen edge only when they are carousels or bottom sheets.

Shapes, borders, shadows:
- Radius is large everywhere: cards 28-32, list cards about 20, buttons and inputs fully pill, icon buttons rounded-square (radius about 16-18), chips fully pill.
- No visible strokes on most cards; separation is by tint difference. Hairline dividers only inside key-value lists. Dashed lines only in charts.
- Shadows are almost absent (flat, translucent layers). Depth is made by stacking, translucency/frosted overlays and overlap.

Header and navigation:
- No filled top bar. Top controls are floating rounded-square or pill buttons over the background; title is centred and small on inner screens, absent on home.
- Back/close on the left, menu on the right.
- Bottom navigation: floating pill, 4 items, icon-only, active item highlighted by a white tile (light variant) or a white circle with a dot (dark variant).

Buttons and inputs:
- Primary: lime fill, dark text, pill, with leading icon. Secondary: light-grey fill, same size. Disabled: flat grey with white text, full width.
- Icon-only action buttons: rounded squares; the arrow-up-right means "open".
- Inputs: pill with a leading icon, soft fill, label above, helper text below, focus shown by an orange border. OTP: separate boxes.

Icons and images:
- Thin outline icons of one stroke weight; the active nav icon is filled. Icons usually sit in a rounded tile.
- Photos are portraits that fill a card; people are shown with avatars everywhere. In ARTA the equivalent is a material photo.
- Illustrations: only a logo and a check in a circle; no spot illustrations are visible.

Interaction patterns:
- Confirmation by a full screen: a green check circle, a big heading, a one-line explanation, then a summary sheet and next actions.
- Status is always shown as a text pill with a colour (Confirmed, Insufficient).
- Progress is a bar plus a count chip ("1 of 3") plus a checklist.
- Details are in bottom sheets with a drag handle.
- Primary action is pinned at the bottom of form screens; disabled until valid.
- Resend timer for codes; helper text for what will happen.
- Transitions are not visible in static images.

## 3. Assumptions (not visible, marked)

- A1. The gradient is two to three soft colour blobs on a light base, and a light mode only exists. Dark mode is not shown (the dark nav is a component variant, not a theme).
- A2. The frosted panel on photos and the translucent nav use background blur. On Flutter web, blur can be costly; ARTA may use a semi-opaque fill without blur as the fallback.
- A3. The carousel scrolls horizontally with snap; the stacked card likely collapses/expands on swipe. Not confirmed by the images.
- A4. Transitions: the stacked card, bottom sheet and the confirmation screen suggest slide-up sheets and a fade for the success screen. This is an inference.
- A5. The nav items in the references do not map to ARTA; the icons' meaning (monitor, note, hexagon) is unclear, so the ARTA tab set needs to be defined separately.
- A6. The lime accent and the orange accent come from different apps and may not belong to one system. ARTA must pick one primary accent.
- A7. Contrast of grey-on-grey text (captions on the grey background, white text on the disabled grey button) looks low. This is an estimate by eye, not a measurement; it must be checked against WCAG before copying.
- A8. Touch-target size cannot be measured from the images; icon buttons look about 44-56 px on the mock.
- A9. Desktop/laptop layout is not shown at all; all references are phone-only.

## 4. File to decision table

| File | What it shows | Decisions for ARTA |
| --- | --- | --- |
| home.png | Greeting, stacked priority card, section with search/filter, photo carousel, floating nav | Dashboard starts with a two-tone greeting using the organisation name. One priority card (for example the next required action such as "confirm characteristics" or "pending requests"), not a metric wall. Catalog uses photo cards with an overlay panel (name, type, kg) and an "open" arrow button; the material photo replaces the portrait. Search and filter are two icon buttons next to the section title. Floating pill nav, icon-only in the reference; ARTA adds a visible text label or screen-reader label (see accessibility). |
| statistic.png | Big metric with unit, status pill, range bar, sheet with a chart | Metrics show the number large with the unit (kg, KGS) small. Every metric gets a text label and a status pill that says "ожидается", "демо", "подтверждено" (never colour only). The range bar pattern can show reuse/distribution split, but only with real data; the chart must label forecast vs actual lines differently (dashed vs solid). No made-up values in mockups. |
| success and other.png (left) | Success screen, summary sheet, two buttons, progress checklist | Use the same sequence for confirmed reservation, transfer, receipt. Heading + one-line explanation + key-value summary (кг, цена KGS, дата) + primary/secondary action. Checklist with progress for "publish readiness" (photo, type, mass, condition, city, confirmation). Status pills for reservation states. Success never implies payment: no payment copy. |
| success and other.png (right) | Profile with centred identity and a list of link cards, history with "View All" | Profile (organisation) as a centred header + list cards (Организация, Контакты, Роль). History blocks truncate with "Все". Link cards use icon tile + title + sub-line + arrow. |
| bottom_navigation.png | Dark pill nav variant with a dot badge | Decide one nav style (light or dark). The dot badge can mark new requests/pending work and must also have a text/number alternative. Four items fit ARTA only if the tabs are limited (see section 6). |
| registration.png | Heading, subtitle, one pill field, divider, social buttons, legal text, disabled pinned button | Registration/login: heading + subtitle + labelled pill fields + pinned primary button. Disabled button state is shown until valid, with the reason in helper text. Social login buttons are not used (no such integration in the MVP). The reference flow is email+code; CLAUDE.md requires email + password, so the code step is not copied; open question. Role selection (enterprise / buyer / recycler) needs its own control; it is not in the reference. |
| code verify.png | OTP boxes, resend timer, disabled continue over the OS keypad | Not needed for MVP (no code login in CLAUDE.md section 4/9). The patterns that transfer: focus ring on the active field, helper text, a timer with a text label, a disabled button above the keyboard. Layout must keep the primary button visible when the keyboard is open. |
| extra-1.png | Booking summary sheet, paired buttons, hatched progress bar, checklist with Edit | Reinforces the success summary and the publish-readiness checklist (done = check tile, remaining = hatched/empty). Use "Изменить" links per checklist row. Hatch pattern is a good non-colour marker for "ожидается / не завершено" (pattern plus label). |
| extra-2.png | Detail screen: hero name + cut-out photo, badge dots on icon buttons, three proportional stat pills, month switcher | Material card: large name/title left, photo right fading into a sheet. Three stat pills for kg split could show "свободно / зарезервировано / передано" with a text label and the number inside each pill; pill widths proportional only if the data are real and the values are labelled (no decoration). Hatched pill for non-actual or free values. Badge dots on icon buttons for new requests, with a count in the accessible name. Rating pill has no ARTA equivalent: do not invent ratings. Calendar/month switcher is not needed in MVP. |

## 5. Repeating patterns across the references (summary)

1. Soft gradient background with translucent, large-radius surfaces; depth through tint and overlap, almost no shadows.
2. Very large radii and pill shapes for all interactive controls; rounded-square tiles for icon buttons.
3. Neutral palette with one saturated action colour (lime) plus pastel status colours; status always as a text pill.
4. Two-tone headlines and a big-number-with-small-unit pattern; hierarchy through size and grey/black tone.
5. Floating icon-only bottom nav with four items and a distinct active tile; top bar without a background, back/close on the left, menu on the right, centred small title.
6. Bottom sheets with a drag handle for details; key-value rows with hairline dividers; primary and secondary pill buttons paired side by side.
7. Confirmation as a dedicated screen: check circle, big heading, one-line reason, summary, next actions; progress as bar + count + checklist.
8. Low density with one block per idea, photo-led cards, a primary action disabled until the form is valid and pinned at the bottom.

9. (added from extra-1/extra-2) Non-colour state markers: diagonal hatch fill for "remaining/free" parts (progress bar, stat pill), solid fill for done/actual, with a text label or number. Corner dot badges on icon buttons mark new items.
10. (added from extra-2) Stat triplets as labelled pills with different fills (solid green, white, hatched) in one row under a section title with a "View All" link.

Pattern list change: patterns 1-8 are unchanged; 9 and 10 are new (from extra-2.png; extra-1.png only confirms existing patterns 6, 7 and adds the hatch detail).

## 6. Constraints that follow for ARTA (design direction, not final spec)

- Keep: gradient surface, radius scale, pill controls, pastel status pills, bottom floating nav on phone, success pattern, photo-led catalog cards.
- Change: ARTA is a business tool for three roles; it needs text labels for nav and status (references use icons and colour alone in places), a role-specific tab set, and a laptop layout (side rail or top nav instead of the floating pill; not shown in the references).
- Do not copy: logos, mascots, portraits, Google/Apple buttons, medical, appointment and finance content, exact layouts.
- Forecast, demo, confirmed and suggested values need their own visible labels; the references' range bar and chart style must not make forecasts look like facts.
- Server rules (role, ownership, stock) are not weakened by any pinned or disabled button; UI states only reflect them.

## 7. Open questions

| Question | Who answers |
| --- | --- |
| What do the two unopened screenshots show? Rename them to ASCII and resend. | Customer / orchestrator |
| Which single accent colour: lime or orange? | Customer, ux-designer |
| Light nav or dark nav? Is icon-only acceptable given accessibility needs? | Customer, ux-designer |
| Is a code (OTP) step wanted at all? CLAUDE.md specifies email + password. | Product owner |
| Which tabs for each role in the bottom nav (max 4-5)? | ux-designer with product owner |
| Is background blur acceptable for Flutter web performance? | frontend engineer |
| Font choice that supports Cyrillic and matches the neo-grotesque look. | ux-designer, frontend engineer |
| Contrast and touch-target measurements for the final palette. | ux-designer (accessibility.md) |
