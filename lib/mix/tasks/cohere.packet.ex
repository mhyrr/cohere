defmodule Mix.Tasks.Cohere.Packet do
  @shortdoc "Assembles a work packet for the contexts a task touches"

  @moduledoc """
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
  """

  use Mix.Task

  alias Cohere.{Packet, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, names} =
      OptionParser.parse!(args, strict: [out: :string, diff: :boolean, base: :string])

    project = Project.load()

    if opts[:diff] do
      run_diff(project, names, opts)
    else
      run_named(project, names, opts)
    end
  end

  defp run_named(project, names, opts) do
    if names == [] do
      Mix.raise("usage: mix cohere.packet <context...> | --diff [--base REF] [--out FILE]")
    end

    case Packet.build(project, names) do
      {:ok, packet} ->
        emit(packet, opts[:out])

      {:error, {:unknown_contexts, unknown}} ->
        Mix.raise("unknown context(s): #{Enum.join(unknown, ", ")}")
    end
  end

  defp run_diff(project, names, opts) do
    if names != [] do
      Mix.shell().info("note: --diff ignores positional contexts (#{Enum.join(names, ", ")})")
    end

    files =
      case Project.changed_files(opts[:base] || "main") do
        {:ok, files} ->
          files

        {:error, message} ->
          Mix.raise(message <> " — pass --base <ref> with a branch that shares history")
      end

    case Packet.build_for_files(project, files) do
      {:ok, packet, report} ->
        if opts[:out] do
          Mix.shell().info("contexts: #{Enum.join(report.contexts, ", ")}")
        end

        emit(packet, opts[:out])

      {:error, {:no_contexts, unmapped}} ->
        Mix.raise(
          "no changed file mapped to a known context. #{length(unmapped)} file(s) changed; " <>
            "none belong to a derived context — web files are not yet traced to the contexts " <>
            "they call, and config/migrations/non-source never map. Name contexts explicitly."
        )
    end
  end

  defp emit(packet, nil), do: Mix.shell().info(packet)
  defp emit(packet, path), do: File.write!(path, packet) && Mix.shell().info("wrote #{path}")
end
