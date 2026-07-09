---
context: Cohere.Design
reviewed: 2026-07-09
surface: c3bf3d14798e
functions: accept/2 accept/3 anchored_to/3 filename/1 ground/2 issues/3 load_all/1 open_questions/1 parse/1 parse/2 promised_refs/1 skeleton/2 skeleton/3 unmet_promises/1
---

# Design — Intent

## Purpose

The authored artifact of the feature loop (design: feature-loop). A
design doc records the conversation that shapes a change — problem,
existing ground, shape, promised surface, decisions with rejected
alternatives — in one format the tooling reads. This module parses and
scaffolds the docs, assembles the ground, verifies the promises, and
performs the one status transition the lifecycle allows.

## Invariants

- INV-DES-001: design findings are advisory by construction — nothing
  `Cohere.Design.issues/3` returns may ever feed a build-failing path.
  Cards gate; designs inform.
- INV-DES-002: promised refs are parsed without the namespace filter — a
  promise is explicit, so mix tasks and any module can be promised. Body
  refs outside Promised surface use the namespace filter, like cards.
- INV-DES-003: refs inside HTML comments never count, anywhere — a
  skeleton example is not a claim. (Found the hard way: the template's
  own example blocked completion of every fresh design.)
- INV-DES-004: accepted designs are immutable history. `accept/3` is the
  only status transition this module performs (draft → accepted, dated
  and attributed in the Status log); supersession is a *new* doc naming
  the old slug in `supersedes:`, never an edit.

## Decisions

- DEC-DES-001 (2026-07-03): Existing ground is inlined as a dated
  snapshot, not linked (per DEC-FEA-003 in the feature-loop design). A
  design is a dated record, so quoting the ground as-of its date is a
  quote in a meeting record, not a second truth. Rejected: link-only
  ground — constraints nobody opens don't constrain anything.
- DEC-DES-002 (2026-07-03): in-flight state is a file property —
  `status: draft` in frontmatter — read fresh from disk every check.
  Rejected: any state file or registry; state lives in the artifact.
- DEC-DES-003 (2026-07-03): unknown anchors render as "proposed" in the
  ground and warn in check rather than erroring — a design may introduce
  the context it anchors; `mix cohere.complete` is where anchors must
  finally resolve.
- DEC-DES-004 (2026-07-08): anchor resolution is Design's to own.
  `Cohere.Design.anchored_to/3` filters docs to a map group for
  consumers like the packet, resolving anchors exactly as check does
  (`Cohere.Map.fetch_group/2`); superseded docs never match — the
  superseding doc carries the thread (DEC-PAC-003 in
  `cohere/design/packet-sources.md`). Rejected: a second matcher inside
  `Cohere.Packet` — two resolutions drift apart.
- DEC-DES-005 (2026-07-09): `mix cohere.design <slug>` without
  `--contexts` infers anchors from the branch diff via
  `Cohere.Packet.contexts_for_files/3` — resolving this card's open
  question, yes (DEC-AGE-005 in `cohere/design/agent-surfaces.md`).
  Design-first stays primary; inference serves the retrofit. Rejected:
  requiring the flag always — agents mid-branch already know the answer
  mechanically.

## Non-goals

- Judging whether a design is *good* or semantically consistent with the
  cards it quotes — no LLM, no heuristics. The tool assembles; the mind
  judges.
- Packet assembly. `Cohere.Packet` delivers task context; the ground
  section serves the design conversation only.

## Open questions

## Accepted drift
- 2026-07-08: surface changed (+anchored_to/3) — accepted
- 2026-07-09: surface changed (+accept/3) — accepted (maya)
