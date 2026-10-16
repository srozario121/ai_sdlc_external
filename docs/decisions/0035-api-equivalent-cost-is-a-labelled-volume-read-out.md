# 0035 — An API-equivalent cost is a labelled volume read-out from dated list prices, never a local token's cost and never a capability comparison

- **Status:** Accepted (2026-10-08). Item 64's plan-review wrote it; the
  user accepted it as drafted on 2026-10-08 (item 64's Q5), and answered
  Q1 (the read-out in the evidence script and harness-observability §5
  only) and Q2 (Max plans described, not converted) with the recommended
  option.
- **Item:** 64 · **Date:** 2026-10-08 · **Origin:** user (Q5 the ADR, Q1 the
  read-out's home, Q2 rule 5) · default (rules 1–4 and 6; raised by the
  user's 2026-10-08 question comparing the box's throughput
  with Claude Max 5x/20x and Opus 5 / 5.5 API prices).
- **Applies to:** `scripts/langfuse/local-pricing.tsv` and
  `scripts/langfuse/adapters/local_pricing.py` (item 21), the run-comparison
  report's cost column (`scripts/report/`, item 66), the LAN gateway's
  dashboards (items 67 and 67.2), `docs/evaluation/harness-observability/`
  §5, and any later item that sets the box's output against a hosted
  model's price.
- **Builds on:** [0007](0007-pinned-serving-configuration.md) (a cost belongs to a
  `config_hash`), [0016](0016-held-out-instances-never-tracked.md)
  (aggregates only), [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (the managed engine).

## Context

1. **A local token's cost is energy.** Item 21 converts the measured
   throughput and the measured SoC power into a per-token energy cost, at
   the serving configuration's own rows. Traces record `cost_model: energy`,
   and the report's $ column uses the same model.
2. **The user asked a different question:** what the box's token volume
   would cost at Claude list prices, and how that compares with a Max plan.
   One hour of the pin's single-stream agent traffic at the measured rates
   (2,323 tok/s input, 97.7% cached; 26.2 tok/s output) is about $4.28 at
   Opus 5.5 list prices. The local energy for the same hour is about 2 p.
3. **The two numbers measure different things.** The API figure prices
   Qwen tokenizer tokens produced by a different model, which would take a
   different number of turns on the same task. Without a rule, the figure
   ends up in a cost column, where it reads as "the box saves $X" or "the
   box is worth Opus 5.5".
4. **List prices move, and subscription plans publish no per-token
   quota.** A hard-coded price goes stale silently, and a Max-plan "token
   equivalent" would be an invented number.

## Decision

1. **Two figures, kept apart.** A local token's cost stays item 21's
   energy model. An API-equivalent figure is never written into a trace's
   `cost` or `cost_pricing`, into the report's $ column, or into any field
   named as a cost of the local run.
2. **The label is mandatory.** Every API-equivalent figure, in a doc, a
   JSON file or a dashboard, carries: *"volume equivalence at list prices
   of <date>: what this many tokens would be billed, not a capability or
   quality comparison"*. The doc beside it states that the tokens are the
   local model's tokenizer's, and that reasoning tokens count as output.
3. **Prices come from one dated, sourced table**,
   `scripts/langfuse/api-reference-prices.tsv`: model, input, output,
   cache read, cache write, the date checked and the source. A price is
   never hard-coded, and a missing price leaves that part unpriced, never
   guessed. A read-out older than 90 days against its price date says so.
4. **The token mix is the measured one.** Cached input is priced at the
   cache-read price and uncached input at base input. A cache-write
   sensitivity line sits beside it, and output (reasoning included) is
   priced at the output price.
5. **No subscription conversion.** A plan with no published per-token
   quota (Claude Max 5x/20x) is described, not converted, unless the user
   supplies a figure. That figure is then labelled as the user's.
6. **A new surface for the read-out** (a report column or a dashboard
   panel) is its own change under these rules. It never reuses a cost
   field.

## Consequences

- The box's cost story has two clearly separated numbers: what the
  electricity cost, and what the same volume would have been billed.
  Neither can be mistaken for the other.
- Item 64 delivers the first read-out, in harness-observability §5 and
  `api-equivalent.json`. Items 66 and 67.2 may add it later, labelled, as
  a separate field.
- Re-checking prices is a manual dated step. A stale table is visible from
  its date, and is never silently wrong about when it was right.
- The read-out answers "how much volume", never "which is better". A
  capability comparison needs its own pre-registered evaluation.
