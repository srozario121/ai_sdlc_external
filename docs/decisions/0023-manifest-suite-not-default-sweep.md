# 0023 — A suite may sit in the coding-bench manifest without joining the default sweep; the composite's denominator is the default sweep, and the scorecard names it

- **Status:** Accepted
- **Item:** 37.1 · **Date:** 2026-10-02 · **Origin:** default (recommended by
  the 2026-09-23 plan-review of items 37 and 37.1; no user was reachable, so it
  is tagged for override)

## Context

Item 12's coding benchmark had one list of suites,
`HARNESS_BENCH_SUITES_ALL` in `scripts/harness/harness_lib.sh`. It did three
jobs at once:

1. It was the **manifest**: the suites `HARNESS_BENCH_SUITES` may name, and the
   suites `make coding-bench-selftest` covers (adapter, pinned subsets, mock).
2. It was the **default sweep**: what `make coding-bench` runs when nothing is
   named.
3. Through the default sweep, it set the **composite's denominator**.
   `bench_report.sh` computes coverage over the suites a run emitted rows for,
   and a configuration under 50 % coverage, or with an `infeasible` agentic
   suite, is excluded from the ranking.

Item 37 adds SWE-bench Pro V2 as a second **agentic** suite. It needs the
manifest: an adapter, pinned subsets and a mock that the selftest checks. If it
also joined the default sweep, every unnamed run would add Pro cells. On a box
where Harbor is not installed those cells are `infeasible (runner-absent)`.
That would break item 12's published scorecard in two ways:

- every configuration would gain an infeasible agentic suite, which is a
  ranking exclusion;
- a configuration measured before Pro existed would have no Pro rows at all,
  so its coverage would no longer be comparable with one measured after.

Together these would un-rank a published frontier. No configuration would have
changed. Only the list would have.

The question of whether Pro *belongs* in the composite is real, but it is item
39's question ("which suites earn their place"), and it needs Pro's measured
cost per point first. Registering a suite must not answer it by accident.

## Decision

1. **Two lists, two jobs.**
   - `HARNESS_BENCH_SUITES_ALL` is the **manifest**: every suite with a
     `suites.tsv` row and an adapter. `HARNESS_BENCH_SUITES` may name any of
     them, and the selftest covers all of them.
   - `HARNESS_BENCH_SUITES_DEFAULT` is the **default sweep**: what runs when
     `HARNESS_BENCH_SUITES` is unset. It is the v1 five: `swe-bench-lite`,
     `humanevalplus`, `mbppplus`, `livecodebench` and `bigcodebench-hard`.
2. **The composite's denominator is the default sweep.** A scorecard built from
   a run that named extra suites shows those columns. The ranking a reader
   compares across runs is the default sweep's, and the scorecard names the
   suites it was computed over.
3. **A suite joins the default sweep only by a decision recorded against this
   ADR**, not as a side effect of being added to the manifest. Item 39 makes
   that decision for SWE-bench Pro.
4. **The selftest holds the line.** `make coding-bench-selftest` fails if:
   - the default sweep is anything other than the five;
   - `swe-bench-pro` appears in it;
   - the default dry-run's cell count moves.

   The same run also proves that a run naming Pro still dry-runs from its mock.

## Consequences

- Adding a suite to the manifest leaves every existing scorecard,
  fixture verdict and matrix cell count byte-identical. Item 37.1 checked this
  directly: on `main` and on its branch, the default smoke dry run produces
  the same 30 cells and the same 130 rows. All six committed bench-row files
  also re-render to the same scorecard.
- A manifest-only suite costs nothing until someone names it. Pro runs only
  as `HARNESS_BENCH_SUITES=swe-bench-pro`.
- There are now two lists to keep in step. The selftest checks the default
  against a literal, so a change to either list is visible in review.
- `bench_report.sh` still orders columns by the manifest, so a run that names
  Pro shows its column after the v1 five, in a stable place.
