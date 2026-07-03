defmodule Mix.Tasks.Cohere.Init do
  @shortdoc "Sets up the coherence layer in this project"

  @moduledoc """
  Creates the `cohere/` directory (map, `intent/`, `design/`), derives the
  first map, and writes a README explaining the feature loop and a CI
  snippet for the check gate.

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
    File.mkdir_p!(Project.design_dir(project))

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
      3. Add the check gate to CI (snippet in #{readme_path}).
      4. Next feature? Start the loop: mix cohere.design <slug> --contexts <ctx>
      5. Check where you stand anytime: mix cohere
    """)
  end

  defp readme(project) do
    """
    # Coherence Layer

    This directory is managed with [cohere](https://hex.pm/packages/cohere).
    Three document kinds, one directory, one gate:

    - `map.md` — **derived, never hand-edited.** The actual shape of the
      system, regenerated from the compiled app by `mix cohere.map`. If it
      disagrees with the code, the file is stale — never the other way
      around.
    - `intent/*.md` — **authored, hash-bound, living.** One card per
      context, holding only what cannot be derived: purpose, invariants,
      decisions (with rejected alternatives), non-goals. When a context's
      public surface moves, its card drifts and `mix cohere.check` fails
      until someone re-reviews it.
    - `design/*.md` — **authored, dated, immutable once accepted.** One doc
      per design: problem, existing ground, shape, promised surface,
      decisions. Drafts are work in flight; accepted designs are history.
      Supersede them, never edit them.

    ## The feature loop

        $ mix cohere.design deal-reversals --contexts deals   # START
          ... design in the doc, against its Existing ground ...
        $ mix cohere.check                                    # CHECK — anytime; fix, repeat
          ... build ...
        $ mix cohere.check                                    # same command, new findings
        $ mix cohere.complete deal-reversals                  # COMPLETE — when check is quiet

    **Start** scaffolds the design doc and delivers the constraints it
    should be shaped against (map slice + card invariants/decisions for
    each anchored context) onto the page.

    **Check** is one iterative command, identical locally and in CI. Hard
    findings exit 1: stale map, drifted cards, dead card references.
    Design findings are advisories, never failures. A drifted card means:
    re-read the card against the new surface, update what the change
    invalidates, then `mix cohere.check --accept <card>` — accepted drift
    is documented drift.

    **Complete** verifies the design's Promised surface actually exists in
    the compiled app, requires cards re-bound (that's where the design's
    durable decisions get distilled into cards), and flips the design to
    accepted with a dated log line.

    Starting a task without a design? `mix cohere.packet <contexts>` (or
    `--diff` for the current branch) assembles the delivered context.

    ## CI gate

    ```yaml
    - name: Coherence check
      run: mix cohere.check
    ```

    ## Status

    `mix cohere` reports where #{project.app} stands on the coherence
    ladder, and which designs are in flight.
    """
  end
end
