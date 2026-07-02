defmodule Cohere.Derive.Schemas do
  @moduledoc """
  Derives object shape from Ecto schemas via `__schema__/1` reflection.

  This is the semantic half of the ontology: objects (schemas), properties
  (fields with real types, enum values included), and links (associations,
  recorded with name, cardinality, target, and owner key — because assoc
  name ≠ target module ≠ foreign key in real codebases).

  Works on compiled modules only; never parses source. Degrades to an empty
  list when Ecto is absent.
  """

  defmodule Schema do
    @moduledoc false
    defstruct module: nil,
              source: nil,
              embedded?: false,
              primary_key: [],
              fields: [],
              assocs: [],
              embeds: []
  end

  @doc "Derives `%Schema{}` for every schema module in the given list."
  def derive(schema_modules) do
    schema_modules
    |> Enum.map(&describe/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&to_string(&1.module))
  end

  @doc "Describes one schema module, or nil if it isn't one."
  def describe(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1) do
      source = module.__schema__(:source)
      pk = module.__schema__(:primary_key)

      %Schema{
        module: module,
        source: source,
        embedded?: is_nil(source),
        primary_key: pk,
        fields: fields(module, pk),
        assocs: assocs(module),
        embeds: embeds(module)
      }
    end
  rescue
    _ -> nil
  end

  defp fields(module, pk) do
    embeds = module.__schema__(:embeds)

    for field <- module.__schema__(:fields), field not in embeds do
      %{name: field, type: type_label(module, field), primary_key?: field in pk}
    end
  end

  defp assocs(module) do
    for name <- module.__schema__(:associations) do
      describe_assoc(module.__schema__(:association, name))
    end
  end

  defp describe_assoc(%{__struct__: Ecto.Association.BelongsTo} = assoc) do
    %{kind: :belongs_to, name: assoc.field, related: assoc.related, key: assoc.owner_key}
  end

  defp describe_assoc(%{__struct__: Ecto.Association.Has, cardinality: card} = assoc) do
    kind = if card == :one, do: :has_one, else: :has_many
    %{kind: kind, name: assoc.field, related: assoc.related, key: assoc.related_key}
  end

  defp describe_assoc(%{__struct__: Ecto.Association.ManyToMany} = assoc) do
    join =
      case assoc.join_through do
        join when is_binary(join) -> join
        join when is_atom(join) -> inspect(join)
        _ -> nil
      end

    %{kind: :many_to_many, name: assoc.field, related: assoc.related, key: nil, through: join}
  end

  defp describe_assoc(%{__struct__: Ecto.Association.HasThrough} = assoc) do
    %{kind: :has_through, name: assoc.field, related: nil, key: nil, through: assoc.through}
  end

  defp describe_assoc(assoc) do
    %{kind: :assoc, name: Map.get(assoc, :field), related: Map.get(assoc, :related), key: nil}
  end

  defp embeds(module) do
    for name <- module.__schema__(:embeds) do
      embed = module.__schema__(:embed, name)
      %{name: name, cardinality: embed.cardinality, related: embed.related}
    end
  end

  @doc """
  Human-stable label for a field type. Enums render their values — those
  values are the vocabulary of the domain and belong in the map.
  """
  def type_label(module, field) do
    module.__schema__(:type, field) |> label()
  rescue
    _ -> "unknown"
  end

  defp label(type) when is_atom(type), do: format_atom_type(type)
  defp label({:array, inner}), do: "[#{label(inner)}]"
  defp label({:map, inner}), do: "map(#{label(inner)})"

  # Ecto >= 3.12 parameterized shape
  defp label({:parameterized, {Ecto.Enum, params}}), do: enum_label(params)
  # Ecto < 3.12 parameterized shape
  defp label({:parameterized, Ecto.Enum, params}), do: enum_label(params)
  defp label({:parameterized, {mod, _params}}), do: format_atom_type(mod)
  defp label({:parameterized, mod, _params}), do: format_atom_type(mod)
  defp label(other), do: inspect(other)

  defp enum_label(%{mappings: mappings}) do
    values = mappings |> Keyword.keys() |> Enum.map_join("|", &to_string/1)
    "enum(#{values})"
  end

  defp enum_label(_), do: "enum"

  defp format_atom_type(type) do
    case to_string(type) do
      "Elixir." <> name -> name
      name -> name
    end
  end
end
