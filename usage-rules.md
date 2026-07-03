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
- When `mix cohere.drift` reports a drifted card: re-read the card against
  the current map, update any invalidated content, then run
  `mix cohere.drift --accept <card>`. Do not accept without re-reading.
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
- `mix cohere.drift` must exit 0 before a PR is done. Fix or accept —
  never ignore.
