---
design: agent-surfaces
status: accepted
date: 2026-07-09
contexts: design, intent, check, onboarding
---

# Agent Surfaces — Design

## Problem

The tool's primary operator is an agent — scaffolding designs for human
review, assembling packets, answering the drift gate — and cohere's
instructions for agents never reach one. `usage-rules.md` encodes the
full discipline (packet before exploring, design before non-trivial
change, re-read before accept, check exits 0), but delivery depends on
the host running the `usage_rules` sync, and `mix cohere.init` writes
its README inside `cohere/` — a directory no agent reads unprompted.
The instructions must land where agents already look: the host's
`AGENTS.md`.

Second gap: every judgment trace is anonymous. Card accepted-drift
lines, design status logs — dated, but no author. In agent-heavy use
the one thing a human reviewer needs to distinguish is "an agent
rubber-stamped its own drift" from "a human signed this," and the diff
can't show it.

Third, small: `mix cohere.design` demands `--contexts` even when the
branch diff already knows the answer — the open question on
`cohere/intent/design.md` since 2026-07-03.

What deliberately stays out (from the 2026-07-08 surfaces
conversation): role *enforcement* — who may run which verb is guidance
devs edit, not mechanism; JSON output — no consumer exists; any
design-approval state machine — the PR is the approval gate.

## Existing ground

> Snapshot assembled 2026-07-09 from the map and intent cards. A dated
> record of the constraints this design is shaped against — the map
> and cards remain canonical.

### Cohere.Design — service

**API** (13): accept/2 anchored_to/3 filename/1 ground/2 issues/3 load_all/1 open_questions/1 parse/1 parse/2 promised_refs/1 skeleton/2 skeleton/3 unmet_promises/1

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
- DEC-DES-004 (2026-07-08): anchor resolution is Design's to own.
  `Cohere.Design.anchored_to/3` filters docs to a map group for
  consumers like the packet, resolving anchors exactly as check does
  (`Cohere.Map.fetch_group/2`); superseded docs never match — the
  superseding doc carries the thread (DEC-PAC-003 in
  `cohere/design/packet-sources.md`). Rejected: a second matcher inside
  `Cohere.Packet` — two resolutions drift apart.

### Cohere.Intent — service

**API** (7): accept_drift/3 filename/1 load_all/1 parse/1 parse/2 refs/2 skeleton/2

_No intent card for this context._

### Cohere.Check — service

**API** (2): check/1 format/1

Invariants (from `cohere/intent/check.md`):
- INV-CHE-001: `Report.clean?/1` delegates to the drift report alone —
  design findings mathematically cannot fail the build (DEC-FEA-002:
  drift on history is information, drift on intent is a bug).
- INV-CHE-002: one command, no modes — check behaves identically locally
  and in CI. No CI-only flags, no environment sniffing.
- INV-CHE-003: every finding is printed with the action that fixes it.
  A checker that names problems without naming the next command is a
  scold, not a loop.

Decisions (from `cohere/intent/check.md`):
- DEC-CHE-001 (2026-07-03): `Cohere.Drift` survives as the map/card
  finding engine; Check composes it and owns the verdict. Rejected:
  absorbing Drift wholesale — its card history and the "drift" finding
  vocabulary are worth keeping stable.
- DEC-CHE-002 (2026-07-03): `--accept` lives on `mix cohere.check`, not
  a separate task (per DEC-FEA-006; `mix cohere.drift` retired outright,
  pre-publish, no alias). The dev remembers one command; accepting is a
  review action taken from its output.

### onboarding — proposed

Not in the map yet; this design introduces it.

## Shape

Three pieces, one new module.

**1. Onboarding: init writes the agent block.** New module
`Cohere.Onboarding`, owning a marker-bounded block in the host's
`AGENTS.md` (default; `mix cohere.init --into CLAUDE.md` redirects):

- Between `<!-- cohere:begin -->` / `<!-- cohere:end -->`:
  machine-managed mechanics, regenerated on every `mix cohere.init`
  re-run — the loop's commands per moment (pickup → packet, non-trivial
  change → design, anytime → check, land → complete), the never-edit
  rules, a pointer to the full usage rules. Nothing outside the markers
  is ever touched, by construction.
- Below the block, on first write only: a `### Working agreement`
  section with the default role policy — agents run mechanical verbs
  freely; self-accept drift an in-flight design promised; unexpected
  drift stops and gets surfaced; the PR is the approval gate. Seeded
  once, dev-owned forever; devs choose how they work with this.

File missing → created. File present without markers → block appended.
Markers present → block replaced in place. `sync/2` returns
`:created | :updated | :unchanged` so init can report honestly.

`mix cohere.check` gains a soft finding when the target has no cohere
block: agents can't find the loop. Advisory, never exit 1 (guidance
absence is not drift), and per INV-CHE-003 it prints its fix
(`mix cohere.init`).

**2. Attribution on judgment traces.** `mix cohere.check --accept
<card> --by NAME` and `mix cohere.complete <slug> --by NAME`. Traces
become `— accepted (NAME)`. `--by` omitted → `git config user.name`;
that missing too → the plain form, never a failure. Write-path only:
check's read path stays clock-, git-, and env-free (INV-CHE-002,
INV-DRI-001 untouched).

**3. Contexts inferred at design start.** `mix cohere.design <slug>`
with no `--contexts` resolves the branch diff to context names — the
same `git diff --name-only` the packet task uses (extracted to
`Cohere.Project.changed_files/1`) through the same
`Cohere.Packet.contexts_for_files/3`. Nothing maps → raise with usage.
Design-first stays the primary path; inference serves the retrofit,
where an agent realizes mid-branch the change deserved a design.

## Promised surface

- `Cohere.Onboarding.block/1` — renders the machine-managed block
- `Cohere.Onboarding.sync/2` — idempotent marker-bounded write
- `Cohere.Onboarding.synced?/1` — does the target carry the block
- `Cohere.Intent.accept_drift/4` — attribution-carrying accept
- `Cohere.Design.accept/3` — attribution-carrying accept
- `Cohere.Project.changed_files/1` — branch diff, shared by packet and
  design tasks

## Decisions

- DEC-AGE-001 (2026-07-09): two zones in AGENTS.md — a machine-owned
  marker block regenerated on re-run, and a seeded-once working
  agreement outside it. Mechanics must track cohere's evolution; policy
  belongs to the devs (Greg: "devs will choose how they want to work
  with this"). Rejected: append-once for everything (instructions rot);
  owning the whole file (authored territory); a separate cohere-owned
  file (a directory no agent reads unprompted is the problem being
  fixed).
- DEC-AGE-002 (2026-07-09): target is `AGENTS.md`, `--into` redirects.
  Rejected: writing AGENTS.md and CLAUDE.md both — one truth per fact;
  CLAUDE.md shops typically symlink or point at AGENTS.md anyway.
- DEC-AGE-003 (2026-07-09): the missing-block finding is soft, printed
  with its fixing command. Rejected: hard finding — a project that
  chose not to run init hasn't drifted from anything it authored.
- DEC-AGE-004 (2026-07-09): attribution lives in event traces only
  (accepted-drift lines, status log), never card frontmatter. The trace
  is the record — a `reviewed-by:` key would be a second, staler truth
  one line above the first. Rejected: reviewed-by frontmatter.
- DEC-AGE-005 (2026-07-09): context inference reuses
  `Packet.contexts_for_files/3` — one file-to-context resolution in the
  codebase, same rationale as DEC-DES-004 for anchors. Rejected: a
  design-task-local matcher.

## Open questions

- Should `--accept` warn when no draft design anchors the drifted
  context — a mechanical hint that drift arrived with no recorded
  intent in flight?
- Umbrellas: one AGENTS.md block at the root, or one per child app?

## Status log
- 2026-07-09: accepted (maya) — promised surface verified
