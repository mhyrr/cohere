---
context: Cohere.Onboarding
reviewed: 2026-07-09
surface: a950d1fd2f87
functions: block/1 sync/1 sync/2 synced?/1 synced?/2
---

# Onboarding — Intent

## Purpose

Lands the loop's instructions where agents already look: owns the
cohere block in the host's `AGENTS.md`. The tool's primary operator is
an agent, and instructions that live in a directory no agent reads
unprompted (`cohere/README.md`, `deps/cohere/usage-rules.md`) reach no
one — the same delivery logic as the packet's DEC-PAC-004.

## Invariants

- INV-ONB-001: nothing outside the `<!-- cohere:begin/end -->` markers
  is ever modified, by construction. The block is cohere's; the file is
  the dev's.
- INV-ONB-002: the working agreement is seeded once and never touched
  again — role policy belongs to the devs (Greg, 2026-07-09: "devs will
  choose how they want to work with this"). Cohere ships mechanics and
  attribution; enforcement stays in PR review, never in mix tasks.
- INV-ONB-003: `sync/2` is idempotent — re-running init with an
  unchanged block is a no-op (`:unchanged`), so upgrades regenerate
  mechanics without churning diffs.

## Decisions

- DEC-ONB-001 (2026-07-09): two zones — a machine-owned marker block
  regenerated on every re-run, and a seeded-once working agreement
  outside it. Mechanics must track cohere's evolution; policy must not.
  Rejected: append-once for everything (instructions rot); owning the
  whole file (authored territory); a separate cohere-owned file (the
  unread-directory problem again). (DEC-AGE-001 in
  `cohere/design/agent-surfaces.md`.)
- DEC-ONB-002 (2026-07-09): target is `AGENTS.md` by default,
  `mix cohere.init --into` redirects; `synced?` accepts either
  `AGENTS.md` or `CLAUDE.md` so `--into` shops aren't nagged. Rejected:
  writing both files — one truth per fact. (DEC-AGE-002.)
- DEC-ONB-003 (2026-07-09): a begin marker without its end marker
  raises with instructions rather than guessing at a repair — mangling
  a dev's authored file is the one unrecoverable failure here.

## Non-goals

- Syncing `usage-rules.md` content — that is the `usage_rules`
  package's job; the block links to the rules instead of duplicating
  them.
- Role enforcement. The working agreement is prose for humans and
  agents to follow, deliberately not machinery.

## Open questions

- Umbrellas: one AGENTS.md block at the root, or one per child app?

## Accepted drift
