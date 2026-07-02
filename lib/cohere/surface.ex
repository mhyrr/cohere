defmodule Cohere.Surface do
  @moduledoc """
  The public function surface of a module, and a stable hash over it.

  A context's surface is its ontology-relevant API: the governed verbs the
  rest of the system (and any agent) is supposed to call. Intent cards bind
  to a surface hash; when the surface moves, the card is drifted until a
  human or agent re-reviews it.
  """

  @generated ~w(child_spec behaviour_info module_info)a

  # OTP machinery, not authored API. Only filtered when the module actually
  # declares the corresponding behaviour — a plain context that happens to
  # define init/1 keeps it.
  @otp_callbacks %{
    GenServer => [
      init: 1,
      handle_call: 3,
      handle_cast: 2,
      handle_info: 2,
      handle_continue: 2,
      terminate: 2,
      code_change: 3,
      format_status: 1,
      format_status: 2
    ],
    Supervisor => [init: 1]
  }

  @doc """
  Sorted list of `{function, arity}` for the module's public surface.

  Filters compiler/framework-generated functions (`__*__`, `child_spec/1`)
  and — for modules declaring GenServer/Supervisor behaviours — the OTP
  callbacks, so the surface reflects authored API, not machinery.
  """
  @spec functions(module()) :: [{atom(), non_neg_integer()}]
  def functions(module) do
    if Code.ensure_loaded?(module) do
      callbacks = otp_callbacks(module)

      module.__info__(:functions)
      |> Enum.reject(fn {name, arity} -> generated?(name) or {name, arity} in callbacks end)
      |> Enum.sort()
    else
      []
    end
  end

  defp otp_callbacks(module) do
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    Enum.flat_map(behaviours, &Map.get(@otp_callbacks, &1, []))
  rescue
    _ -> []
  end

  @doc ~S"""
  Renders a surface as a stable, single-line string: `"create/2 list/1"`.
  """
  @spec to_line([{atom(), non_neg_integer()}]) :: String.t()
  def to_line(functions) do
    Enum.map_join(functions, " ", fn {name, arity} -> "#{name}/#{arity}" end)
  end

  @doc "Parses a surface line back into `{function, arity}` tuples."
  @spec from_line(String.t()) :: [{atom(), non_neg_integer()}]
  def from_line(line) do
    line
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(fn entry ->
      case String.split(entry, "/") do
        [name, arity] -> [{String.to_atom(name), String.to_integer(arity)}]
        _ -> []
      end
    end)
    |> Enum.sort()
  end

  @doc "12-hex-char hash of a surface, stable across runs and machines."
  @spec hash([{atom(), non_neg_integer()}]) :: String.t()
  def hash(functions) do
    functions
    |> to_line()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp generated?(name) when name in @generated, do: true

  defp generated?(name) do
    text = Atom.to_string(name)
    String.starts_with?(text, "__") or String.starts_with?(text, "-")
  end
end
