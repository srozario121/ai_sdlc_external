# 0012 — Only a bit-exact serving change may be called lossless; a tie-equivalent one must be quality-measured before it is pinned

- **Status:** Accepted
- **Item:** 33.2 · **Date:** 2026-09-23 · **Origin:** user (drafted from item
  33.2's measurement as a default, then accepted by the maintainer)

> **Numbering.** `0009` is reserved by item 26's plan and `0011` by item 36's,
> neither delivered. This takes `0012` rather than claim either, the same way
> item 31 took `0010` while `0009` was already spoken for.

## Context

**"Lossless" has meant one thing and been used for two.**

Item 32 pre-registered a strict gate: a speculative configuration passes if
its greedy output is **byte-identical** to the no-speculation reference. That
gate disqualified every configuration whose verify is wider than 8 tokens —
which is every configuration reaching 1.1× or more on the edit prompt. Under
it the winner was `Bs2.pm50` at 1.095, and that verdict still stands as the
pre-registered one.

The rule was then amended three times (D1, D2, D3) after looking at what the
divergences actually were. `near_tie.py` measured them over 28 scans:

- the **edit prompt is byte-identical in every configuration**, including
  every failing one;
- the flips are **deterministic** and sit **inside the reasoning text** —
  " diverse" → " distinct";
- each is a token the reference model itself ranks **first under one of its
  own computation paths** (decode, prefill, cached, resume), or second by
  less than its own path-to-path noise at that token.

D3's rule is therefore: *a divergence is a tie if the unmodified server would
itself have produced that token under one of its normal batchings.* It has
teeth — it separated 2 configurations from the other 26 — and on it the pin
moved to `Bs1.sn8`, buying **2.7× on re-emitted text**.

**The unstated premise was that a tie is free.** If the model would have said
it anyway, the reasoning was, the answer cannot be worse. That premise had
never been measured. Item 33 was opened to measure it, and item 33.2 did.

**It is false, and the size of the error is now known.** Over 284 paired
instances (HumanEval+ 164, MBPP+ 120), both arms the same weights decoding
greedily, differing only in `serving.env`:

| | n | `Bs1.sn8` — tie-flipping | `Bs2.pm50` — bit-exact | Δ | b / c | exact McNemar |
|---|---|---|---|---|---|---|
| Pooled | 284 | 0.8979 | 0.9190 | **+0.0211** | **0 / 6** | **0.0312** |

The tie-flipping arm **never won a discordant pair**. The arms diverged
textually on **22.9 %** of instances, and conditional on divergence Δ is
**+0.0923**. The verdict was *non-inferior* — +2.1 points is inside the
5-point margin fixed before any generation — so the pin was kept. But the
flips are **cheap, not free**, and the pin is justified by "2.7× is worth 2.1
points", which is a trade, not an equivalence.

A second lesson came from the same run. The pre-registration's "harm shown"
clause was written as the interval lying **below** `−m` — arm B being worse —
while the question asked was whether arm A's flips cost quality, which is
`Δ > +m`. The sign was inverted for the question. It changed nothing at
Δ = +0.021, and it was recorded as an erratum rather than edited, because a
pre-registration is frozen once generation starts. It would have mattered had
the effect been larger.

## Decision

**Three tiers. Only the first may be called lossless.**

### 1. Bit-exact — *lossless*

Greedy output **byte-identical** to the no-speculation reference over the
coherence corpus, in every replicate.

No quality evidence is required, and none can be needed: both arms are the
same weights decoding greedily, so a deterministic grader **must** return the
same verdict on identical bytes. This is the only tier that may be described
as lossless, in a document, a commit message, a `note=` field or a table
column.

### 2. Tie-equivalent — *quality-equivalent at margin m*, never lossless

Every divergence passes D3's path-tie test, **and** a pre-registered paired
quality A/B has shown non-inferiority at a declared margin.

**The tie test is necessary and not sufficient.** This is the substantive
change. Item 32 pinned a configuration on the tie test alone; item 33.2
measured a directional, statistically detectable cost in exactly the
configuration that passed it. A configuration that is not bit-exact may
**not** be pinned on the tie test alone again.

Such a change must publish, beside its speed claim:

- the divergence rate `d` and the deterministic bound `|Δ| ≤ d`;
- pass@1 per arm, Δ with its interval;
- the discordant table `b`/`c` with an **exact** McNemar p;
- Δ conditional on divergence;
- the worst case the design could not exclude.

The phrase for tier 2 is **"quality-equivalent at margin m"**, with `m`
stated. Not "lossless", not "equivalent", not "no quality cost".

### 3. Everything else — *not equivalent*

Fails the tie test, or has no quality evidence. It may still be pinned, but
only as an explicit trade with both numbers stated.

### Two rules that apply to any such comparison

**Declare the direction.** A non-inferiority pre-registration states which arm
is the incumbent, the sign convention for Δ, and **which sign constitutes
harm**, in words, before any generation. Item 33.2's erratum is the reason.

**Publish the bound with the verdict.** A divergence-conditioned design bounds
what it could have missed. Item 33.2's bound was ±0.2289 against a measured
Δ of +0.0211 — the verdict is far more precise than the design's worst case,
and quoting one without the other overstates it.

## Consequences

- **Item 32's pin stands, and is now the only tier-2 configuration with its
  evidence.** Nothing in item 32's pre-registered verdict or its D1–D3
  deviations is edited by this ADR; they are the record of what was decided
  when, and this is the rule that succeeds them.
- **A future non-bit-exact serving change costs a measurement window** — a
  paired A/B on a declared instance list, which item 33.2 ran in about four
  hours per arm. That is the price of the claim, and it is deliberate.
- **The word "lossless" narrows.** Where the bench, `serving.env` or a scan
  currently labels a tie-equivalent configuration lossless, the label is
  wrong under this ADR and should be re-worded as tier 2 when next touched.
- **`near_tie.py` keeps its job** as the tier-2 entry test; it simply no
  longer ends the argument.
- **Scope stays with the evidence.** Item 33.2's verdict covers *graded
  short-form completion*. It does not cover agentic patch generation, where
  the flips live in reasoning text and the pin earns its speed; item 20.2 is
  where that is to be re-tested, and a tier-2 claim should say which suites
  it rests on.

## Alternatives considered

**Keep byte-exactness as the only gate.** Clean, and it is what item 32
pre-registered. Rejected: it would give up 2.7× on re-emitted text to buy 2.1
points of pass@1, on a box where decode is ~88 % of agent wall clock. The
strict winner `Bs2.pm50` remains published as the fallback for anyone who
wants tier 1.

**Tighten the tie test instead.** Calibrate δ against the path-to-path noise
band, or require argmax on *every* path rather than one. Rejected as a
sufficient answer: the flips that cost the 6 discordant pairs **already pass**
the tie test. A tighter test would reject more configurations without
establishing that the survivors are free — it would move the line, not
measure it.

**Treat ties as free (the status quo ante).** Rejected: directly contradicted
by `b = 0, c = 6`, p = 0.0312.

**Fold the quality A/B into the bench's lossless gate**, so a configuration
cannot be scored without one. Rejected for now as too expensive — the gate
runs per scan across dozens of configurations, and an A/B is a four-hour
window. The A/B belongs at the **pin** decision, not at every scan.
