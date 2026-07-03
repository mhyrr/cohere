defmodule Mix.Tasks.Cohere.Packet do
  @shortdoc "Assembles a work packet for the contexts a task touches"

  @moduledoc """
  Prints a work packet — map slices, intent cards, related routes, and
  runtime-verification pointers — for the contexts a task touches.

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

    files = changed_files(opts[:base] || "main")

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

  # Changed files on this branch: everything that moved since the merge base
  # with `base` (committed or not), plus new untracked source. Plumbing only,
  # never porcelain — stable across git versions and safe to script.
  defp changed_files(base) do
    merge_base =
      case System.cmd("git", ["merge-base", "HEAD", base], stderr_to_stdout: true) do
        {out, 0} ->
          String.trim(out)

        {out, _} ->
          Mix.raise(
            "could not find a merge base with `#{base}` (git: #{String.trim(out)}). " <>
              "Pass --base <ref> with a branch that shares history."
          )
      end

    tracked = git_lines(["diff", "--name-only", merge_base])
    untracked = git_lines(["ls-files", "--others", "--exclude-standard"])

    Enum.uniq(tracked ++ untracked)
  end

  defp git_lines(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {out, 0} -> String.split(out, "\n", trim: true)
      {out, code} -> Mix.raise("git #{Enum.join(args, " ")} exited #{code}: #{String.trim(out)}")
    end
  end
end
