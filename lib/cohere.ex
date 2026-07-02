defmodule Cohere do
  @moduledoc """
  A coherence layer for Elixir/Phoenix projects.

  A project is coherent to the degree that, at any point in its development,
  it can furnish any actor — human or model — with the minimal context
  sufficient to act in line with the user's intent, and can mechanically
  detect when the project has drifted from that intent.

  Cohere makes that a measurable property of the project rather than a
  behavior of the agent, via three artifacts and the tooling that keeps
  them honest:

    * **The map** (`mix cohere.map`) — a compact, git-tracked description of
      the system's actual shape, derived from the compiled application:
      contexts and their public API, Ecto schemas and associations, Phoenix
      routes, Oban workers and cron wiring. Never hand-edited, regenerated
      on demand, therefore it cannot lie.

    * **Intent cards** (`mix cohere.gen.intent`) — one small authored file
      per context holding only what cannot be derived: purpose, invariants,
      decisions with rejected alternatives, non-goals. Each card is bound to
      the context's public surface by hash.

    * **The drift sentinel** (`mix cohere.drift`) — CI-runnable check that
      the map matches the code and every card matches its context's surface.
      Drift is fixed or explicitly accepted with a dated annotation — never
      silent.

  Work packets (`mix cohere.packet`) assemble the map slice and cards for
  the contexts a task touches, so context is delivered to an agent rather
  than rediscovered by it.

  ## The coherence ladder

  | Level | Property | Mechanism |
  |---|---|---|
  | 0 | Context by discovery | raw repo; agents grep and hope |
  | 1 | Static guidance | AGENTS.md / usage-rules |
  | 2 | Derived truth | the map |
  | 3 | Authored intent, checked | intent cards + drift sentinel |
  | 4 | Governed verbs, verified behavior | boundary enforcement, Tidewave runtime |
  | 5 | Delivered context | work packets |

  Each level is useful alone; adopt incrementally. `mix cohere` reports
  where a project currently stands.

  ## Design constraints

  Cohere has **zero runtime dependencies** and makes **no LLM calls**:
  everything it produces is deterministic and CI-runnable. It probes for
  what's present (Ecto, Phoenix, Oban, boundary, Ash, Tidewave) and derives
  more when more is there — capability detection, not a required stack.
  """

  @doc "The installed cohere version."
  def version do
    Application.spec(:cohere, :vsn) |> to_string()
  end
end
