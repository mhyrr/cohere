---
context: Cohere.Check
reviewed: 2026-07-03
surface: 33bec9f41f56
functions: check/1 format/1
---

# Check — Intent

## Purpose

The check verb (design: feature-loop): every finding cohere can make, in
one iterative command that is identical locally and in CI. Composes the
drift engine's hard findings with design advisories and owns the verdict
line.

## Invariants

- INV-CHE-001: `Report.clean?/1` delegates to the drift report alone —
  design findings mathematically cannot fail the build (DEC-FEA-002:
  drift on history is information, drift on intent is a bug).
- INV-CHE-002: one command, no modes — check behaves identically locally
  and in CI. No CI-only flags, no environment sniffing.
- INV-CHE-003: every finding is printed with the action that fixes it.
  A checker that names problems without naming the next command is a
  scold, not a loop.

## Decisions

- DEC-CHE-001 (2026-07-03): `Cohere.Drift` survives as the map/card
  finding engine; Check composes it and owns the verdict. Rejected:
  absorbing Drift wholesale — its card history and the "drift" finding
  vocabulary are worth keeping stable.
- DEC-CHE-002 (2026-07-03): `--accept` lives on `mix cohere.check`, not
  a separate task (per DEC-FEA-006; `mix cohere.drift` retired outright,
  pre-publish, no alias). The dev remembers one command; accepting is a
  review action taken from its output.

## Non-goals

- Fixing anything itself, with the single exception of `--accept` — an
  explicit, human-initiated review action. Check reports; the dev (or
  `mix cohere.complete`) changes state.
- Verifying design promises — that is completion-time rigor and belongs
  to `mix cohere.complete`.

## Open questions

## Accepted drift
