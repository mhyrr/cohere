# Changelog

## v0.1.0 (unreleased)

Initial release: the coherence ladder for Elixir/Phoenix.

- Derived system map (`mix cohere.map`): contexts with public surfaces and
  hashes, Ecto schemas with types/enums/associations/embeds, Phoenix
  routes with LiveView unwrapping, Oban workers with queue + cron wiring
  from config, capability detection (Ecto, Phoenix, LiveView, Oban,
  boundary, Ash, Tidewave). Deterministic output — no timestamps, stable
  ordering.
- Intent cards (`mix cohere.gen.intent`): per-context authored intent,
  hash-bound to the context's public surface.
- Drift sentinel (`mix cohere.drift`): stale-map detection with line diff,
  card surface drift with exact +/− function deltas, broken-reference
  checks; exit 1 for CI; `--accept` rebinds with a dated annotation.
- Work packets (`mix cohere.packet`): map slices + inlined cards +
  name-matched routes + runtime-verification pointers (Tidewave-aware).
- Ladder status (`mix cohere`) and scaffolding (`mix cohere.init`).
- Zero runtime dependencies; no LLM calls anywhere.
