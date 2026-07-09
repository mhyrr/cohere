# Coherence Layer

This directory is managed with [cohere](https://hex.pm/packages/cohere).
Three document kinds, one directory, one gate:

- `map.md` — **derived, never hand-edited.** The actual shape of the
  system, regenerated from the compiled app by `mix cohere.map`. If it
  disagrees with the code, the file is stale — never the other way
  around.
- `intent/*.md` — **authored, hash-bound, living.** One card per
  context, holding only what cannot be derived: purpose, invariants,
  decisions (with rejected alternatives), non-goals. When a context's
  public surface moves, its card drifts and `mix cohere.check` fails
  until someone re-reviews it.
- `design/*.md` — **authored, dated, immutable once accepted.** One doc
  per design: problem, existing ground, shape, promised surface,
  decisions. Drafts are work in flight; accepted designs are history.
  Supersede them, never edit them.

## The feature loop

    $ mix cohere.design deal-reversals --contexts deals   # START
      ... design in the doc, against its Existing ground ...
    $ mix cohere.check                                    # CHECK — anytime; fix, repeat
      ... build ...
    $ mix cohere.check                                    # same command, new findings
    $ mix cohere.complete deal-reversals                  # COMPLETE — when check is quiet

**Start** scaffolds the design doc and delivers the constraints it
should be shaped against (map slice + card invariants/decisions for
each anchored context) onto the page.

**Check** is one iterative command, identical locally and in CI. Hard
findings exit 1: stale map, drifted cards, dead card references.
Design findings are advisories, never failures. A drifted card means:
re-read the card against the new surface, update what the change
invalidates, then `mix cohere.check --accept <card>` — accepted drift
is documented drift.

**Complete** verifies the design's Promised surface actually exists in
the compiled app, requires cards re-bound (that's where the design's
durable decisions get distilled into cards), and flips the design to
accepted with a dated log line.

Starting a task without a design? `mix cohere.packet <contexts>` (or
`--diff` for the current branch) assembles the delivered context.

## CI gate

```yaml
- name: Coherence check
  run: mix cohere.check
```

## Status

`mix cohere` reports where cohere stands on the coherence
ladder, and which designs are in flight.
