# Cohere

**A coherence layer for Elixir/Phoenix projects.**

> A project is coherent to the degree that, at any point in its development,
> it can furnish any actor — human or model — with the minimal context
> sufficient to act in line with the user's intent, and can mechanically
> detect when the project has drifted from that intent.

Models are intelligent but context-starved, and the failure mode of context
starvation is incoherence: sessions rediscover the same facts expensively,
and codebases drift as hundreds of locally-reasonable changes accumulate
with no shared frame. Cohere makes coherence a **measurable property of the
project** instead of a hoped-for behavior of the agent.

It does this with three document kinds in one directory, each checked as
hard as its nature allows:

- **The map** — the actual shape of your system, *derived* from the
  compiled application: contexts and their public API, Ecto schemas with
  real types and associations, Phoenix routes (LiveView unwrapped), Oban
  workers with queue and cron wiring. Never hand-edited, regenerated on
  demand — therefore it cannot lie.
- **Intent cards** — one small authored file per context holding only what
  cannot be derived: purpose, invariants, decisions with their rejected
  alternatives, non-goals. Each card is hash-bound to its context's public
  surface. Living constraints, kept fresh by the check gate.
- **Design docs** — one authored file per design: problem, existing
  ground, shape, promised surface, decisions. Drafts are work in flight;
  accepted designs are immutable, dated history. The design conversation
  you'd have anyway, landing in one format the tooling reads — instead of
  a hairy pile of wiki pages and gists no gate keeps honest.

No LLM calls. Zero runtime dependencies. Everything is deterministic and
CI-runnable; models *consume* the outputs but are never required to
produce them.

## Quickstart

```elixir
# mix.exs
{:cohere, "~> 0.1", only: [:dev, :test]}
```

```console
$ mix cohere.init            # scaffold cohere/, derive the first map
$ mix cohere                 # where does this project stand?

Coherence ladder — my_app

  ✓ L1 static guidance — AGENTS.md
  ✓ L2 derived map — map present and fresh
  ✗ L3 authored intent, checked — no intent cards
  ~ L4 governed verbs / runtime verification — tidewave installed; write paths not compiler-governed (boundary)
  ✓ L5 delivered context — work packets available via `mix cohere.packet`
```

Then, incrementally:

```console
$ mix cohere.gen.intent deals      # card skeleton, born bound to the current surface
$ mix cohere.check                 # CI gate: exit 1 on any drift
$ mix cohere.packet deals billing  # assemble delivered context for a task
$ mix cohere.packet --diff         # …or for exactly the contexts this branch touches
```

## The feature loop

The developer surface is three verbs; everything else is plumbing their
output points at.

```console
$ mix cohere.design deal-reversals --contexts deals   # START
  ... design in the doc, against its Existing ground ...
$ mix cohere.check                                    # CHECK — anytime; fix, repeat
  ... build ...
$ mix cohere.check                                    # same command, new findings
$ mix cohere.complete deal-reversals                  # COMPLETE — when check is quiet
```

**Start** scaffolds `cohere/design/deal-reversals.md` (status: draft) and
assembles its *Existing ground*: each anchored context's current API from
the map, plus the invariants and decisions from its intent card. A no-LLM
tool can't judge that your design contradicts INV-DEA-002 — it delivers
INV-DEA-002 onto the page where you're designing, so the contradiction
gets seen. The tool assembles; the mind judges.

**Check** is one iterative command, identical locally and in CI. Hard
findings exit 1: stale map, drifted cards, dead card references. Design
findings are advisories, never failures — an accepted design is a dated
record, and drift on history is information, not a bug. A drifted card
means: re-read it against the new surface, update what your change
invalidated, then `mix cohere.check --accept deals`. Accepted drift is
documented drift; the failure mode this tool exists to kill is the
*silent* kind.

**Complete** is the land step, one command. It regenerates the map,
requires the check hard-clean (which forces the card re-review where the
design's durable decisions get distilled into cards), then verifies every
backticked ref in the design's *Promised surface* exists in the compiled
app. A design that promised `reverse_deal/1` cannot complete until
`reverse_deal/1` exists — the design doc is a mechanically checkable
spec, not aspirational prose. On success: `draft → accepted`, dated,
immutable. New thinking later? A new design with `supersedes:` in its
frontmatter — history is superseded, never rewritten.

The PR that lands a feature carries the map delta (the ontology change),
the card delta (the intent change), the accepted design (the why), and
the code — reviewable together.

## What the map looks like

Derived from a real ~185-module Phoenix app, entries read like the
language of the business, because they are the business — reflected out of
the compiled code:

```markdown
### Revrec.Deals — domain `[surface:df8be63a83b8]`

**API** (32): approve_deal/1 create_deal/1 extract_deal_data/1 get_financial_summary/1 …
**Schemas:** Deal, DealParty, DealPartyFeeComponent
**Support:** AccountKeys, DealReset, EditTracker, Insights, JournalCalculator

### Revrec.Deals.Deal → `deals`
- fields: …, side:enum(listing|buyer|both|lease|referral),
  status:enum(draft|needs_review|approved|posting|posted|posting_failed|reversed), …
- belongs_to reviewed_by → Revrec.Users.User via reviewed_by_user_id
- belongs_to agency → Revrec.Agencies.Agency via agency_id
```

Enum vocabularies, custom foreign keys, queue/cron wiring from config —
the facts agents otherwise rediscover by grepping, delivered in one
git-tracked file whose PR diff *is* the ontology change.

## What check finds

```console
$ mix cohere.check
✗ cohere/intent/deals.md
  surface drifted: +approve_deal/1
  → re-review the card, then `mix cohere.check --accept deals`
⚠ cohere/design/deal-reversals.md — draft, advisory only
  anchor "Reversals" not in the map — fine if this design introduces it;
  `mix cohere.complete` verifies it lands

drift detected

$ mix cohere.check --accept deals
cohere/intent/deals.md — rebound to surface df8be63a83b8, drift annotated
```

## The coherence ladder

| Level | Property | Mechanism |
|---|---|---|
| 0 | Context by discovery | raw repo; agents grep and hope |
| 1 | Static guidance | AGENTS.md / [usage_rules](https://hex.pm/packages/usage_rules) |
| 2 | Derived truth | the map (`mix cohere.map`) |
| 3 | Authored intent, checked | intent cards + drift sentinel |
| 4 | Governed verbs, verified behavior | [boundary](https://hex.pm/packages/boundary) enforcement, [Tidewave](https://tidewave.ai) runtime introspection |
| 5 | Delivered context | work packets (`mix cohere.packet`) |

Each level is useful alone; none requires the previous. Phoenix 1.8 ships
every new project at level 1. Cohere is levels 2–5, adopted incrementally.

Cohere **probes** for what's present rather than requiring anything:
Ecto present → objects and links appear in the map; Oban present → the job
surface appears; boundary present → level 4 lights up; Tidewave present →
work packets direct agents to verify behavior in the running app
(`project_eval`, `execute_sql_query`) instead of inferring it from source.

## Mix tasks

| Task | Does |
|---|---|
| `mix cohere` | ladder status + designs in flight |
| `mix cohere.init` | scaffold `cohere/`, first map, workflow README |
| `mix cohere.design <slug>` | start a design: draft doc + existing ground (`--contexts a,b`) |
| `mix cohere.check` | the iterative check + CI gate; exit 1 on hard drift (`--accept <card>` to rebind) |
| `mix cohere.complete <slug>` | verify the design's promises landed, flip it to accepted |
| `mix cohere.map` | regenerate the derived map |
| `mix cohere.gen.intent <ctx>` | intent card skeleton (`--all`, `--force`) |
| `mix cohere.packet <ctx…>` | assemble a work packet; `--diff` for the contexts this branch touches (`--base REF`, `--out FILE`) |

## Configuration

Everything is optional, via `config :cohere, ...`:

```elixir
config :cohere,
  dir: "cohere",                    # artifact directory
  namespace: MyApp,                 # default: camelized app name
  web_namespace: MyAppWeb,          # default: <Namespace>Web when present
  ignore: [MyApp.DevHelpers]        # modules to exclude from derivation
```

## Design constraints

- **Derived or checked, nothing else.** Every artifact gets the strongest
  binding its nature allows: the map is regenerated from code (cannot
  drift), cards are authored-but-hash-bound (drift fails the build), and
  designs are authored-but-dated — anchored to the map, promise-verified
  at completion, advisory ever after. Unbound prose is future lies.
- **Zero runtime dependencies.** Ecto/Phoenix appear only as test deps for
  fixture reflection. Consumers inherit nothing.
- **No LLM calls.** Deterministic, CI-runnable, same bytes for same code.
- **Link, don't restate.** Packets carry source records and pointers; they
  never paraphrase code into a second truth.

The full research and design rationale — what Palantir's Ontology and
8090's Software Factory are actually selling, why the failure modes of
spec-driven development all point the same direction, and why Elixir is
the cheapest stack to build this on — lives in
[cohere/design/design-spec.md](cohere/design/design-spec.md), an accepted
design doc in cohere's own coherence layer. The feature loop's own design
is [cohere/design/feature-loop.md](cohere/design/feature-loop.md) —
completed by the tool it specifies.

## License

MIT
