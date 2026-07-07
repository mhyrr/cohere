# Design docs

Every non-trivial change starts with a design conversation. Without a
home, it lands in a wiki, a gist, a chat scrollback — a hairy pile of
documents no tool reads and no gate keeps honest. Design docs give
that conversation one format, one directory (`cohere/design/`), and a
lifecycle the tooling enforces.

## Anatomy

A design doc is frontmatter — `design`, `status: draft | accepted |
superseded`, `date`, `contexts`, optionally `supersedes` — plus
sections: Problem, Existing ground, Shape, Promised surface,
Decisions, Open questions, Status log.

Two sections do the heavy lifting:

### Existing ground

Assembled by `mix cohere.design` when the doc is born: each anchored
context's current API from the map, plus the invariants and decisions
from its intent card, inlined as a **dated snapshot**. Constraints
nobody opens don't constrain anything — so the constraints are
delivered onto the page where the designing happens. A design is a
dated record; quoting the ground as-of its date is a quote in a
meeting record, not a second truth.

### Promised surface

The backticked refs the design commits to delivering. This is what
makes a design doc a **mechanically checkable spec** instead of
aspirational prose: `mix cohere.complete` fails until every promised
ref resolves in the compiled app. Promise `MyApp.Deals.reverse_deal/1`
and the design cannot land without it.

## Lifecycle

- **Draft** — work in flight. The draft *is* the in-flight state;
  there is no dotfile, no registry. Check reads status fresh from disk.
- **Accepted** — `mix cohere.complete` verified the promises, flipped
  the status, dated the log. Accepted designs are immutable history.
- **Superseded** — new thinking is a *new* doc naming the old slug in
  its `supersedes:` frontmatter. History is superseded, never edited.

## Advisory by construction

Design findings never fail the build — only the map and cards can
exit 1. A design that has drifted from today's code is *history doing
its job*: drift on intent is a bug, drift on history is information.
The gate lives where the living documents live; the record stays a
record.

One direction of flow ties it together: completing a design forces the
anchored cards through re-review, which is the moment the design's
durable decisions get distilled into [intent cards](intent-cards.html)
— and cards cite designs by slug. Conversation becomes constraint;
the trail stays walkable.
