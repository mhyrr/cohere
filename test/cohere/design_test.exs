defmodule Cohere.DesignTest do
  use ExUnit.Case, async: true

  alias Cohere.{Design, Intent, Map, Project}

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    project = Cohere.Fixtures.project(dir: tmp)
    map = Map.build(project)
    %{project: project, map: map, accounts: Enum.find(map.groups, &(&1.name == "Accounts"))}
  end

  defp write_design!(project, slug, contents) do
    dir = Project.design_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, Design.filename(slug)), contents)
  end

  defp write_card!(project, name, contents) do
    dir = Project.intent_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, name), contents)
  end

  test "skeleton parses back as a draft bound to its anchors" do
    {:ok, doc} =
      "deal-reversals"
      |> Design.skeleton(~D[2026-07-03], contexts: ["Accounts", "Billing"])
      |> Design.parse()

    assert doc.slug == "deal-reversals"
    assert doc.status == :draft
    assert doc.date == "2026-07-03"
    assert doc.contexts == ["Accounts", "Billing"]
    assert doc.supersedes == nil
    assert doc.sections["Problem"]
    assert doc.sections["Promised surface"]
    assert doc.sections["Status log"] == ""
  end

  test "rejects unknown status and missing slug" do
    assert {:error, {:bad_status, "shipped"}} =
             Design.parse("---\ndesign: x\nstatus: shipped\n---\n\nbody")

    assert {:error, :missing_slug} = Design.parse("---\nstatus: draft\n---\n\nbody")
  end

  test "ground carries the API and card constraints for known contexts", %{project: project} do
    write_card!(project, "accounts.md", """
    ---
    context: Fixture.Accounts
    reviewed: 2026-07-02
    surface: 000000000000
    functions:
    ---

    ## Invariants

    - INV-ACC-001: every user has an email.

    ## Decisions

    <!-- only a comment, no real content -->
    """)

    ground = Design.ground(project, ["Accounts", "Ghost"])

    assert ground =~ "### Fixture.Accounts — domain"
    assert ground =~ "**API**"
    assert ground =~ "create_user/1"
    assert ground =~ "INV-ACC-001"
    # comment-only sections are not constraints
    refute ground =~ "only a comment"
    # unknown anchors render as proposed, not as errors
    assert ground =~ "### Ghost — proposed"
  end

  test "promised refs are parsed unfiltered; unmet promises resolve against compiled code" do
    text = """
    ---
    design: x
    status: draft
    ---

    ## Shape

    Mentions `Fixture.Accounts.create_user/1` in prose.

    ## Promised surface

    - `Mix.Tasks.Cohere.Design` — the start verb
    - `Fixture.Accounts.create_user/1` — already exists
    - `Fixture.Accounts.reverse_user/1` — not yet
    """

    {:ok, doc} = Design.parse(text)

    assert {"Mix.Tasks.Cohere.Design", nil, nil} in Design.promised_refs(doc)
    assert length(Design.promised_refs(doc)) == 3

    assert Design.unmet_promises(doc) == [{"Fixture.Accounts", "reverse_user", 1}]
  end

  test "refs inside skeleton comments are examples, not promises" do
    # A fresh skeleton's Promised surface holds only a commented example;
    # it must not block completion (caught dogfooding the negative path).
    {:ok, doc} = "fresh" |> Design.skeleton(~D[2026-07-03]) |> Design.parse()

    assert Design.promised_refs(doc) == []
    assert Design.unmet_promises(doc) == []
  end

  test "accept flips status, keeps the design date, logs the acceptance" do
    text = Design.skeleton("feature-x", ~D[2026-07-01], contexts: ["Accounts"])
    {:ok, doc} = text |> Design.accept(~D[2026-07-03]) |> Design.parse()

    assert doc.status == :accepted
    assert doc.date == "2026-07-01"
    assert doc.contexts == ["Accounts"]
    assert doc.sections["Status log"] =~ "2026-07-03: accepted"
  end

  test "issues: missing anchors and dead body refs warn; promised refs are exempt", %{
    project: project,
    map: map
  } do
    text = """
    ---
    design: x
    status: draft
    contexts: Accounts, Ghost
    ---

    ## Shape

    Builds on `Fixture.Accounts.create_user/1` and `Fixture.Accounts.no_such/9`.
    Will call `Fixture.Accounts.not_built_yet/1` from the new flow.
    Ignores `Enum.map/2` (outside the namespace).

    ## Promised surface

    - `Fixture.Accounts.not_built_yet/1`
    """

    {:ok, doc} = Design.parse(text)
    issues = Design.issues(doc, map, project)

    assert {:anchor_missing, "Ghost"} in issues
    assert {:broken_ref, "Fixture.Accounts.no_such/9"} in issues
    refute Enum.any?(issues, &match?({:broken_ref, "Fixture.Accounts.not_built_yet" <> _}, &1))
    refute Enum.any?(issues, &match?({:anchor_missing, "Accounts"}, &1))
  end

  test "promised-ref exemption is draft-only: accepted docs flag vanished refs", %{
    project: project,
    map: map
  } do
    text = """
    ---
    design: y
    status: accepted
    contexts: Accounts
    ---

    ## Shape

    Will call `Fixture.Accounts.not_built_yet/1` from the new flow.

    ## Promised surface

    - `Fixture.Accounts.not_built_yet/1`
    """

    {:ok, doc} = Design.parse(text)
    issues = Design.issues(doc, map, project)

    assert {:broken_ref, "Fixture.Accounts.not_built_yet/1"} in issues
  end

  test "load_all reads the design directory", %{project: project} do
    write_design!(project, "one", Design.skeleton("one", ~D[2026-07-03]))
    write_design!(project, "two", Design.skeleton("two", ~D[2026-07-03]))

    assert [%{slug: "one"}, %{slug: "two"}] = Design.load_all(project)
  end

  test "open questions: skeleton prompts don't count, real ones do" do
    {:ok, bare} = "bare" |> Design.skeleton(~D[2026-07-03]) |> Design.parse()
    assert Design.open_questions(bare) == nil

    {:ok, doc} =
      Design.parse("""
      ---
      design: x
      status: draft
      ---

      ## Open questions

      - Should start infer contexts from the branch diff?
      """)

    assert Design.open_questions(doc) =~ "infer contexts"
  end

  test "the empty-contexts skeleton still parses and prompts for anchors" do
    {:ok, doc} = "bare" |> Design.skeleton(~D[2026-07-03]) |> Design.parse()

    assert doc.contexts == []
    assert doc.sections["Existing ground"] =~ "No contexts anchored yet"
  end

  test "intent card refs still parse through the shared markdown mechanics" do
    # Guard the Intent refactor onto Cohere.Markdown: behavior unchanged.
    {:ok, card} =
      Intent.parse("""
      ---
      context: Fixture.Accounts
      ---

      See `Fixture.Accounts.create_user/1`, ignore `String.trim/1`.
      """)

    assert Intent.refs(card, Fixture) == [{"Fixture.Accounts", "create_user", 1}]
  end
end
