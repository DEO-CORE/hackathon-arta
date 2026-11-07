# ARTA business analysis (PIT-01)

Status: draft, 2026-11-06. Owner: business-analyst. Task USR-03 (real facts from the user) is open.

## What is verified here

Verified (source: `CLAUDE.md` §2, §10, product scope; the repository, 2026-11-06):
- ARTA's product scope, roles (enterprise, buyer, recycler as a buyer category) and MVP path.
- Mass is in kg, money in KGS.
- The 5% commission is a business hypothesis for the pitch, not a payments feature (`CLAUDE.md` §2). The MVP has no online payment module.
- Analytics keeps forecast, transfer and confirmed reuse separate (`CLAUDE.md` §10).

## What is not verified

Nothing about the market. No interviews, pilots, partners, volumes, prices, delivery costs, company counts, TAM/SAM/SOM, revenue or letters of intent exist in the repository or were supplied by the user. Every such point is an assumption or to-validate. Nothing here is a fact about Kyrgyzstan's textile sector.

## Label rule

| Label | Meaning | Required next to it |
|---|---|---|
| verified | Backed by a named source and date | Source path or URL, date |
| assumption | Reasoned guess used so the model can be built | Register ID (A-xx) and reasoning |
| to-validate | Unknown; needs interviews or data. Fields stay empty | Register ID and validation method |

Rules:
1. A number without a label is a defect.
2. A to-validate field is left empty (`___`); do not fill it with an illustrative value.
3. Environmental figures (CO2, waste tonnage) are out of scope here; impact-analyst owns them.
4. The pitch may only quote a figure as verified if a source file exists in the repository.

## Files

- `problem-and-segments.md` - problem hypotheses, segments, interview questions
- `competitors.md` - categories of alternatives to check
- `model-and-unit-economics.md` - model, formulas, empty unit-economics table
- `assumptions-register.md` - all assumptions (A-01 to A-20) and the top three decision-critical ones

## Deferred (not produced, because no inputs exist)

Market sizing (TAM/SAM/SOM) and go-to-market with a named first-20 list. They need data from interviews; see A-17 and A-18 in the register. Minimum validation before judging: 5 to 10 short interviews with sewing enterprises and workshops (see `problem-and-segments.md`).
