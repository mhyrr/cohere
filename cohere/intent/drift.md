---
context: Cohere.Drift
reviewed: 2026-07-09
surface: 4f4931c09525
functions: check/1 derived_status/2 format/1
---

# Drift — Intent

## Purpose

The mechanism that keeps the authored layer honest. Detects, mechanically
and deterministically, when the project has moved out from under its
coherence artifacts: a stale map, a card whose context surface changed
since review, a card referencing dead code, a registered derived
artifact whose committed bytes no longer match a fresh render. This is
the piece that separates the coherence layer from "we added more
markdown."

## Invariants

- INV-DRI-001: every check is deterministic — no clock, no randomness, no
  network. Same repo state in, same report out.
- INV-DRI-002: drift is binary at the CI boundary: `Report.clean?/1`
  drives exit 0/1. Informational findings (uncarded contexts) never fail
  the build.
- INV-DRI-003: accepting drift always leaves a dated trace in the card's
  `## Accepted drift` section. Silent rebinding is not a supported path.

## Decisions

- DEC-DRI-001 (2026-07-02): cards bind to surfaces via hash **plus** the
  full function list in frontmatter, not hash alone. The list costs a
  machine-managed line but buys exact `+fun/1 −fun/2` deltas in reports
  and annotations without depending on git state. Rejected: hash-only
  (detection without explanation); git-diff of the committed map (breaks
  when the map is regenerated before cards are reviewed).
- DEC-DRI-002 (2026-07-02): reference checking validates only backticked,
  fully-qualified, app-namespaced mentions (`MyApp.Mod.fun/1`). Rejected:
  checking short names like `Deal` — false-positive machine.
- DEC-DRI-003 (2026-07-02): map staleness = byte inequality between the
  committed file and a fresh render, reported as a bounded Myers line
  diff. Rejected: semantic diffing — the render is already deterministic,
  so bytes are the semantics.
- DEC-DRI-004 (2026-07-09): DEC-DRI-003 generalized to any registered
  derived artifact (`config :cohere, derived:` —
  `{name, path, {module, function}, fix}`; `function(out_dir)` renders
  into a scratch dir under the build path, never the working tree).
  Hard finding, gated in `mix cohere.check`, not bespoke CI steps —
  supersedes the venue half of DEC-DOC-001. Delta is file-level
  (differs/appears/vanishes, bounded), not line-level: the map's Myers
  diff earns its cost on one small file, a site of dozens does not; the
  fixing command is the payload. (Full record: DEC-DER-001..004 in
  `cohere/design/derived-artifacts.md`.)

## Non-goals

- Judging whether drift is *good*. The sentinel detects and demands a
  decision; humans (or agents with the card in context) make it.
- Prose invariants ("money is integer cents") — those are card content
  the verify flow reads; the sentinel only checks what reflection can see.

## Open questions

- Should `--accept` require the map to be fresh first, forcing one
  canonical ordering of the fix workflow?

## Accepted drift
- 2026-07-09: surface changed (+derived_status/2) — accepted (maya)
