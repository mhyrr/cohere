defmodule Mix.Tasks.Cohere.Check do
  @shortdoc "Checks coherence — map, cards, and designs in one pass"

  @moduledoc """
  The check verb of the feature loop: run it anytime, locally or in CI;
  fix what it lists and run it again.

      $ mix cohere.check                  # exit 1 on hard drift (the CI gate)
      $ mix cohere.check --accept deals   # rebind the deals card after re-review

  Hard findings fail the build: a stale map, an intent card whose context
  surface moved since review, a card referencing dead code. Design docs
  only ever produce advisories — an accepted design is a dated record, and
  drift on history is information, not a build failure.

  Accepting drift is a review action: re-read the card against the current
  map first. The annotation records that the surface change was seen and
  deemed consistent with the card's intent.
  """

  use Mix.Task

  alias Cohere.{Check, Intent, Map, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [accept: :keep])
    project = Project.load()

    case Keyword.get_values(opts, :accept) do
      [] -> check(project)
      slugs -> Enum.each(slugs, &accept(project, &1))
    end
  end

  defp check(project) do
    report = Check.check(project)
    Mix.shell().info(Check.format(report))

    unless Check.Report.clean?(report) do
      exit({:shutdown, 1})
    end
  end

  defp accept(project, slug) do
    path = Path.join(Project.intent_dir(project), slug <> ".md")

    unless File.exists?(path) do
      Mix.raise("no intent card at #{path}")
    end

    {:ok, card} = Intent.parse(File.read!(path), path)
    map = Map.build(project)
    group = Enum.find(map.groups, &(&1.context == card.context))

    unless group do
      Mix.raise(
        "context #{inspect(card.context)} no longer exists — " <>
          "update the card's `context:` line (or delete the card) instead of accepting"
      )
    end

    if group.surface_hash == card.surface do
      Mix.shell().info("#{path} — already in sync, nothing to accept")
    else
      updated = Intent.accept_drift(File.read!(path), group, Date.utc_today())
      File.write!(path, updated)
      Mix.shell().info("#{path} — rebound to surface #{group.surface_hash}, drift annotated")
    end
  end
end
