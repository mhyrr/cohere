# FAQ

## The idea

### Isn't this just documentation with extra steps?

Documentation rots silently, and that rot is the target. The map can't
rot (it's derived), cards rot loudly (the build fails), designs are
allowed to age (they're dated history). Every artifact gets the
strongest binding its nature allows.

### Why not just watch git diffs?

Git watches text; the surface hash watches the contract. File churn
isn't drift: refactors, private helpers, and comments never move the
public surface, so the card stays quiet. Drift isn't always file
churn: macro-generated functions, a new `defdelegate`, or a relocated
module change the surface without touching the paths a git rule
watches, and reflection over the compiled module catches them anyway.
Git also always needs a baseline (changed since *when?*), while a card
names the surface it was reviewed against, which works in a shallow
clone and survives any rebase. And a git rule is satisfied by touching
the doc in the same PR; `--accept` rewrites the binding and leaves a
dated trace. The surface hash is a lockfile for intent.

### Agents keep getting better. Won't they just read the code?

Reading code gets you what the code is, re-derived expensively every
session. It can't get you what isn't in the code at all: no context
window derives "we rejected Decimal because rounding leaked at the
boundaries." The map is a cache of what can be derived from code, and
cards hold what can't be.

### Why doesn't the tool use an LLM?

A gate has to be deterministic to sit in CI: same repo, same verdict,
no flake, no API bill. A summary that can hallucinate is unbound
prose, the failure mode this exists to kill. Models consume the
outputs and are never trusted to produce them.

### How is this different from spec-driven development?

Spec-first tools verify that evidence exists for what you authored: an
ID appears in a test file, a command exits 0. Cohere derives truth
from the compiled app and binds authored intent to it. One asks "does
the spec have a pointer," the other asks "does the code still match
the intent."

## The mechanism

### The hash covers the public surface. What about a behavior change that keeps the signature?

It doesn't catch it, and claiming otherwise would be lying. The hash
catches contract shape; behavior belongs to the test suite, and at
level 4 to runtime verification. The card's invariants exist to tell
the test writer what must stay true.

### Won't `--accept` become a rubber stamp?

It can. But it's a dated, attributable stamp on an exact
`+fun/1 −fun/2` delta. Cohere can't make anyone think. It makes
not-thinking leave a trace, and silent rot becomes visible negligence.

### Who wins when the card and the code disagree?

On facts, the map, because nobody authors it. On intent, the human:
disagreement halts the build until someone re-reviews, instead of the
tool guessing.

### Why cards per context instead of per module?

Contexts are where intent lives, and Phoenix already made them the
boundary vocabulary. Finer-grained is moduledoc territory, and
moduledocs stay exactly where they are. Cards carry what they
structurally can't: cross-cutting invariants, rejected alternatives,
non-goals.

### Isn't AGENTS.md enough?

AGENTS.md is level 1 on the [ladder](ladder.html): authored guidance
nothing checks, stale the week after it's written. Keep it for
workflow and conventions. The system's shape and constraints belong in
artifacts that are derived or gated.

## The cost

### I have 200 modules of legacy. Do I card everything?

No. Uncarded contexts are informational, never failures. Derive the
map with one command, card the two or three contexts where intent
actually matters, and stop there. Money, auth, and tenancy are the
usual three.

### More files I'll forget to maintain.

The map maintains itself. Cards only demand attention when a public
surface moves, and then the build stops and names the exact delta.
Forgetting is the one failure mode that has been made impossible.

### Am I locked in?

No. It's a dev and test dependency with zero runtime dependencies, and
every artifact is plain markdown in your repo. Remove the package and
you keep readable docs. Production never knew cohere existed.

### I'm solo. Overkill?

The teammate with amnesia is already on your project: every agent
session starts cold. Solo devs have the multiplayer problem, just with
nobody else to blame it on.

### Umbrella apps? Ash?

Not validated yet. Cohere probes for capabilities rather than
requiring them, but neither umbrella roots nor Ash resources have been
run against a real project. Until they have, assume unsupported, and
file what you find.
