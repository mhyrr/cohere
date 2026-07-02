defmodule Mix.Tasks.Cohere.Init do
  @shortdoc "Sets up the coherence layer in this project"

  @moduledoc """
  Creates the `cohere/` directory, derives the first map, and writes a
  README explaining the workflow and a CI snippet for the drift gate.

      $ mix cohere.init

  Deliberately does *not* generate an intent card per context — empty cards
  are noise. Start with the two or three contexts where intent actually
  accumulates (`mix cohere.gen.intent <context>`); add more when a context
  earns one.
  """

  use Mix.Task

  alias Cohere.{Map, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    project = Project.load()
    map = Map.build(project)

    File.mkdir_p!(Project.intent_dir(project))

    readme_path = Path.join(project.dir, "README.md")

    unless File.exists?(readme_path) do
      File.write!(readme_path, readme(project))
      Mix.shell().info("created #{readme_path}")
    end

    Mix.Task.run("cohere.map")

    suggestions =
      map.groups
      |> Enum.filter(&(&1.kind == :domain))
      |> Enum.sort_by(&(-length(&1.functions)))
      |> Enum.take(3)
      |> Enum.map_join(" ", &Macro.underscore(&1.name))

    Mix.shell().info("""

    Coherence layer initialized. Next steps:

      1. Commit #{project.dir}/ — the map diff on future PRs is the ontology change.
      2. Write intent cards for the contexts that carry the most intent:
           mix cohere.gen.intent #{suggestions}
      3. Add the drift gate to CI (snippet in #{readme_path}).
      4. Check where you stand anytime: mix cohere
    """)
  end

  defp readme(project) do
    """
    # Coherence Layer

    This directory is managed with [cohere](https://hex.pm/packages/cohere).

    - `map.md` — **derived, never hand-edited.** The actual shape of the
      system, regenerated from the compiled app by `mix cohere.map`. If it
      disagrees with the code, the file is stale — never the other way
      around.
    - `intent/*.md` — **authored, checked.** One card per context, holding
      only what cannot be derived: purpose, invariants, decisions (with
      rejected alternatives), non-goals, open questions. Each card is bound
      by hash to its context's public surface; when the surface moves, the
      card drifts and `mix cohere.drift` fails until someone re-reviews it.

    ## Workflow

    - Structural change in a PR → run `mix cohere.map`, commit the diff.
      The map diff *is* the ontology change; review it like one.
    - `mix cohere.drift` says a card drifted → re-read the card against the
      new surface. Update what the change invalidates, then
      `mix cohere.drift --accept <card>` to rebind it (adds a dated
      annotation — accepted drift is documented drift).
    - Starting a task? `mix cohere.packet <contexts>` assembles the map
      slice and cards the task touches.

    ## CI gate

    ```yaml
    - name: Coherence drift check
      run: mix cohere.drift
    ```

    ## Status

    `mix cohere` reports where #{project.app} stands on the coherence ladder.
    """
  end
end
