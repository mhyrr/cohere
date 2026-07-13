# Agent guidance

<!-- cohere:begin -->
## Coherence layer (cohere)

This project carries a coherence layer in `cohere/`: a derived
map, intent cards, design docs, and a drift gate. The loop:

- **Picking up work:** `mix cohere.packet <contexts>` (on a branch:
  `mix cohere.packet --diff`) — read it before exploring the repo.
- **Non-trivial change:** `mix cohere.design <slug> --contexts <ctx>`
  (contexts inferred from the branch diff when omitted); design in
  the doc, against its Existing ground section.
- **Anytime, and before any PR:** `mix cohere.check` — must exit 0;
  every finding prints the command that fixes it.
- **Landing:** `mix cohere.complete <slug>` — verifies the design's
  promised surface exists, then flips it to accepted.
- Never hand-edit `cohere/map.md` (derived — run
  `mix cohere.map`) or the machine-managed frontmatter of cards and
  designs.
- `mix cohere.check --accept` is a judgment, not a mechanical fix:
  before running it, surface the drift delta and your card updates
  to a human and wait for confirmation.
- Judgment actions record who: pass `--by <name>` to
  `mix cohere.check --accept` and `mix cohere.complete` (defaults to
  git user.name).
- Full rules: usage-rules.md.
<!-- cohere:end -->

### Working agreement (cohere seeds this once — edit to how your team works)

- Agents run the mechanical verbs freely: map, packet, check, and the
  design/gen.intent scaffolds.
- Accepting drift is human-gated: an agent re-reads the card, updates
  what the change invalidated, then presents the surface delta and its
  edits for verification. `mix cohere.check --accept` runs only after
  a human confirms, with `--by` naming who approved. Unexpected drift
  stops the work outright.
- `mix cohere.complete` and card edits ride in PRs — human review is
  the approval gate.
