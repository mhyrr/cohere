# The loop

The developer surface is three verbs. Credo got the shape right: one
iterative command you run until it comes back quiet, identical locally
and in CI.

```console
$ mix cohere.design deal-reversals --contexts deals   # START
$ mix cohere.check                                    # CHECK: anytime
$ mix cohere.complete deal-reversals                  # COMPLETE
```

## Start

`mix cohere.design deal-reversals --contexts deals` scaffolds
`cohere/design/deal-reversals.md` with `status: draft` and assembles
its **Existing ground**: each anchored context's current API from the
map, plus the invariants and decisions from its intent card, dated.

A no-LLM tool can't judge that your design contradicts INV-DEA-002.
It does something better suited to a deterministic tool: it delivers
INV-DEA-002 onto the page where you're designing, where a
contradiction is hard to miss.

## Check

Every finding comes with the action that fixes it. Hard findings exit
1: a stale map, a drifted card, a dead card reference. Design findings
are advisories and never fail the build; an accepted design is a dated
record, and drift on history is information, not a bug.

<pre><code>$ mix cohere.check
<span class="hazard">✗ cohere/intent/deals.md
  surface drifted: +approve_deal/1</span>
  → re-review the card, then `mix cohere.check --accept deals`
⚠ cohere/design/deal-reversals.md — draft, advisory only
  anchor "Reversals" not in the map — fine if this design introduces it

<span class="hazard">drift detected</span></code></pre>

A drifted card means: re-read it against the new surface, update what
your change invalidated, then accept. Accepting always leaves a dated
trace in the card. **Accepted drift is documented drift**, and the
failure mode this loop exists to kill is the silent kind.

```console
$ mix cohere.check --accept deals
cohere/intent/deals.md — rebound to surface df8be63a83b8, drift annotated
```

## Complete

`mix cohere.complete deal-reversals` is the land step, one command:

1. Regenerate the map. Mechanical, so it just runs.
2. Require the check hard-clean, which forces the card re-review
   where the design's durable decisions get distilled into cards.
3. Verify every backticked ref in the design's **Promised surface**
   exists in the compiled app. A design that promised `reverse_deal/1`
   cannot complete until `reverse_deal/1` exists.
4. Flip `draft → accepted`, dated, and log it.

The PR that lands the feature carries the map delta (the ontology
change), the card delta (the intent change), the accepted design (the
why), and the code, all reviewable together.

## After acceptance

Accepted designs are immutable. New thinking later is a *new* design
naming the old one in its `supersedes:` frontmatter; history is
superseded, never rewritten. Cards are the living constraints; designs
are the conversation record. Two living truths about the same intent
always diverge, so cohere keeps exactly one.
