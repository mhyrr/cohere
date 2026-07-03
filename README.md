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

It does this with two artifacts and a sentinel:

- **The map** — the actual shape of your system, *derived* from the
  compiled application: contexts and their public API, Ecto schemas with
  real types and associations, Phoenix routes (LiveView unwrapped), Oban
  workers with queue and cron wiring. Never hand-edited, regenerated on
  demand — therefore it cannot lie.
- **Intent cards** — one small authored file per context holding only what
  cannot be derived: purpose, invariants, decisions with their rejected
  alternatives, non-goals. Each card is hash-bound to its context's public
  surface.
- **The drift sentinel** — a CI gate that fails when the map is stale, when
  a card's surface moved out from under it, or when a card references code
  that no longer exists. Drift is fixed or explicitly accepted with a dated
  annotation — never silent.

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
$ mix cohere.drift                 # CI gate: exit 1 on any drift
$ mix cohere.packet deals billing  # assemble delivered context for a task
$ mix cohere.packet --diff         # …or for exactly the contexts this branch touches
```

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

## The drift workflow

```console
$ mix cohere.drift
✗ cohere/intent/deals.md
  surface drifted: +approve_deal/1
  → re-review the card, then `mix cohere.drift --accept deals`

$ mix cohere.drift --accept deals
cohere/intent/deals.md — rebound to surface df8be63a83b8, drift annotated
```

Accepting appends a dated annotation to the card's `## Accepted drift`
section. Accepted drift is documented drift; the failure mode this tool
exists to kill is the *silent* kind.

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
| `mix cohere` | ladder status |
| `mix cohere.init` | scaffold `cohere/`, first map, workflow README |
| `mix cohere.map` | regenerate the derived map |
| `mix cohere.drift` | drift check; exit 1 on drift (`--accept <card>` to rebind) |
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

- **Derived or checked, nothing else.** Every artifact is either
  regenerated from code (cannot drift) or authored-but-hash-bound (drift is
  mechanically detected). Anything else is future lies.
- **Zero runtime dependencies.** Ecto/Phoenix appear only as test deps for
  fixture reflection. Consumers inherit nothing.
- **No LLM calls.** Deterministic, CI-runnable, same bytes for same code.
- **Link, don't restate.** Packets carry source records and pointers; they
  never paraphrase code into a second truth.

The full research and design rationale — what Palantir's Ontology and
8090's Software Factory are actually selling, why the failure modes of
spec-driven development all point the same direction, and why Elixir is
the cheapest stack to build this on — lives in
[docs/design-spec.md](docs/design-spec.md).

## License

MIT
