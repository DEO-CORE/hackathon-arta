# Journeys

Status: draft, `[PROVISIONAL]` until CON-01. Maps to the MVP path in CLAUDE.md §2.

## J1 Enterprise (textile business)

| Step | Screen | Action | System response | Error case |
|---|---|---|---|---|
| 1 | S01 | Register as enterprise, log in | Redirect to S02 | 401 wrong credentials; 422 field errors; email taken |
| 2 | S04 | Create draft: name, type, mass (кг), condition, city; optional price/кг, composition | Draft saved (no photo needed) | 422; 409 stale version |
| 3 | S04 | Upload 1-5 photos | Progress per file, thumbnails | wrong format, >10 MB, limit of 5, network failure with retry |
| 4 | S06 | Start AI analysis | Pending -> result (suggestions) | AI failed / unavailable: manual path stays open |
| 5 | S06 | Review suggestions, edit fields, press "Подтвердить характеристики" | Fields marked confirmed with author/time | 409 stale analysis (material changed); 403 |
| 6 | S05 | Publish (needs photo, type, mass>0, condition, city, confirmation) | Status becomes "Доступна" | 422 missing items listed; 409 |
| 7 | S07 | Open matching | Compatible buyers with score and reasons; excluded ones with reasons | none found (empty state) |
| 8 | S08 | Run allocation plan | Three directions, expected net value, remainder, baseline comparison | infeasible / timeout / error; outdated inputs -> recalc prompt |
| 9 | S09 | Review incoming requests; confirm reserve; mark transferred | Held mass changes, then transferred | 409 insufficient stock/demand; 403 |
| 10 | S05 | Record internal use | Mass moves to internally used | 409 exceeds free mass |
| 11 | S02 | Read analytics | Forecast, distributed, confirmed reuse shown separately | empty dataset |

## J2 Buyer (workshop)

| Step | Screen | Action | Response | Error |
|---|---|---|---|---|
| 1 | S01 | Register as buyer | S02 | as J1 |
| 2 | S10 | Create requirement: types, conditions, min/max кг, budget KGS/кг, city, uses | Saved, active | 422 (min_kg > max_kg) |
| 3 | S03 | Browse published materials | List with published fields only | empty, 403 |
| 4 | S05 | Open card, enter quantity (кг), "Подать заявку" | Request "Ожидает" | 409 quantity > available; duplicate press ignored |
| 5 | S09 | Track request status | Pending, confirmed, transferred | cancelled by seller (reason shown) |
| 6 | S09 | "Подтвердить получение" after transfer | Completed | 409 wrong state |
| 7 | S09 | "Подтвердить использование" (separate action, kg) | Confirmed reuse recorded | 409 exceeds transferred kg |

## J3 Recycler

Same as J2 with the organization activity category `recycler`; the role is `buyer`. S10 default uses may include recycling; no extra screens. Profile (S11) shows the category read-only after registration `[PROVISIONAL]`.

## Open questions

- Can a buyer edit activity category after registration? (backend-engineer)
- Is cancel reason mandatory for the seller? (backend-engineer)
