---
context: Cohere.Packet
reviewed: 2026-07-08
surface: ce98880a2916
functions: build/2 build_for_files/2 contexts_for_files/3 group_index/1 guidance_paths/2
---

# Packet — Intent

## Purpose

Assembles the work packet: context delivered, not discovered. For the
contexts a task touches — named explicitly or resolved from a branch
diff — the packet carries the map slice, the intent card verbatim,
anchored designs, per-directory agent guidance, related routes, and
runtime-verification pointers, in one markdown artifact that travels
(dispatch prompts, other harnesses, a teammate's paste buffer).

## Invariants

- INV-PAC-001: the packet is deterministic given repo state — file
  contents in, markdown out. No clock, no network, no git commands.
- INV-PAC-002: link, don't restate. The packet inlines source records
  verbatim (cards, draft excerpts, guidance files) and points at
  everything else; it never paraphrases code or documents into a second
  truth.
- INV-PAC-003: diff-driven assembly never slices silently — the branch
  scope note lists the contexts covered and every changed file that
  mapped to no context.

## Decisions

- DEC-PAC-001 (2026-07-08): accepted designs render as one-line
  pointers; only drafts inline content (Problem + Promised surface).
  Durable content belongs in the card — a packet that restates accepted
  designs is a confession that distillation failed; if a card feels
  thin, fix the card. Rejected: inlining accepted designs whole or
  excerpted.
- DEC-PAC-002 (2026-07-08): drafts render once, in a packet-level
  `## In-flight designs` section, not per context — a draft is
  task-level context ("someone is mid-change here"), and one anchoring
  several packeted contexts must not repeat verbatim. Rejected:
  per-context draft inlining.
- DEC-PAC-003 (2026-07-08): superseded designs never render — the
  superseding doc carries the thread. Rejected: listing them as
  history; archaeology lives in `cohere/design/`.
- DEC-PAC-004 (2026-07-08): per-directory guidance (`AGENTS.md`,
  `CLAUDE.md` in a context's source directories, found via the source
  index — reflection, not path convention) is inlined verbatim; root
  guidance stays a pointer. Packets travel to harnesses that never
  auto-load nested guidance; root files load everywhere already.
  Rejected: pointer-only for directory guidance.
- DEC-PAC-005 (2026-07-08): anchor matching is delegated to
  `Cohere.Design.anchored_to/3` — the same resolution check uses, not a
  second matcher (DEC-DES-004 in `cohere/intent/design.md`).

## Non-goals

- Git-history and test-file slices — ranked behind designs and
  guidance; revisit when a packet consumer actually wants them
  (`cohere/design/packet-sources.md`, Shape).
- Tracing web modules to the domain contexts they call — that needs the
  call-topology deriver; until then diff-driven packets report web
  files as unmapped rather than guessing.

## Open questions

- Should inlined guidance files get a size cap? None for now — revisit
  when a host project shows up with a monster per-directory CLAUDE.md.

## Accepted drift
