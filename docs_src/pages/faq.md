---
title: FAQ
nav: 8
description: Common questions, short answers.
---

## Concept

### Isn't this just documentation with extra steps?

Documentation rots quietly over time, which is what we're trying to
target. The map can't rot (it's derived), cards rot loudly (the build
fails), designs are allowed to age (they're dated history). Every
artifact gets a different binding constraint useful to both humans
and agents.

### Why not just watch git diffs?

Git can only see that text changed. The surface hash tracks
contracts. File churn isn't drift: refactors, private helpers, and
comments never move the public surface, so the card stays quiet. Drift isn't always file
churn: macro-generated functions, a new `defdelegate`, or a relocated
module change the surface without touching the paths a git rule
watches, and reflection over the compiled module catches them anyway.
Git also always needs a baseline (changed since *when?*), while a card
holds the surface it was reviewed against, which works in a shallow
clone and survives any rebase. And a git rule is satisfied by touching
the doc in the same PR; `--accept` rewrites the binding and leaves a
dated trace. The surface hash is a lockfile for intent.

### Agents keep getting better. Won't they just read the code?

Reading code gets you what the code is, re-derived expensively every
session. It can't get you what isn't in the code at all: no context
window derives "we rejected Decimal because rounding leaked at the
boundaries." The map is a cache of everything derivable from the
code. Cards exist for the part that isn't.

### Why doesn't the tool use an LLM?

A gate has to be deterministic to sit in CI: the same repo must
produce the same verdict, with nothing to flake and no API bill to
pay. A summary that can hallucinate is just more unbound prose.
Models consume the outputs and are never trusted to produce them.

### How is this different from spec-driven development?

Spec-first tools verify that evidence exists for what you authored.
Cohere derives truth from the compiled app and works to bind authored
intent to it. One asks "does
the spec have a pointer," the other asks "does the code still match
the intent."

## Mechanisms

### The hash covers the public surface. What about a behavior change that keeps the signature?

It doesn't. The hash catches changes to the contract's shape.
Behavior belongs to the test suite, and at level 4 to runtime
verification. The card's invariants exist to tell the test writer
what must stay true.

### Won't `--accept` become a rubber stamp?

It can. But the stamp is dated, attributable, and attached to an
exact `+fun/1 −fun/2` delta. Nothing can force a reviewer to think,
but the review now leaves an attributable record.

### Who wins when the card and the code disagree?

On facts, the map, because nobody authors it. On intent, the human:
disagreement halts the build until someone re-reviews, instead of the
tool guessing.

### Why cards per context instead of per module?

Contexts are where intent lives, and they are the boundary
vocabulary. Finer-grained is moduledoc territory, and
moduledocs stay exactly where they are. Cards carry what they
structurally can't: cross-cutting invariants, rejected alternatives,
etc.

### Isn't AGENTS.md enough?

AGENTS.md is level 1 on the [ladder](ladder.html): unverified
authored guidance, often stale the week after it's written. Keep it
for workflow and conventions. The system's shape and constraints
belong in artifacts that are derived or gated.

## Trade-offs

### I have 200 modules of legacy. Do I card everything?

No. Uncarded contexts are informational, not failures. Derive the
map with one command, card the two or three contexts where intent
actually matters, and stop there. Money, auth, and tenancy are the
usual three.

### More files I'll forget to maintain.

The map maintains itself. Cards only demand attention when a public
surface moves, and then the build stops and names the exact delta.

### Am I locked in?

No. It's a dev and test dependency with zero runtime dependencies, and
every artifact is plain markdown in your repo. Remove the package and
you keep readable docs. Production never knew cohere existed.

### I'm solo. Overkill?

The teammate with amnesia is already on your project: every agent
session starts cold. Solo devs already have the multiplayer problem,
just nobody else to blame.

### Umbrella apps? Ash?

Not validated yet. Cohere probes for capabilities rather than
requiring them, but neither umbrella roots nor Ash resources have been
run against a real project. Until they have, assume unsupported, and
file what you find.
