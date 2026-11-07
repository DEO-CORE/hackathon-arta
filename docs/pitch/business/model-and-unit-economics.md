# Model and unit economics

Rule: every input is empty (`___`) and labelled to-validate unless a register ID gives an assumption. No value below is a fact.

## Model

Verified (`CLAUDE.md` §2): the 5% commission is a business hypothesis for the pitch. The MVP does not include online payments, bank integration or a payment module. Therefore the commission is not collected by the product; it is a model for the pitch only.

| Option | Description | Depends on volume | Label / ID |
|---|---|---|---|
| M1 Commission | Rate r on the recorded value of completed sales (revenue field in analytics is a deal amount, not a bank reconciliation, `CLAUDE.md` §10) | Yes | assumption A-08 (r = 5%, hypothesis) |
| M2 Subscription | Fixed monthly fee for enterprises | No | to-validate A-19 |
| M3 Managed-matching fee | Fee per manually assisted deal during cold start | Per deal | to-validate A-19 |

Off-platform risk: with no payment in the product, parties can agree and settle outside; the commission may leak (A-08).

## Formulas

- Revenue per transaction = r x S, where S = sale amount of a transaction (KGS), r = commission rate.
- S = price per kg x transferred kg.
- Contribution per transaction = r x S - cost to serve per transaction.
- Break-even transactions per month = fixed monthly cost / contribution per transaction.
- Sensitivity to r: contribution is linear in r; break-even volume scales as 1 / (r x S - variable cost). Report break-even for r in a range, e.g. 3%, 5%, 8% (the range itself is an assumption).

## Inputs (empty until validated)

| Input | Symbol | Unit | Value | Label | ID |
|---|---|---|---|---|---|
| Price per kg of offcuts | p | KGS/kg | ___ | to-validate | A-10 |
| Typical lot size | q | kg | ___ | to-validate | A-05 |
| Commission rate | r | % | 5 (hypothesis) | assumption | A-08 |
| Delivery cost per kg | d | KGS/kg | ___ | to-validate | A-14 |
| Hosting per month | H | KGS/month | ___ | to-validate | A-20 |
| AI vision call cost per analysis | a | KGS | ___ | to-validate | A-20 |
| AI analyses per transaction | n | count | ___ | to-validate | A-20 |
| Support and onboarding time per deal | t | hours | ___ | to-validate | A-20 |
| Cost of staff time | w | KGS/hour | ___ | to-validate | A-20 |
| Share of listings that sell | s | % | ___ | to-validate | A-21 |

## Unit economics table (recalculate when inputs are filled)

| Line | Formula | Value | Label |
|---|---|---|---|
| Sale amount S | p x q | ___ | to-validate |
| Revenue per transaction | r x S | ___ | to-validate |
| AI cost per transaction | a x n / s (analyses on listings that do not sell are borne by the sold ones) | ___ | to-validate |
| Support cost per transaction | t x w | ___ | to-validate |
| Hosting per transaction | H / transactions per month | ___ | to-validate |
| Cost to serve per transaction | sum of the three above | ___ | to-validate |
| Contribution per transaction | revenue - cost to serve | ___ | to-validate |
| Contribution margin | contribution / revenue | ___ | to-validate |
| Break-even transactions per month | H / (contribution before hosting) | ___ | to-validate |

Delivery cost d is borne by the parties and does not enter ARTA's cost, unless ARTA arranges it (not in MVP scope); it still matters to the buyer's net price and therefore to p.

## Sensitivity table (fill when inputs exist)

| r | Revenue per transaction | Break-even transactions per month |
|---|---|---|
| 3% | ___ | ___ |
| 5% | ___ | ___ |
| 8% | ___ | ___ |

## Cold start

Chicken-and-egg risk: buyers need supply, sellers need buyers. All mitigations are assumptions until tested.

| Mitigation | Label / ID |
|---|---|
| Seed the seller side first by hand-onboarding a few enterprises and listing their lots | assumption A-18 |
| Managed matching: the team contacts buyers for each listing in the first weeks | assumption A-18 |
| A recycler as the buyer of last resort for remainders | assumption A-13 |

Not stated: any TAM/SAM/SOM. Sizing needs counts of enterprises and volumes (A-05, A-17), which do not exist yet; the formula would be enterprises x kg per month x price x r, with every input to-validate.
