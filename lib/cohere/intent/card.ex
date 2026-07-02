defmodule Cohere.Intent.Card do
  @moduledoc """
  One authored intent card: the thin layer of truth that cannot be derived.

  A card belongs to one context and holds only what reflection can't see:
  purpose, invariants, decisions with their rejected alternatives, non-goals,
  and open questions. Everything else belongs in the derived map.

  The frontmatter binds the card to a **surface**: the context's public
  function list and its hash at the time the card was last reviewed. When
  the real surface moves, the card is *drifted* — mechanically detectable,
  never silently stale.
  """

  defstruct path: nil,
            context: nil,
            reviewed: nil,
            surface: nil,
            functions: [],
            body: "",
            sections: %{}

  @type t :: %__MODULE__{
          path: String.t() | nil,
          context: module() | nil,
          reviewed: String.t() | nil,
          surface: String.t() | nil,
          functions: [{atom(), non_neg_integer()}],
          body: String.t(),
          sections: %{String.t() => String.t()}
        }

  @sections [
    "Purpose",
    "Invariants",
    "Decisions",
    "Non-goals",
    "Open questions",
    "Accepted drift"
  ]

  @doc "The canonical section headings, in order."
  def sections, do: @sections
end
