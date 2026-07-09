defmodule Cohere.OnboardingTest do
  use ExUnit.Case, async: true

  alias Cohere.Onboarding

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    %{project: Cohere.Fixtures.project(dir: tmp), target: Path.join(tmp, "AGENTS.md")}
  end

  test "creates the file with block and working agreement", %{project: project, target: target} do
    assert Onboarding.sync(project, target) == :created

    content = File.read!(target)
    assert content =~ "<!-- cohere:begin -->"
    assert content =~ "<!-- cohere:end -->"
    assert content =~ "mix cohere.packet"
    assert content =~ "### Working agreement"
  end

  test "appends to an existing file without touching its content", %{
    project: project,
    target: target
  } do
    File.write!(target, "# My project\n\nHand-authored guidance.\n")

    assert Onboarding.sync(project, target) == :updated

    content = File.read!(target)
    assert String.starts_with?(content, "# My project")
    assert content =~ "Hand-authored guidance."
    assert content =~ "<!-- cohere:begin -->"
    assert content =~ "### Working agreement"
  end

  test "re-sync replaces only the block; edits outside it survive", %{
    project: project,
    target: target
  } do
    :created = Onboarding.sync(project, target)

    # Dev edits the agreement and adds content after the block.
    edited =
      File.read!(target)
      |> String.replace("edit to how your team works", "OUR RULES")
      |> Kernel.<>("\nCustom trailing section.\n")

    File.write!(target, edited)

    # Nothing changed in the block itself → unchanged, file untouched.
    assert Onboarding.sync(project, target) == :unchanged
    assert File.read!(target) == edited

    # Someone tampers inside the markers → re-sync repairs exactly that.
    File.write!(target, String.replace(edited, "mix cohere.packet", "mix hacked.packet"))
    assert Onboarding.sync(project, target) == :updated

    repaired = File.read!(target)
    assert repaired =~ "mix cohere.packet"
    assert repaired =~ "OUR RULES"
    assert repaired =~ "Custom trailing section."
    # the agreement is seeded once — never re-appended
    assert length(String.split(repaired, "### Working agreement")) == 2
  end

  test "begin marker without end marker raises rather than mangling", %{
    project: project,
    target: target
  } do
    File.write!(target, "prose\n<!-- cohere:begin -->\nno end in sight\n")

    assert_raise ArgumentError, ~r/no.*cohere:end/, fn ->
      Onboarding.sync(project, target)
    end
  end

  test "synced?/2 sees the block through any known target", %{
    project: project,
    target: target,
    tmp_dir: tmp
  } do
    claude = Path.join(tmp, "CLAUDE.md")

    refute Onboarding.synced?(project, [target, claude])

    :created = Onboarding.sync(project, claude)
    assert Onboarding.synced?(project, [target, claude])
  end
end
