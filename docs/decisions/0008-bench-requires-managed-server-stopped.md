# 0008 — `make bench` runs only with the managed model server explicitly stopped

- **Status:** Accepted; amended by [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (Accepted; in effect since item 60's cut-over on 2026-10-03: "the managed server" means either managed unit, `ai-sdlc-llama-server` or `ai-sdlc-gufo-server`; the bench refuses while either is not inactive, which item 60's PR 1 already enforces)
- **Item:** 23 (implemented in 23.1) · **Date:** 2026-09-21 · **Origin:**
  default (put to no one; one line to override)

## Context

Item 22 made the model server a systemd `--user` unit (`ai-sdlc-llama-server`)
with `Restart=always` and `RestartSec=30`, enabled at boot through lingering
([ADR 0007](0007-pinned-serving-configuration.md)). Item 10's `make bench`
predates it, and assumes it owns the box. The two now share three things:

1. **The port.** `BENCH_PORT` defaults to 18080 (`bench_lib.sh`), and so does
   `SERVE_PORT` (`serving.env`). With the unit up, `measure.sh` refuses every
   config as `port-busy:18080`. The refusal is correct, but it happens one
   config at a time: a campaign produces a results directory of refusals rather
   than failing before it starts.
2. **The memory pool.** The pinned configuration holds ~68 GiB of GTT at 32k.
   Item 13's 262k point used 76 GiB of the 110 GiB pool and **still** hit
   the host swap guard. Two servers can't both fit, and a bench's GTT and host-RAM
   baselines, taken before its own server starts, are wrong if the unit
   loads while the bench runs.
3. **The cold-boot window.** Item 22 T7 saw the unit start before ROCm could
   see the GPU. It failed, and `Restart=always` retried 30 s later. During that
   gap the port is free and no `llama-server` is running, so every existing
   check passes, and then the unit comes back mid-run. Nothing today catches
   this.

Item 23 is the first campaign that needs the whole box on purpose: long,
attended runs at 131k–262k. It will not be the last (20, 21 and 12 all measure
on this host).

## Decision

- **The bench preflight refuses to start** while the managed unit is in any
  state other than explicitly stopped. That means `systemctl --user is-active
  ai-sdlc-llama-server` is not `inactive`, **including `activating` and the
  auto-restart wait**. The refusal names the fix (`make serve-down`). It
  happens once, before the plan is printed, not per config. When no unit is
  installed, or `systemctl --user` is unavailable (CI, macOS), the check is
  skipped and the existing port check stands.
- **Ownership is explicit and one-directional.** The bench never stops or
  starts the unit itself. The operator stops it with `make serve-down`, and
  restores it with `make serve-up` followed by `make serve-check`, which
  must be green on its `pin`, `binary` and `live` blocks. An automated
  stop would hide the cost: every agent session is offline for the
  length of the campaign.
- **Co-resident memory is recorded, not assumed.** The preflight writes the
  RSS of the Langfuse stack and of any other `llama-server` into the scan's
  host record, so a later reader can tell what else was holding host RAM.
- **Proven offline.** `bench-selftest` covers each unit state (inactive,
  active, activating, auto-restart, no unit, no systemd) with a stubbed
  `systemctl`. No real unit, no network, no localhost.

## Consequences

- A campaign on the serving host costs a planned outage of agent traffic.
  It is announced, not discovered as a 180 s timeout.
- The cold-boot race can no longer contaminate a measurement. It is still
  a startup-ordering defect in the unit (item 22 T7's two suggested fixes:
  read the `version:` line, and fail explicitly when no ROCm device is
  visible). That remains item 22's follow-up, not this ADR's.
- Moving `BENCH_PORT` off 18080 was considered and rejected. It would let
  both servers start and fight over memory, which is worse than the refusal.
- Hosts without the unit behave exactly as before. Every existing
  `bench-selftest` fixture verdict is unchanged.
