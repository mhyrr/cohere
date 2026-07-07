# Packets

The rest of this site is about *keeping* the project coherent.
Packets spend that coherence: one command assembles the minimal
context an actor needs for a task, so the session starts informed
instead of opening with an archaeology dig.

```console
$ mix cohere.packet deals billing        # context for named contexts
$ mix cohere.packet --diff               # ...or for exactly the
                                         # contexts this branch touches
```

## What's inside

For each requested context: its map entry (the real API, schemas,
routes, workers), its intent card (the invariants the work must not
violate, the decisions already made, with what was rejected), and
pointers to the source files that own it. With `--diff`, cohere reads
the branch's changed files and works out the touched contexts itself:
the packet for the work actually in flight.

## Link, don't restate

A packet carries source records and pointers; it never paraphrases
code into a second truth. The map slice is the derived record, the
card is the authored record, and the rest is pointers into source.
Paraphrase is how context layers rot, so the format simply has no
place for it.

## Runtime verification, when it's there

Cohere probes the host app rather than requiring anything of it. When
Tidewave is present, the packet's verification section directs the
agent to confirm behavior against the *running* application instead
of inferring it from source: `project_eval` for code paths,
`execute_sql_query` for data shape. When it isn't, the packet says
so, and verification falls back to the test suite.

## Where the guarantees compound

The ladder's lower levels each strengthen a guarantee. Because the map
[cannot lie](the-map.html), the API in the packet is current. Because
cards are [hash-bound](intent-cards.html), the invariants in the
packet were re-reviewed the last time the surface moved. Because
[designs](design-docs.html) are dated records, the packet's history is
honest. Delivered context is only as good as the coherence behind it.
