---
design: docs-site
status: accepted
date: 2026-07-07
contexts: Cohere.Map, Cohere.Intent, Cohere.Design, Cohere.Check, Cohere.Drift, Cohere.Packet, Cohere.Docs
---

# Docs Site — Design

## Problem

Cohere's entire public story lives in one README. The thesis (coherence
as a measurable property), the ladder, the three document kinds, and the
feature loop are narrative — they need pages with an argument's shape,
not an API reference's. Hexdocs will exist once we publish to Hex, but
hexdocs is the API layer; it cannot carry positioning, and every hexdocs
site looks like every other hexdocs site.

The adjacent project (specled.dev, surveyed 2026-07-07) demonstrates the
gap: a less mechanically capable tool that reads as more serious because
its docs surface is complete — overview, core model, use-case guides,
and an `llms.txt` so agents can consume the docs directly. For a tool
whose audience is half agents, not having an agent-readable docs surface
is failing our own thesis.

A repeated question wants its own surface. The README answers "what is
this repo"; nothing answers "what is this idea."

## Existing ground

> Snapshot assembled 2026-07-07 from the map and intent cards. A dated
> record of the constraints this design is shaped against — the map
> and cards remain canonical.

### Cohere.Map — service

**API** (3): build/1 fetch_group/2 render/1

Invariants (from `cohere/intent/map.md`):
- INV-MAP-001: the map is 100% derived. No hand-authored content survives
  regeneration, by design.
- INV-MAP-002: rendering is deterministic — stable ordering, no
  timestamps. Regenerating without a code change is a no-op diff.
- INV-MAP-003: derivation reads compiled modules and app config only.
  Never source text, never a running server, never the database — so it
  runs anywhere `mix compile` runs, including CI.

Decisions (from `cohere/intent/map.md`):
- DEC-MAP-001 (2026-07-02): classification is functional, not name-based
  (`__schema__/1` makes a schema, `Oban.Worker` behaviour makes a worker).
  Named after traps in the first production validation: a Cloak type living in the schema layer,
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

### Cohere.Intent — service

**API** (7): accept_drift/3 filename/1 load_all/1 parse/1 parse/2 refs/2 skeleton/2

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

### Cohere.Packet — service

**API** (4): build/2 build_for_files/2 contexts_for_files/3 group_index/1

_No intent card for this context._

### Cohere.Docs — proposed

Not in the map yet; this design introduces it.

## Shape

A static site at `mhyrr.github.io/cohere`, generated by the repo, served
by GitHub Pages from `docs/` on main. The site is built the way cohere
builds everything: **derived where possible, authored where necessary**,
with a CI gate that catches silent rot.

```
docs_src/                 # sources (authored)
  pages/*.md              #   narrative pages, constrained markdown
  assets/site.css         #   one stylesheet
  assets/fonts/*.woff2    #   self-hosted faces
  build.exs               #   thin runner: mix run docs_src/build.exs
docs/                     # output (derived, committed, Pages serves it)
  .nojekyll
  *.html + *.md twins     #   every page in both forms
  llms.txt                #   agent index
```

**Generator.** Logic lives in `Cohere.Docs` (lib module, tested);
`docs_src/build.exs` is a thin runner. Zero new deps: we author the
markdown input, so a constrained renderer (headings, paragraphs, fenced
code, inline code, links, lists, blockquotes, rules) is safe — the same
move as hand-parsed frontmatter over a YAML dep. Rendering is
deterministic (INV-MAP-002's discipline applied to HTML): same sources
in, same bytes out.

**Derived pages.** The command reference is reflected from the compiled
mix tasks' own `@shortdoc`/`@moduledoc` — the reference cannot lie. A
`self` page renders cohere's own live `cohere/map.md` and an intent
card: the product demonstrated on itself, show-don't-narrate. Derived
blocks carry a provenance stamp (see visual direction).

**Freshness gate.** `docs/` is a committed derived artifact, gated
exactly like the map (DEC-DRI-003's byte-diff pattern): CI rebuilds and
fails on `git diff --exit-code docs/`. The site cannot silently drift
from its sources.

**Page set** — one idea per page, each with an `.md` twin:

| page | kind | carries |
|---|---|---|
| `index` | authored | thesis, the loop in 12 lines, quickstart |
| `ladder` | authored | L1–L5, what each rung buys |
| `loop` | authored | design / check / complete, walked end to end |
| `the-map` | authored | derived truth; why it cannot lie |
| `intent-cards` | authored | the authored layer; hash-binding; accepted drift |
| `design-docs` | authored | drafts, immutable history, promised surface |
| `packets` | authored | delivered context vs discovered context |
| `reference` | derived | every mix task, from its own moduledoc |
| `self` | derived | cohere's live map + a real card |
| `llms.txt` | derived | index of all `.md` twins |

**Visual direction — the survey chart.** The subject supplies the
aesthetic: cohere's own vocabulary is maps, surfaces, drift. The site
reads as a nautical/survey chart, not a SaaS docs theme.

- *Palette:* pale bathymetric blue-grey ground `#E8EDEE`; warm buff
  panel `#EFE7D8` for authored narrative; white `#FDFDFB` for derived
  blocks; deep chart ink `#1F2A2E` for text;
  contour brown `#8A6B4D` for rules and secondary structure; chart
  magenta `#C21E6E` reserved for drift/hazard semantics only — on NOAA
  charts magenta marks what keeps you off the rocks, and here it marks
  drift findings, warnings, and nothing else. Links in bathy blue
  `#2E6E8E`.
- *Two papers encode the thesis:* authored content sits on buff (land),
  derived content on white/blue (soundings). The reader learns the
  authored/derived distinction from texture before reading a word.
- *Type:* display — Marcellus (inscriptional roman, chart-label caps,
  letterspaced, used sparingly); body — Source Serif 4; code/data —
  Fragment Mono. Loaded via a Google Fonts link rather than self-hosted
  woff2 (build-time deviation, 2026-07-07: network fetches for the font
  binaries were unavailable in-session; functionally identical on
  GitHub Pages, swappable to self-hosted later). Ligatures are disabled
  in code — an arrow ligature in `~> 0.1` lies about the source.
- *Signature:* the **edition notice** — every derived block is stamped
  like a chart correction: `derived · mix cohere.map · surface
  eddee810a03a · 0.1.0` in a thin-ruled mono strip. Structure, not
  ornament: the stamp is the page telling you it cannot lie and when it
  was last true.
- *Motion:* essentially none. Charts don't animate. One contour-line
  SVG device in the index hero, static, and that is the whole budget.

What deliberately doesn't change: README stays the repo-facing quick
story; hexdocs (when published) stays the API layer; the site is the
narrative layer. Three surfaces, no duplication of role.

## Promised surface

- `Cohere.Docs` — the generator module
- `Cohere.Docs.build/1` — render docs_src/ into docs/, all pages,
  twins, and llms.txt
- `Cohere.Docs.render_markdown/1` — the constrained markdown renderer

## Decisions

- DEC-DOC-001 (2026-07-07): GitHub Pages from `docs/` on main with
  `.nojekyll`; generated output is committed and gated by a CI
  freshness diff — a derived artifact kept honest the same way the map
  is (DEC-DRI-003). Rejected: gh-pages branch (build artifacts outside
  the reviewed tree); external hosting (a service dependency for a
  static folder GitHub already serves).
- DEC-DOC-002 (2026-07-07): zero-dependency generator — `Cohere.Docs`
  in lib (testable, promised) driven by `docs_src/build.exs`; no new
  mix task in v1, so the package surface consumers see stays clean.
  Rejected: Jekyll (theme-fighting, a Ruby toolchain, and no way to
  derive the reference); ex_doc (every hexdocs page looks identical —
  the opposite of this brief; hexdocs arrives with Hex publish as the
  API layer anyway); earmark (the project's first dependency, spent on
  a docs nicety — we author the input, so a constrained renderer is
  safe, the same judgment as hand-parsed frontmatter over YAML).
- DEC-DOC-003 (2026-07-07): the command reference is derived from the
  compiled tasks' `@shortdoc`/`@moduledoc` via reflection — the
  reference cannot lie, per the product's own thesis. Rejected: a
  hand-written reference (it would rot, and cohere of all projects
  cannot ship rotting docs).
- DEC-DOC-004 (2026-07-07): every page ships an `.md` twin plus a
  site-wide `llms.txt`. Half the audience is agents; serve them the
  form they parse best. (Adopted from specled.dev with pride.)
  Rejected: HTML-only (fails our own agent-readability thesis).
- DEC-DOC-005 (2026-07-07): visual direction is the survey chart —
  two paper tones encoding authored vs derived, edition-notice hash
  stamps on derived blocks, chart magenta reserved for drift/hazard
  semantics. The aesthetic is load-bearing: it teaches the product's
  central distinction visually. Rejected: the statistical defaults
  (cream + serif + terracotta; near-black + acid accent; broadsheet
  hairlines), Elixir purple (every BEAM project), dark-mode Inter +
  JetBrains Mono (the median dev-tool site).

## Open questions

- Name collision (TK-007): publishing `mhyrr.github.io/cohere` makes
  the name public ahead of the Hex naming decision. Proceed, or settle
  the name first? Greg's call.
- Should `Cohere.Docs` later render a *host project's* `cohere/`
  directory as a browsable site ("your coherence layer, in a browser")?
  Genuine product surface, out of scope for v1.

## Status log
- 2026-07-07: accepted — promised surface verified
