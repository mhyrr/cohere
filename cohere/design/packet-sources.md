---
design: packet-sources
status: accepted
date: 2026-07-08
contexts: packet, design
---

# Packet Sources — Design

## Problem

The packet promises "context delivered, not discovered" and then omits
two sources of context that already live in the repo.

First, design docs. They anchor to contexts via `contexts:` frontmatter,
yet a packet for those contexts never mentions them. The sharp edge is
drafts: a `status: draft` design is live intent — someone is mid-change
on that context — and an agent holding the packet has no way to know.
It will happily design against ground that a sibling design is about to
move. Accepted designs are a milder gap; their durable content should
already be in cards, but the packet doesn't even point at the record.

Second, per-directory agent guidance. Host projects grow `CLAUDE.md` /
`AGENTS.md` files next to context source (revrec's organic pattern).
Harnesses auto-load those only when the agent opens files in that
directory — but packets travel: into dispatch prompts, other harnesses,
a teammate's paste buffer, where the auto-load never fires. Guidance
that exists precisely to brief agents on a context is invisible in the
one artifact whose job is briefing agents on a context.

## Existing ground

> Snapshot assembled 2026-07-08 from the map and intent cards. A dated
> record of the constraints this design is shaped against — the map
> and cards remain canonical.

### Cohere.Packet — service

**API** (4): build/2 build_for_files/2 contexts_for_files/3 group_index/1

_No intent card for this context._

### Cohere.Design — service

**API** (12): accept/2 filename/1 ground/2 issues/3 load_all/1 open_questions/1 parse/1 parse/2 promised_refs/1 skeleton/2 skeleton/3 unmet_promises/1

Invariants (from `cohere/intent/design.md`):
- INV-DES-001: design findings are advisory by construction — nothing
  `Cohere.Design.issues/3` returns may ever feed a build-failing path.
  Cards gate; designs inform.
- INV-DES-002: promised refs are parsed without the namespace filter — a
  promise is explicit, so mix tasks and any module can be promised. Body
  refs outside Promised surface use the namespace filter, like cards.
- INV-DES-003: refs inside HTML comments never count, anywhere — a
  skeleton example is not a claim. (Found the hard way: the template's
  own example blocked completion of every fresh design.)
- INV-DES-004: accepted designs are immutable history. `accept/2` is the
  only status transition this module performs (draft → accepted, dated
  in the Status log); supersession is a *new* doc naming the old slug in
  `supersedes:`, never an edit.

Decisions (from `cohere/intent/design.md`):
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

## Shape

Two new packet slices, both assembled from mechanisms that already
exist — no new derivation.

**In-flight designs: one packet-level section, loud.** After the header
(and branch-scope note, when present), before the first context section:

```
## In-flight designs

> `packet-sources` (draft, 2026-07-08) anchors Packet, Design — read it
> before working these contexts. Excerpt below; full doc at
> cohere/design/packet-sources.md.
```

followed by the draft's Problem and Promised surface sections inlined.
A draft is task-level context — "someone is mid-change here" — not
context-encyclopedia content, so it renders once per packet, not once
per context, and a draft anchoring several packeted contexts never
repeats. Matching is `Design.load_all/1` anchors resolved through
`Map.fetch_group/2` — the same resolution `check` uses, no second
matcher.

**Accepted designs: per-context pointers.** A `### Designs` line-list
at the end of each context section: slug, date, path. One line each.
The durable content of an accepted design lives in the card by
construction (the complete step distills it); the packet links the
record, it does not restate it.

**Directory guidance: per-context, inlined verbatim.** For each context
group, the owning directories are the unique dirnames of the group's
modules' compile sources (via `Project.source_index/1` — reflection,
not path convention). Any `AGENTS.md` or `CLAUDE.md` in those
directories is inlined whole in the context section, labeled with its
path. Root-level guidance stays where it is today — a pointer — because
every harness already loads it.

What deliberately doesn't change: the packet stays deterministic (file
contents in, markdown out — no clock, no git); the card remains the
canonical durable layer; git-history and test-file slices stay out
(ranked behind these two sources; revisit when a packet consumer
actually wants them).

## Promised surface

- `Cohere.Design.anchored_to/3` — designs whose anchors resolve to a
  given map group
- `Cohere.Packet.guidance_paths/2` — guidance files owned by a group's
  source directories

## Decisions

- DEC-PAC-001 (2026-07-08): accepted designs render as one-line
  pointers; only drafts inline content (Problem + Promised surface).
  Inlining an accepted design would undo the architecture — durable
  content belongs in the card, and a packet that restates designs is a
  confession that distillation failed. If a card feels thin, fix the
  card. Rejected: inlining accepted designs whole or excerpted.
- DEC-PAC-002 (2026-07-08): drafts render once, in a packet-level
  `## In-flight designs` section, not per context. A draft anchoring
  four contexts (feature-loop's shape) would otherwise repeat verbatim
  in one packet. Rejected: per-context draft inlining.
- DEC-PAC-003 (2026-07-08): superseded designs never render — the
  superseding doc carries the thread. Rejected: listing them as
  history; archaeology lives in `cohere/design/`, not in every packet.
- DEC-PAC-004 (2026-07-08): per-directory guidance is inlined verbatim,
  root guidance stays a pointer. Packets travel to harnesses that never
  auto-load nested guidance files; root files load everywhere already.
  Rejected: pointer-only for directory guidance — that is context
  discovered, not delivered, in the one artifact whose rule is the
  reverse.

## Open questions

- Should inlined guidance files get a size cap? None for now — defense
  in proportion; revisit when a host project shows up with a monster
  per-directory CLAUDE.md.
- Should a draft's Decisions section inline too, once drafts start
  carrying substantial decisions mid-flight?

## Status log
- 2026-07-08: accepted — promised surface verified
