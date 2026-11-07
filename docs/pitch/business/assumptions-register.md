# Assumptions register

Total entries: 29 (A-22…A-25 from `market-data.md`; A-26…A-29 from `market-data-2.md`, added 2026-11-07). Labels: assumption or to-validate (nothing here is verified). Source "none" means no source exists in the repository or from the user (USR-03 open). Status: open for all.

| ID | Statement | Label | Source | How to validate | Owner | Status |
|---|---|---|---|---|---|---|
| A-01 | Sewing enterprises in Kyrgyzstan generate textile offcuts regularly | assumption | none (general reasoning about garment production) | Interview 3+ enterprises | business-analyst | open |
| A-02 | Offcuts are mostly discarded, stored or sold informally | to-validate | none | Interview: where does it go now | business-analyst | open |
| A-03 | Enterprises do not know who could buy their offcuts | assumption | none | Interview question on current buyers | business-analyst | open |
| A-04 | Disposal or storage has a cost (money, space) to the enterprise | to-validate | none | Ask for cost of disposal and storage | business-analyst | open |
| A-05 | Volume per enterprise (kg per month) and typical lot size | to-validate | none; value `___` | Ask for last month's kg | business-analyst | open |
| A-06 | Material mix is varied (fabric, piece size, colour) | to-validate | none | Photos and samples from interviews | business-analyst | open |
| A-07 | Enterprises will pay a share only when a real sale happens | assumption | none | Ask willingness to pay commission vs fixed fee | business-analyst | open |
| A-08 | Commission rate is 5% of completed sale value; some deals may leave the platform | assumption | `CLAUDE.md` §2 (stated as a hypothesis for the pitch, not a payments feature) | Test 3%, 5%, 8% in interviews; track off-platform settlement risk | business-analyst | open |
| A-09 | Workshops and small makers struggle to find cheap fabric in suitable type and size | assumption | none | Interview 3+ workshops | business-analyst | open |
| A-10 | Price per kg for offcuts that buyers pay | to-validate | none; value `___` | Ask current purchase price and offers received | business-analyst | open |
| A-11 | Recyclers need steady collected supply | assumption | none | Interview 1+ recycler | business-analyst | open |
| A-12 | Textile recyclers operate in Kyrgyzstan, and how many | to-validate | none; value `___` | Desk search and calls; record sources | business-analyst | open |
| A-13 | A recycler can take remainders as a buyer of last resort | assumption | none | Ask recycler minimum lot, price, pickup | business-analyst | open |
| A-14 | Delivery cost per kg and who arranges it | to-validate | none; value `___` | Ask for last delivery cost and distance; MVP uses explicit cost per kg (`CLAUDE.md` §7) | business-analyst | open |
| A-15 | Informal sellers, direct buyers and classifieds are the main current channels | to-validate | none | Search classifieds and groups; record URL and date | business-analyst | open |
| A-16 | Foreign B2B surplus marketplaces do not serve this local market | to-validate | none | Desk research with sources | business-analyst | open |
| A-17 | First target businesses can be reached; count of enterprises and workshops is known | to-validate | none; value `___` | Build a list from public directories and referrals; record the source | business-analyst | open |
| A-18 | Cold start can be solved by seeding sellers and managed matching | assumption | none | Run manual matching for 1 to 3 real lots | business-analyst | open |
| A-19 | Subscription or per-deal assisted fee is acceptable as an alternative to commission | to-validate | none | Ask in interviews | business-analyst | open |
| A-20 | Cost to serve (hosting, AI call, support, onboarding) per transaction | to-validate | none; values `___` (hosting and AI provider prices unchecked) | Take provider price lists with date; time one onboarding | business-analyst | open |
| A-21 | Share of listings that result in a sale | to-validate | none; value `___` | Pilot lots; count sold vs listed | business-analyst | open |
| A-22 | The only known recycler in the market (Mramornoe plant) already takes waste from ~40 Bishkek workshops and ~100 suppliers; ARTA must not claim to be the first recycling outlet | verified (secondary) | `docs/pitch/business/market-data.md` MD-18…MD-20 (Textile Space, Open.kg, 2025–2026) | Confirm contract scope and buying terms by interview with the plant | business-analyst | open |
| A-23 | National textile waste volume is unknown; Bishkek estimates range from 50 to 80 t/day | to-validate | `market-data.md` MD-15, MD-16 | Request Нацстатком / Минприроды data; pilot weighing at 5–10 workshops | business-analyst | open |
| A-24 | Number of sewing workshops is unknown: official ~200 enterprises vs government ~3 000 (likely incl. informal) | to-validate | `market-data.md` MD-04, MD-10 | Build list from directories and associations; record source per entry | business-analyst | open |
| A-26 | Textile and clothing are not in the 24-group utilisation fee list (RPO); if this holds, no regulatory obligation pushes producers to offcut recycling yet | to-validate | `market-data-2.md` MD-28, MD-29 (text of resolution 322 not opened) | Read resolution 322 on cbd.minjust.gov.kg or ask Eco Operator | business-analyst | open |
| A-27 | Cheap imported fabric (China) undercuts the value of offcut purchases for workshops | to-validate | `market-data-2.md` MD-55, MD-56; no KGS/kg price found | Collect current prices of imported fabric per kg from 3+ suppliers | business-analyst | open |
| A-28 | Enterprises are looking for export channels after the Russia slowdown; ARTA's value may include lower material cost, not only waste disposal | assumption | `market-data-2.md` MD-48, MD-49 | Ask exporting workshops about material purchase cost and waste | business-analyst | open |
| A-29 | Local classifieds (Lalafo) are where small sellers of offcuts already post; B2B-specific exchange is unserved | to-validate | `market-data-2.md` MD-42, MD-43; no B2B data found | Search Lalafo for offcut listings; record URL and date | business-analyst | open |
| A-25 | Sector is contracting in 2025–2026 (output −20% in Q1 2025 for textiles; order cancellations, closures) | secondary (may shift demand for offcuts) | `market-data.md` MD-08, MD-25 | Track monthly stats; ask workshops about current order volume | business-analyst | open |

## Top three assumptions that would change the decision if wrong

1. A-10 and A-05 together: price per kg and volume. If revenue per deal is too small, a 5% commission cannot cover cost to serve and the model must change to subscription or a different purpose.
2. A-02 and A-03: enterprises actually lack a good outlet today. If they already sell offcuts well, ARTA has little to add.
3. A-18 and A-17: cold start and reachability. If there are too few reachable buyers or sellers, matching cannot produce a first transaction.

Note: A-08 (off-platform leakage) is next in importance because the MVP has no payment module.
