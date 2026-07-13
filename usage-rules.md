# cohere usage rules

- `cohere/map.md` is derived. NEVER edit it by hand; run `mix cohere.map`
  after any structural change (new/renamed public context functions,
  schema fields, associations, routes, workers) and commit the diff in the
  same PR. The map diff is the ontology change — review it as such.
- If `cohere/map.md` disagrees with the code, the file is stale — never
  the other way around. Regenerate; do not "fix" the map.
- `cohere/intent/*.md` cards hold authored intent: purpose, invariants,
  decisions, non-goals. Edit the sections freely; NEVER edit the
  frontmatter (`context`/`reviewed`/`surface`/`functions`) by hand — it is
  machine-managed.
- When `mix cohere.check` reports a drifted card: re-read the card against
  the current map and update any invalidated content. `--accept` is
  human-gated, and the gate is an explanation, not a paste: tell the human
  which design or decision drove the drift, show the exact `+fun/1 −fun/2`
  delta, and say what your card edits now claim, so their confirmation is
  informed — then run `mix cohere.check --accept <card>` with
  `--by <approver>`. Do not accept without re-reading, and never
  unilaterally.
- Non-trivial change? Start with `mix cohere.design <slug> --contexts <ctx>`
  and design in the doc, against its Existing ground section. Record
  decisions with their rejected alternatives; list the code you commit to
  delivering under Promised surface as backticked `Module.fun/arity` refs.
- `cohere/design/*.md` frontmatter is machine-managed except `contexts:`
  and `supersedes:`. Never flip `status:` by hand — that is
  `mix cohere.complete <slug>`, which verifies the promised surface exists
  before accepting. Accepted designs are immutable history: supersede with
  a new design, never edit.
- When a card re-review happens after a design lands, distill the design's
  durable decisions into the card and cite the design by slug — the card
  is the living constraint; the design is the record of the conversation.
- A violated invariant or superseded decision in a card is either a bug in
  your change or a deliberate supersession — surface it explicitly; never
  silently contradict a card.
- Before starting work that touches a context, run
  `mix cohere.packet <contexts>` and read it instead of re-exploring the
  repo. Trust the map for shape; read code for behavior. On an existing
  branch, `mix cohere.packet --diff` assembles the packet for exactly the
  contexts you changed; read its "Branch scope" note for changed files that
  did not map to a context and verify those by hand.
- Do not copy facts from the map or cards into other documents. Link to
  them. One truth per fact.
- `mix cohere.check` must exit 0 before a PR is done. Fix or accept —
  never ignore. Design advisories don't fail the build; read them anyway.
