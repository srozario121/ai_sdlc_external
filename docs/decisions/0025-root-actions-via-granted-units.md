# 0025 — A root action on the box runs only as a named, root-owned, guarded systemd unit that the user installs and grants per unit and verb

- **Status:** Proposed (item 59, PR 1, 2026-10-02). The user signs it when
  T11 closes the item.
- **Item:** 59 · **Date:** 2026-10-02 · **Origin:** user (the privilege
  model, Question 1a) · default (writing it as a cross-item rule)

## Context

Item 59 needs the repo's first root action: `swapoff` and `swapon` on the
serving box, at engine switches, before measurements and on a timer. Until
now the repo's units are all user units (items 22, 43), and agents work
without root. Other items will need root too: item 26's `sysctl.d` step,
item 43's system-level reads, item 60's engine units and their guards.

Three ways were weighed (item 59, Question 1):

- a root template oneshot with a root timer, granted by a polkit rule that
  lets the user *start* only named instances;
- the same unit, granted by a sudoers `NOPASSWD` line for those exact
  `systemctl start` commands;
- sudoers `NOPASSWD` for the privileged commands themselves.

The third puts the guard outside the privilege: the check runs unprivileged,
the action runs as root later, and an unguarded command is one keystroke
away. The user's `docker` group is already root-equivalent; this rule
neither changes that nor relies on it.

## Decision

1. **A root action runs only inside a named systemd unit**, which evaluates
   its own guards and performs the action in the same root process.
2. **The unit executes a root-owned copy**, installed under
   `/usr/local/sbin` (or another root-owned path), never a file in a
   user-writable checkout. A repo edit cannot become root code; a
   `make <x>-check` target compares the installed copies with the repo's,
   read-only.
3. **The user installs every root file** from a printed plan
   (`make <x>-install-plan`), which runs nothing. The repo carries every
   installable file; nothing is installed by an agent.
4. **The grant is per unit and per verb**: a polkit rule that matches
   `org.freedesktop.systemd1.manage-units`, the user, the verb (`start`)
   and the exact unit names. A sudoers line for the same `systemctl start`
   commands is the shipped alternative, installed only if the user chooses
   it, never both.
5. **Agents never run sudo**, not even `sudo -n`.
6. **Every root action logs one structured line per decision** to the
   journal, readable without root.

## Consequences

- Each new root action costs a unit, a rule line, an install-plan entry and
  a drift check; it is visible and reviewable as files.
- The installed copy can lag the repo; `make <x>-check` names the drift,
  and reinstalling is the user's step.
- polkit's `rules.d` is not readable by the user, so a drift check reports
  that file as unverifiable with the root command that verifies it.
- Item 59 is the first instance
  ([scripts/host/](../../scripts/host/README.md)). Items 26 and 60 follow
  it when they need root.
