---
title: Intent cards
nav: 5
description: The authored layer — purpose, invariants, decisions — hash-bound to the code so drift fails the build.
---

The map states what the system *is*; it cannot state what the system
is *for*. Intent cards carry the half that can't be derived: purpose,
invariants, decisions with their rejected alternatives, non-goals.
One small file per context, in `cohere/intent/`.

```markdown
---
context: MyApp.Deals
surface: df8be63a83b8
functions: approve_deal/1 create_deal/1 ...
---

## Purpose
One sentence a new engineer reads first.

## Invariants
- INV-DEA-001: a posted deal is immutable; corrections go
  through reversal, never edit.

## Decisions
- DEC-DEA-002 (2026-03-11): fee math uses integer cents.
  Rejected: Decimal (rounding at the boundaries leaked).

## Non-goals
- Commission forecasting. See MyApp.Insights.
```

Invariants are the constraints an agent must not violate; decisions
carry the *rejected alternatives*, which is the half of institutional
memory that otherwise dies in chat scrollback. The next actor doesn't
just learn what was chosen — they learn what was tried.

## Hash-bound, not hoped

The frontmatter is machine-managed: cohere stamps the card with the
context's current surface hash *and* its full function list. When the
code's public surface moves, the card is **drifted** and
`mix cohere.check` fails the build — with an exact delta, not a vibe:

<pre><code><span class="hazard">✗ cohere/intent/deals.md
  surface drifted: +approve_deal/1 −legacy_approve/2</span>
  → re-review the card, then `mix cohere.check --accept deals`</code></pre>

Storing the function list alongside the hash costs one machine-managed
line and buys those exact `+fun/1 −fun/2` deltas without depending on
git state.

## Accepting drift

Accepting is a review action, not a bypass. `mix cohere.check --accept
deals` rebinds the card to the new surface and appends a dated line to
the card's *Accepted drift* section — silent rebinding is not a
supported path. The gate's contract is honest history: **the build
fails until a human has looked, and the looking leaves a trace.**

## What cards are not

Cards are not documentation of the API — the map already carries the
API, and restating it would create a second truth to keep honest.
A card holds only what reflection cannot reach. If a card ever
disagrees with the map, the map wins, because the map cannot lie.
Cards cite [design docs](design-docs.html) by slug for the fuller
story of any decision.
