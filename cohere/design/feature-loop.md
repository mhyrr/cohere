---
design: feature-loop
status: draft
date: 2026-07-03
contexts: Design, Check, Drift, Intent
---

# The Feature Loop — Design

## Problem

Cohere knows how to derive truth (the map), pin intent (cards), and gate
staleness (drift) — but it has no step for the moment a feature *begins*.
The design conversation that precedes every non-trivial change lands in a
wiki, a gist, a chat scrollback, or a `docs/` file with its own private
format, and the repo accumulates a hairy pile of documents no tool reads
and no gate keeps honest. The live counterexample is this very repo:
`docs/design-spec.md`, unlinked and unchecked, in the project that
preaches coherence.

The surface is also gate-shaped where it should be loop-shaped. A dev
must remember `gen.intent`, `packet`, `drift`, and an unnamed manual
"land" step. Credo got this right: one command you run iteratively until
it comes back quiet.

## Existing ground

> Snapshot assembled 2026-07-03 from the map and intent cards. A dated
> record of the constraints this design was shaped against — the map and
> cards remain canonical.

### Cohere.Drift — service
**API** (2): check/1 format/1

Constraints (from `cohere/intent/drift.md`):
- INV-DRI-001: every check is deterministic — no clock, no randomness,
  no network.
- INV-DRI-002: drift is binary at the CI boundary: `Report.clean?/1`
  drives exit 0/1. Informational findings never fail the build.
- INV-DRI-003: accepting drift always leaves a dated trace. Silent
  rebinding is not a supported path.
- DEC-DRI-002: reference checking validates only backticked,
  fully-qualified mentions — short names are a false-positive machine.

### Cohere.Intent — service
**API** (7): accept_drift/3 filename/1 load_all/1 parse/1 parse/2 refs/2 skeleton/2

No intent card yet. Frontmatter is hand-parsed key/value (no YAML dep);
sections are `##` headings; cohere manages frontmatter, humans manage
sections.

### Design — proposed
Not in the map yet; this design introduces it.

### Check — proposed
Not in the map yet; this design introduces it.

## Shape

Three verbs, one loop. State lives in files — a design with
`status: draft` *is* the in-flight state; there is no dotfile.

```console
$ mix cohere.design deal-reversals --contexts deals   # START
  ... design against the delivered ground, iterate ...
$ mix cohere.check                                    # CHECK — anytime, and in CI
  ... build ...
$ mix cohere.check                                    # same command, new findings
$ mix cohere.complete deal-reversals                  # COMPLETE — when check is quiet
```

**Design docs** live in `cohere/design/*.md`: frontmatter
(`design`, `status: draft|accepted|superseded`, `date`, `contexts`,
optional `supersedes`) plus sections — Problem, Existing ground (generated
snapshot), Shape, Promised surface, Decisions, Open questions, Status log.

**Start** scaffolds the doc and assembles the Existing ground section:
for each anchored context, its map API line and its card's invariants and
decisions, dated. A no-LLM tool cannot judge whether a design contradicts
INV-X; it delivers INV-X onto the page where the design is being written,
so the contradiction gets seen. The tool assembles; the mind judges.

**Check** composes two severities. Hard (exit 1, unchanged from the drift
sentinel): stale map, drifted cards, broken card refs. Soft (printed,
never exit 1): design anchors that don't resolve to map contexts, dead
body refs in designs, drafts sitting on a moved ground. `--accept <card>`
moves here from `mix cohere.drift`, which is retired.

**Complete** is the previously-unnamed land step, made one command:
regenerate the map (mechanical, so just do it), require the check
hard-clean — which forces the card re-review where the design's durable
decisions get distilled into cards — then verify every ref in Promised
surface resolves in the compiled app, flip `draft → accepted` with a
date, and append to the Status log. A design that promised
`reverse_deal/1` cannot complete until `reverse_deal/1` exists.

**Module shape:** `Cohere.Design` (parse, scaffold, ground assembly,
promise verification, accept), `Cohere.Check` (composes `Cohere.Drift`
plus design findings into one report), `Cohere.Markdown` (frontmatter and
section mechanics extracted from `Cohere.Intent`, now shared by both).
`Cohere.Drift` survives as the map/card drift engine — the *command*
retires, the finding category keeps its name.

## Promised surface

<!-- Backticked refs this design commits to delivering.
     `mix cohere.complete feature-loop` verifies each one exists. -->

- `Mix.Tasks.Cohere.Design` — start verb
- `Mix.Tasks.Cohere.Check` — check verb, `--accept` included
- `Mix.Tasks.Cohere.Complete` — complete verb
- `Cohere.Design.load_all/1`, `Cohere.Design.parse/2`,
  `Cohere.Design.skeleton/3`, `Cohere.Design.ground/2`,
  `Cohere.Design.promised_refs/1`, `Cohere.Design.accept/2`,
  `Cohere.Design.issues/3`
- `Cohere.Check.check/1`, `Cohere.Check.format/1`
- `Cohere.Project.design_dir/1`

## Decisions

- DEC-FEA-001 (2026-07-03): three verbs — `design`, `check`, `complete` —
  with `map`, `gen.intent`, `packet` demoted to plumbing that check's
  output points at. Credo-shaped: one iterative command, same locally and
  in CI. Rejected: a command per artifact/gate (design + packet + drift +
  manual land) — four things to remember is a workflow too rigid to keep.
- DEC-FEA-002 (2026-07-03): design docs are warn-only in check; only the
  map and cards can exit 1. An accepted design is a dated historical
  record — drift on history is information, drift on intent is a bug.
  Rejected: hash-binding designs like cards, which would demand re-review
  of immutable history forever.
- DEC-FEA-003 (2026-07-03): Existing ground is inlined as a dated
  snapshot, not linked. A design doc is a dated record, so quoting the
  ground as-of its date is a quote in a meeting record, not a second
  truth — and the whole point is designing *against* the constraints on
  the same page. Rejected: link-only ground (constraints nobody opens
  don't constrain anything).
- DEC-FEA-004 (2026-07-03): Promised surface makes the design a
  mechanically checkable spec — complete fails until every promised ref
  resolves in the compiled app. Promised refs are exempt from dead-ref
  checking while draft, and are parsed without the namespace filter so
  mix tasks can be promised. Rejected: prose-only designs (unverifiable
  promises rot into aspirations).
- DEC-FEA-005 (2026-07-03): accepted designs are immutable — supersede
  with a new design (`supersedes:` frontmatter), never edit. Cards are
  the living constraints; designs are the conversation record. One
  direction: complete forces anchored cards to be re-bound, which is the
  moment durable decisions distill from design to card, and cards cite
  designs by slug. Rejected: living design docs — two living truths about
  the same intent always diverge.
- DEC-FEA-006 (2026-07-03): `mix cohere.drift` is retired outright, not
  aliased — pre-publish, zero compat debt. `--accept` moves to
  `mix cohere.check --accept <card>`. Rejected: deprecated alias
  (dead surface area on day one).
- DEC-FEA-007 (2026-07-03): unresolved Open questions at complete time
  warn but do not block — questions legitimately outlive features.
  Rejected: hard-blocking on empty Open questions (invites deleting
  questions to ship).

## Open questions

- Should `start` infer `--contexts` from a branch diff when omitted,
  the way `packet --diff` does?
- When a design's anchored context gains a card *after* acceptance,
  should check suggest citing the design from the new card?

## Status log
