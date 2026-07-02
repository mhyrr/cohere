---
context: Cohere.Map
reviewed: 2026-07-02
surface: eddee810a03a
functions: build/1 fetch_group/2 render/1
---

# Map — Intent

## Purpose

Assembles the derived truth: the actual shape of the host system, built
from reflection over compiled modules and rendered to one git-tracked
markdown file. The map is the level-2 rung — the artifact that cannot lie
because nobody authors it.

## Invariants

- INV-MAP-001: the map is 100% derived. No hand-authored content survives
  regeneration, by design.
- INV-MAP-002: rendering is deterministic — stable ordering, no
  timestamps. Regenerating without a code change is a no-op diff.
- INV-MAP-003: derivation reads compiled modules and app config only.
  Never source text, never a running server, never the database — so it
  runs anywhere `mix compile` runs, including CI.

## Decisions

- DEC-MAP-001 (2026-07-02): classification is functional, not name-based
  (`__schema__/1` makes a schema, `Oban.Worker` behaviour makes a worker).
  Named after the revrec traps: a Cloak type living in the schema layer,
  contexts with zero CRUD-named functions. Rejected: source
  regex/AST scanning — names lie, compiled modules don't.
- DEC-MAP-002 (2026-07-02): one markdown artifact, one line per fact.
  Rejected: a JSON twin (a second rendering to keep honest) and markdown
  tables (token-heavy, not greppable).
- DEC-MAP-003 (2026-07-02): context groups classify as
  domain/service/passive/infra; pure plumbing (Application, Repo, Ecto
  types) collapses to an Infrastructure list instead of posing as
  contexts. Rejected: hiding plumbing entirely — the map must account for
  every module or "unclaimed" loses meaning.

## Non-goals

- Call topology (which routes invoke which contexts) — needs compiler
  tracers; a future deriver, not this module.
- Runtime state (process trees, live config). That is Tidewave's layer;
  the map points at it instead of duplicating it.

## Open questions

- Umbrella projects: one map per child app, or one merged map at the root?

## Accepted drift
