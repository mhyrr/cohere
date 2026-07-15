# Changelog

## v0.1.1 (2026-07-15)

Documentation release, no code changes: README, moduledoc, and docs
site reworded in a full voice pass.

## v0.1.0 (2026-07-14)

Initial release: the coherence ladder for Elixir/Phoenix.

- Derived system map (`mix cohere.map`): contexts with public surfaces and
  hashes, Ecto schemas with types/enums/associations/embeds, Phoenix
  routes with LiveView unwrapping, Oban workers with queue + cron wiring
  from config, capability detection (Ecto, Phoenix, LiveView, Oban,
  boundary, Ash, Tidewave). Deterministic output — no timestamps, stable
  ordering.
- Intent cards (`mix cohere.gen.intent`): per-context authored intent,
  hash-bound to the context's public surface.
- The feature loop, three verbs: `mix cohere.design <slug>` scaffolds a
  draft design doc with its Existing ground (map slice + card constraints
  for anchored contexts) delivered onto the page; `mix cohere.check` is
  the one iterative command and CI gate; `mix cohere.complete <slug>`
  verifies every backticked ref in the design's Promised surface exists
  in the compiled app, then flips it draft→accepted with a dated log.
  Accepted designs are immutable history — supersede, never edit.
- Coherence check (`mix cohere.check`): stale-map detection with line
  diff, card surface drift with exact +/− function deltas,
  broken-reference checks; exit 1 for CI; `--accept` rebinds a card with
  a dated annotation. Design docs produce advisories only — drift on
  history is information, drift on intent is a bug.
- Work packets (`mix cohere.packet`): map slices + inlined cards +
  name-matched routes + runtime-verification pointers (Tidewave-aware).
  `--diff` assembles the packet for exactly the contexts the current branch
  touches — changed files mapped to contexts by reflection over compiled
  modules, not path convention; unmapped files reported, never dropped
  silently. `--base REF` sets the ref to diff against (default `main`).
- Ladder status (`mix cohere`) and scaffolding (`mix cohere.init`).
  `mix cohere.design` with no arguments lists designs with statuses; the
  ladder always states design status affirmatively when designs exist
  ("none in flight" is a claim, not an absence).
- Zero runtime dependencies; no LLM calls anywhere.
