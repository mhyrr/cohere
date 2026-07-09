defmodule Cohere.Onboarding do
  @moduledoc """
  Owns the cohere block in the host's agent guidance file (`AGENTS.md`).

  Two zones (DEC-AGE-001 in `cohere/design/agent-surfaces.md`): a
  marker-bounded block of loop mechanics, machine-managed and regenerated
  on every `mix cohere.init` re-run; and a working-agreement section
  seeded below it on first write only — dev-owned, never touched again.
  Nothing outside the markers is ever modified, by construction.
  """

  alias Cohere.Project

  @begin_marker "<!-- cohere:begin -->"
  @end_marker "<!-- cohere:end -->"
  @default_target "AGENTS.md"
  @known_targets ["AGENTS.md", "CLAUDE.md"]

  @doc """
  Renders the machine-managed block, markers included. Regenerated whole
  on every sync — content between the markers is cohere's, not the dev's.
  """
  @spec block(Project.t()) :: String.t()
  def block(%Project{} = project) do
    """
    #{@begin_marker}
    ## Coherence layer (cohere)

    This project carries a coherence layer in `#{project.dir}/`: a derived
    map, intent cards, design docs, and a drift gate. The loop:

    - **Picking up work:** `mix cohere.packet <contexts>` (on a branch:
      `mix cohere.packet --diff`) — read it before exploring the repo.
    - **Non-trivial change:** `mix cohere.design <slug> --contexts <ctx>`
      (contexts inferred from the branch diff when omitted); design in
      the doc, against its Existing ground section.
    - **Anytime, and before any PR:** `mix cohere.check` — must exit 0;
      every finding prints the command that fixes it.
    - **Landing:** `mix cohere.complete <slug>` — verifies the design's
      promised surface exists, then flips it to accepted.
    - Never hand-edit `#{Project.map_path(project)}` (derived — run
      `mix cohere.map`) or the machine-managed frontmatter of cards and
      designs.
    - Judgment actions record who: pass `--by <name>` to
      `mix cohere.check --accept` and `mix cohere.complete` (defaults to
      git user.name).
    - Full rules: #{usage_rules_path()}.
    #{@end_marker}
    """
  end

  @agreement """
  ### Working agreement (cohere seeds this once — edit to how your team works)

  - Agents run the mechanical verbs freely: map, packet, check, and the
    design/gen.intent scaffolds.
  - Agents may `mix cohere.check --accept` drift their own in-flight
    design promised. Unexpected drift stops the work and gets surfaced
    to a human.
  - `mix cohere.complete` and card edits ride in PRs — human review is
    the approval gate.
  """

  @doc """
  Writes the block into `target` (default `#{@default_target}`),
  idempotently: file missing → created with block + working agreement;
  markers present → block replaced in place, everything else untouched;
  file present without markers → block + agreement appended.

  Returns `:created`, `:updated`, or `:unchanged`.
  """
  @spec sync(Project.t(), String.t()) :: :created | :updated | :unchanged
  def sync(%Project{} = project, target \\ @default_target) do
    content = block(project)

    cond do
      not File.exists?(target) ->
        File.write!(target, "# Agent guidance\n\n" <> content <> "\n" <> @agreement)
        :created

      String.contains?(File.read!(target), @begin_marker) ->
        existing = File.read!(target)
        updated = replace_block(existing, content, target)

        if updated == existing do
          :unchanged
        else
          File.write!(target, updated)
          :updated
        end

      true ->
        appended =
          String.trim_trailing(File.read!(target)) <>
            "\n\n" <> content <> "\n" <> @agreement

        File.write!(target, appended)
        :updated
    end
  end

  @doc """
  Whether any known guidance file (`AGENTS.md`, `CLAUDE.md`) carries the
  cohere block — the check's soft finding when none does. Both files
  count so `--into CLAUDE.md` shops don't get nagged about AGENTS.md.
  """
  @spec synced?(Project.t(), [String.t()]) :: boolean()
  def synced?(%Project{}, targets \\ @known_targets) do
    Enum.any?(targets, fn path ->
      File.exists?(path) and String.contains?(File.read!(path), @begin_marker)
    end)
  end

  defp replace_block(text, content, target) do
    [before, rest] = String.split(text, @begin_marker, parts: 2)

    case String.split(rest, @end_marker, parts: 2) do
      [_old, remainder] ->
        before <> String.trim_trailing(content) <> remainder

      [_no_end] ->
        raise ArgumentError,
              "#{target} has a `#{@begin_marker}` marker but no `#{@end_marker}` — " <>
                "restore the end marker (or delete the block), then re-run"
    end
  end

  defp usage_rules_path do
    if File.exists?("usage-rules.md"), do: "usage-rules.md", else: "deps/cohere/usage-rules.md"
  end
end
