# Overview

<div class="hero">
<svg class="hero-contours" viewBox="0 0 300 220" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="#8a6b4d" stroke-width="1">
<path d="M138 14 C 200 4, 262 30, 284 74 C 300 108, 288 152, 246 180 C 204 208, 132 216, 84 196 C 40 178, 14 140, 22 98 C 30 52, 80 24, 138 14 Z" opacity="0.45"/>
<path d="M142 38 C 192 30, 244 50, 260 84 C 273 112, 258 146, 226 166 C 190 188, 134 192, 96 174 C 62 158, 44 128, 52 96 C 60 62, 98 45, 142 38 Z" opacity="0.58"/>
<path d="M148 62 C 186 56, 224 72, 236 96 C 246 116, 232 140, 206 152 C 178 165, 136 166, 110 152 C 86 139, 76 116, 84 94 C 92 72, 116 67, 148 62 Z" opacity="0.72"/>
<path d="M154 86 C 180 82, 204 92, 211 106 C 217 118, 208 132, 190 139 C 172 146, 146 146, 130 137 C 116 129, 112 114, 119 102 C 126 91, 134 89, 154 86 Z" opacity="0.88"/>
<text x="268" y="52" font-family="Fragment Mono, monospace" font-size="9" fill="#8a6b4d" stroke="none" opacity="0.8">7</text>
<text x="242" y="128" font-family="Fragment Mono, monospace" font-size="9" fill="#8a6b4d" stroke="none" opacity="0.8">12</text>
<text x="58" y="72" font-family="Fragment Mono, monospace" font-size="9" fill="#8a6b4d" stroke="none" opacity="0.8">23</text>
</svg>
<p class="hero-thesis">A project is coherent to the degree that it can furnish any actor — human or model — with the minimal context sufficient to act in line with intent, and can mechanically detect when it has drifted.</p>
<p class="hero-attribution">the working definition · everything below is machinery for it</p>
</div>

Models are intelligent but context-starved, and the failure mode of
context starvation is incoherence: sessions rediscover the same facts
expensively, and codebases drift as hundreds of locally-reasonable
changes accumulate with no shared frame. Cohere makes coherence a
**measurable property of the project** instead of a hoped-for behavior
of the agent.

No LLM calls. Zero runtime dependencies. Everything is deterministic
and CI-runnable — models *consume* the outputs but are never required
to produce them.

## Three documents, checked as hard as their nature allows

- **[The map](the-map.html)** — the actual shape of your system,
  *derived* from the compiled application. Never hand-edited,
  regenerated on demand — therefore it cannot lie.
- **[Intent cards](intent-cards.html)** — one small authored file per
  context holding only what cannot be derived: purpose, invariants,
  decisions with their rejected alternatives. Hash-bound to the code's
  public surface; drift fails the build.
- **[Design docs](design-docs.html)** — one authored file per design.
  Drafts are work in flight; accepted designs are immutable, dated
  history whose promises were mechanically verified.

The rule underneath all three: **derived or checked, nothing else.**
Unbound prose is future lies.

## Quickstart

```elixir
# mix.exs — dev/test only; consumers inherit nothing
{:cohere, "~> 0.1", only: [:dev, :test]}
```

```console
$ mix cohere.init            # scaffold cohere/, derive the first map
$ mix cohere                 # where does this project stand?
```

## The loop

Three verbs; everything else is plumbing their output points at.
[Walk it end to end.](loop.html)

```console
$ mix cohere.design deal-reversals --contexts deals    # START
    ... design in the doc, against its ground ...
$ mix cohere.check                     # CHECK — anytime; fix, repeat
    ... build ...
$ mix cohere.complete deal-reversals   # COMPLETE — when check is quiet
```

`mix cohere.check` runs identically in CI and exits 1 on hard drift —
a stale map, a drifted card, a dead reference. The failure mode this
tool exists to kill is the *silent* kind.

## Reading on

The [coherence ladder](ladder.html) places all of this on five
incremental levels — each useful alone. [Work packets](packets.html)
are the payoff: context delivered to an agent, not discovered by one.
And [cohere on cohere](self.html) shows the tool run on this very
repository, live.
