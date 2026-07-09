---
design: derived-artifacts
status: accepted
date: 2026-07-09
contexts: drift, check, docs, project
---

# Derived Artifacts — Design

## Problem

"Committed derived artifact" is a class, and cohere gates exactly one
member of it, by special case. `cohere/map.md` is member #1, hard-wired
into `Cohere.Drift` (render in memory, byte-compare, Myers diff).
`docs/` became member #2 via the docs-site design: DEC-DOC-001 decided
it should be "kept honest the same way the map is" — but the venue
never got weighed. The gate landed as two bespoke CI steps
(`mix run docs_src/build.exs && git diff --exit-code docs/`), so
`mix cohere.check` says "coherent" locally while the site is stale, and
you learn at CI. That contradicts the spirit of INV-CHE-002 (one
command, identical locally and in CI) even though its letter — check's
own behavior — holds.

Members #3..N are coming: any future design that introduces a
generated-and-committed output (an OpenAPI spec, an ERD, seed data)
gets nothing but convention and a hand-rolled CI step. The 2026-07-09
session demonstrated the failure mode twice in one afternoon: a
behavior change left `docs/reference.md` stale until manually rebuilt,
and the manual rebuild itself used the wrong `base_url` because the
canonical invocation lived only inside `docs_src/build.exs`.

## Existing ground

> Snapshot assembled 2026-07-09 from the map and intent cards. A dated
> record of the constraints this design is shaped against — the map
> and cards remain canonical.

### Cohere.Drift — service

**API** (2): check/1 format/1

Invariants (from `cohere/intent/drift.md`):
- INV-DRI-001: every check is deterministic — no clock, no randomness, no
  network. Same repo state in, same report out.
- INV-DRI-002: drift is binary at the CI boundary: `Report.clean?/1`
  drives exit 0/1. Informational findings (uncarded contexts) never fail
  the build.
- INV-DRI-003: accepting drift always leaves a dated trace in the card's
  `## Accepted drift` section. Silent rebinding is not a supported path.

Decisions (from `cohere/intent/drift.md`):
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

### Cohere.Docs — service

**API** (3): build/0 build/1 render_markdown/1

_No intent card for this context._

### Cohere.Project — service

**API** (8): changed_files/1 design_dir/1 has?/2 intent_dir/1 load/0 load/1 map_path/1 source_index/1

_No intent card for this context._

## Shape

**Registration.** A derived artifact declares itself in config:

```elixir
config :cohere,
  derived: [
    {"docs site", "docs", {Cohere.Docs, :gate_build}, "mix run docs_src/build.exs"}
  ]
```

`{name, path, {module, function}, fix}` — one committed path (file or
directory) per registration; the function takes one argument, an
output directory, and renders the artifact into it as it would appear
at `path`. That arity-1 contract is the price of admission to the
gate: an artifact that can only build in place cannot be checked
without mutating the working tree, and check never mutates the tree.
`fix` is the command the finding prints (INV-CHE-003: a finding
without its fixing command is a scold). `Cohere.Project.load/1` reads
the list onto the struct (`project.derived`), same as every other
config key.

**The check.** `Cohere.Drift.check/1` gains derived-artifact findings
beside map staleness — same category, same severity, same mechanics
generalized: render into a scratch dir under the build directory,
byte-compare the rendered tree against the committed paths, report
per-artifact `:fresh | :stale` with a bounded file-level delta (which
files differ/appear/vanish) and the fixing command. `Report.clean?/1`
requires every registered artifact fresh — hard finding, exactly as
DEC-DOC-001 already classified docs. Map stays special-cased: it needs
no registration because it *is* the product, and its diff stays
line-level.

**Docs registers itself.** `Cohere.Docs.gate_build/1` bakes the
canonical `base_url` into the module (single source — `build.exs`
calls it too, killing the wrong-base_url class of mistake), and
cohere's own config registers the docs site. CI drops the two bespoke
lines; the pipeline gate is `mix cohere.check`, full stop.

What deliberately doesn't change: authored-prose truthfulness stays
outside the gate — byte-compare catches "forgot to rebuild," never "the
sentence stopped being true"; that is review's job (or an LLM's, and
cohere ships neither). Determinism of the registered render is the
registrant's responsibility, as it already is for the map; a
nondeterministic artifact shows up as unfixable staleness, which is the
gate telling you the render is broken.

## Promised surface

- `Cohere.Drift.derived_status/2` — render-and-compare for one
  registered artifact
- `Cohere.Docs.gate_build/1` — canonical docs render into a given
  directory

## Decisions

- DEC-DER-001 (2026-07-09): derived artifacts are gated inside
  `mix cohere.check`, not by bespoke CI steps — one command, identical
  locally and in CI (INV-CHE-002's spirit, now its letter). Supersedes
  the venue half of DEC-DOC-001; the gate half stands. Rejected:
  keeping per-artifact CI steps (a stale site reads "coherent" locally;
  every new artifact hand-rolls its own gate).
- DEC-DER-002 (2026-07-09): registration is config data —
  `{name, path, {module, function}, fix}` with an arity-1 out-dir
  contract and an explicit fixing command. Rejected: anonymous
  functions in config (not reliably storable); MFA-with-appended-args
  (clever, unreadable); a behaviour to implement (a callback module per
  artifact is ceremony for what one function expresses); a
  `mix cohere.regen` task as the universal fix (new surface to keep
  coherent, when every artifact already has a canonical build
  invocation to point at).
- DEC-DER-003 (2026-07-09): scratch renders go under `_build`
  (`Mix.Project.build_path()`), not `System.tmp_dir` — same lifecycle
  as every other build product, no reliance on world-writable temp, and
  `mix clean` sweeps it.
- DEC-DER-004 (2026-07-09): the derived-artifact diff is file-level
  (differs/appears/vanishes, bounded), not line-level. The map's
  line-level Myers diff earns its cost on one small file; a site of
  dozens of HTML files does not. The fixing command is the payload;
  the delta is orientation.

## Open questions

- Should `mix cohere` (the ladder) surface registered derived artifacts
  as part of the level summary?

## Status log
- 2026-07-09: accepted (maya) — promised surface verified
