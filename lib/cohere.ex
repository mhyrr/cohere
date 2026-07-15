defmodule Cohere do
  @moduledoc """
  A coherence layer for Elixir/Phoenix projects.

  A project is coherent to the degree that, at any point in its development,
  it can furnish any actor, human or model, with the minimal context
  sufficient to act in line with the user's intent, and can mechanically
  detect when the project has drifted from that intent.

  Cohere makes that a measurable property of the project rather than a
  behavior of the agent, via three document kinds and the tooling that
  keeps them honest:

    * **The map** (`mix cohere.map`). A compact, git-tracked description of
      the system's actual shape, derived from the compiled application:
      contexts and their public API, Ecto schemas and associations, Phoenix
      routes, Oban workers and cron wiring. Never hand-edited, regenerated
      on demand, so it cannot lie.

    * **Intent cards** (`mix cohere.gen.intent`). One small authored file
      per context holding only what cannot be derived: purpose, invariants,
      decisions with rejected alternatives, non-goals. Each card is bound to
      the context's public surface by hash. Living constraints.

    * **Design docs** (`mix cohere.design`). One authored file per design:
      problem, existing ground, shape, promised surface, decisions. Drafts
      are work in flight; accepted designs are immutable history.

  The developer surface is the **feature loop**, three verbs:
  `mix cohere.design <slug>` starts a design with its ground delivered
  onto the page; `mix cohere.check` is the one iterative command (and CI
  gate: hard findings exit 1, design findings only advise); and
  `mix cohere.complete <slug>` verifies the design's promised surface
  exists in the compiled app, then flips it to accepted.

  Work packets (`mix cohere.packet`) assemble the map slice and cards for
  the contexts a task touches, so context is delivered to an agent rather
  than rediscovered by it.

  ## The coherence ladder

  | Level | Property | Mechanism |
  |---|---|---|
  | 0 | Context by discovery | raw repo; agents grep and hope |
  | 1 | Static guidance | AGENTS.md / usage-rules |
  | 2 | Derived truth | the map |
  | 3 | Authored intent, checked | intent cards + design docs + the check gate |
  | 4 | Governed verbs, verified behavior | boundary enforcement, Tidewave runtime |
  | 5 | Delivered context | work packets |

  Each level is useful alone; adopt incrementally. `mix cohere` reports
  where a project currently stands.

  ## Design constraints

  Cohere has **zero runtime dependencies** and makes **no LLM calls**:
  everything it produces is deterministic and CI-runnable. It probes for
  what's present (Ecto, Phoenix, Oban, boundary, Ash, Tidewave) and derives
  more when more is there: capability detection, not a required stack.
  """

  @doc "The installed cohere version."
  def version do
    Application.spec(:cohere, :vsn) |> to_string()
  end
end
