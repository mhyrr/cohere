---
title: The ladder
nav: 2
description: Five levels of coherence, each useful alone, adopted incrementally.
---

Coherence isn't binary, and it isn't bought all at once. The ladder
names what a project actually has, level by level. `mix cohere` prints
where yours stands.

<ul class="rungs">
<li><span class="lvl">L0</span><span class="what">Context by discovery</span><span class="how">raw repo; agents grep and hope</span></li>
<li><span class="lvl">L1</span><span class="what">Static guidance</span><span class="how">AGENTS.md, usage_rules; authored, unchecked</span></li>
<li><span class="lvl">L2</span><span class="what">Derived truth</span><span class="how">a system map reflected from compiled code: mix cohere.map</span></li>
<li><span class="lvl">L3</span><span class="what">Authored intent, checked</span><span class="how">intent cards + the drift gate</span></li>
<li><span class="lvl">L4</span><span class="what">Governed verbs, verified behavior</span><span class="how">boundary enforcement, Tidewave runtime introspection</span></li>
<li><span class="lvl">L5</span><span class="what">Delivered context</span><span class="how">work packets: mix cohere.packet</span></li>
</ul>

Each level is useful alone; none requires the previous. Phoenix 1.8
ships every new project at level 1. Cohere is levels 2–5, adopted
incrementally: start with the map, add cards to the contexts that
matter, and let the rest arrive when it earns its place.

## Probing, never requiring

Cohere has zero runtime dependencies, so every capability is *probed*
in the host app rather than required of it. The more you have
installed, the more cohere derives; with nothing beyond Elixir you
still get a working, if sparse, map.

- **Ecto present.** Objects and links appear in the map: real field
  types, enum vocabularies, associations with their actual foreign keys.
- **Phoenix present.** The route surface appears, LiveView unwrapped
  to its module and action.
- **Oban present.** The job surface appears: queues, uniqueness, and
  cron wiring read from config.
- **boundary present.** Level 4 lights up: write paths are
  compiler-governed, not convention-governed.
- **Tidewave present.** Work packets direct agents to verify behavior
  in the running app (`project_eval`, `execute_sql_query`) instead of
  inferring it from source.

## What a level buys you

The rungs are ordered by the strength of the guarantee, not by effort.
L1 is prose someone wrote once; nothing checks it. L2 cannot lie but
knows nothing of intent. L3 is where the gate appears: authored intent
that the build *verifies* is still current. L4 moves enforcement into
the compiler and verification into the runtime. L5 is the payoff:
[context assembled and delivered](packets.html) for exactly the task
at hand.
