# Reference

<div class="stamp">derived · task moduledocs, via reflection · cohere 0.1.0</div>

Every entry below is read from the compiled task's own `@shortdoc`
and `@moduledoc`. The reference cannot drift from the tool, because
it is the tool describing itself.

## mix cohere

*Reports where the project stands on the coherence ladder*

Prints the project's current coherence level and what the next rung
requires.

    $ mix cohere

Levels: 1 static guidance, 2 derived map, 3 checked intent cards,
4 governed verbs / runtime verification, 5 delivered context (packets).

Registered derived artifacts (`config :cohere, derived:`) count toward
the L2 rung — they are the map's discipline applied to other committed
outputs — and are listed with their freshness below the ladder.


## mix cohere.init

*Sets up the coherence layer in this project*

Creates the `cohere/` directory (map, `intent/`, `design/`), derives the
first map, writes a README explaining the feature loop, and syncs the
agent-guidance block into `AGENTS.md` — the loop's instructions, landed
where agents already look.

    $ mix cohere.init
    $ mix cohere.init --into CLAUDE.md   # guidance file of choice

Re-running is safe and is how the guidance block stays current across
cohere upgrades: only the marker-bounded block is regenerated; the
seeded working agreement and everything else in the file is never
touched.

Deliberately does *not* generate an intent card per context — empty cards
are noise. Start with the two or three contexts where intent actually
accumulates (`mix cohere.gen.intent <context>`); add more when a context
earns one.


## mix cohere.design

*Starts a design: scaffolds a draft doc with its existing ground*

The start verb of the feature loop — and, with no arguments, the listing.

    $ mix cohere.design                                    # list designs + statuses
    $ mix cohere.design deal-reversals --contexts deals,billing
    $ mix cohere.design deal-reversals                     # contexts from the branch diff
    $ mix cohere.design deal-reversals --base develop      # …diffed against a given ref

Scaffolds `cohere/design/deal-reversals.md` (status: draft) and
assembles its Existing ground: for each anchored context, the current
API from the map plus the invariants and decisions from its intent
card — the constraints the design should be shaped against, delivered
onto the page where the designing happens.

With `--contexts` omitted, the anchors are inferred from the branch
diff, the way `mix cohere.packet --diff` maps changed files to the
contexts that own them. Design-first stays the primary path — the flag
is explicit intent; inference serves the retrofit, where the change is
underway before anyone admits it deserved a design.

Anchoring a context that doesn't exist yet is fine — the design may be
the thing that introduces it; `mix cohere.complete` verifies it landed.

Iterate with `mix cohere.check`; land with `mix cohere.complete <slug>`.


## mix cohere.check

*Checks coherence — map, cards, and designs in one pass*

The check verb of the feature loop: run it anytime, locally or in CI;
fix what it lists and run it again.

    $ mix cohere.check                            # exit 1 on hard drift (the CI gate)
    $ mix cohere.check --accept deals             # rebind the deals card after re-review
    $ mix cohere.check --accept deals --by greg   # …recording who judged (default: git user.name)

Hard findings fail the build: a stale map, an intent card whose context
surface moved since review, a card referencing dead code. Design docs
only ever produce advisories — an accepted design is a dated record, and
drift on history is information, not a build failure.

Accepting drift is a review action: re-read the card against the current
map first. The annotation records that the surface change was seen and
deemed consistent with the card's intent.


## mix cohere.complete

*Completes a design: verifies its promises landed, flips it to accepted*

The complete verb of the feature loop — the land step, one command.

    $ mix cohere.complete deal-reversals

Regenerates the map (mechanical, so it just happens), then requires:

  * the check hard-clean — drifted cards must be re-reviewed and
    accepted first, which is exactly the moment the design's durable
    decisions get distilled into the cards it anchors
  * every ref in Promised surface resolving in the compiled app — a
    design that promised `reverse_deal/1` cannot complete until
    `reverse_deal/1` exists
  * every anchored context present in the map

Unresolved open questions warn but never block (DEC-FEA-007) —
questions legitimately outlive features. On success the design flips
`draft → accepted` with a dated Status log line. Accepted designs are
immutable history: supersede them with a new design, never edit them.


## mix cohere.map

*Regenerates the derived system map*

Derives the system map from the compiled application and writes it to
`cohere/map.md` (configurable via `config :cohere, dir: ...`).

    $ mix cohere.map

The map is deterministic: same code in, same bytes out. Commit it; the
diff on a PR *is* the ontology change.


## mix cohere.gen.intent

*Generates intent card skeletons for contexts*

Generates an intent card skeleton for each named context, bound to its
current public surface (so a fresh card is born non-drifted).

    $ mix cohere.gen.intent deals billing
    $ mix cohere.gen.intent --all        # every context-ful group
    $ mix cohere.gen.intent deals --force  # overwrite an existing card

Cards are the *authored* layer — the skeleton is scaffolding, not
content. Fill in only what cannot be derived: purpose, invariants,
decisions, non-goals. If a section has nothing durable to say, leave it
empty rather than restating the code.


## mix cohere.packet

*Assembles a work packet for the contexts a task touches*

Prints a work packet — map slices, intent cards, anchored designs
(drafts inlined as live intent, accepted as pointers), per-directory
agent guidance, related routes, and runtime-verification pointers —
for the contexts a task touches.

    $ mix cohere.packet deals billing        # contexts named explicitly
    $ mix cohere.packet --diff                # contexts touched by this branch
    $ mix cohere.packet --diff --base develop # …diffed against a given ref
    $ mix cohere.packet deals --out packet.md

With `--diff`, cohere maps the branch's changed files to the contexts that
own them (reflection over compiled modules, not path guessing) and
assembles the packet for exactly those — the dispatch integration point: a
work loop calls it with no arguments and gets the right slice. `--base`
sets the ref to diff against (default `main`).

Feed the packet to whatever does the work: paste it into a session, wire
it into a dispatch prompt, or hand it to a teammate. Context delivered,
not discovered.

