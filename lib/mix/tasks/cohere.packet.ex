defmodule Mix.Tasks.Cohere.Packet do
  @shortdoc "Assembles a work packet for the contexts a task touches"

  @moduledoc """
  Prints a work packet — map slices, intent cards, related routes, and
  runtime-verification pointers — for the named contexts.

      $ mix cohere.packet deals billing
      $ mix cohere.packet deals --out packet.md

  Feed the packet to whatever does the work: paste it into a session, wire
  it into a dispatch prompt, or hand it to a teammate. Context delivered,
  not discovered.
  """

  use Mix.Task

  alias Cohere.{Packet, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, names} = OptionParser.parse!(args, strict: [out: :string])

    if names == [] do
      Mix.raise("usage: mix cohere.packet <context...> [--out FILE]")
    end

    project = Project.load()

    case Packet.build(project, names) do
      {:ok, packet} ->
        case opts[:out] do
          nil -> Mix.shell().info(packet)
          path -> File.write!(path, packet) && Mix.shell().info("wrote #{path}")
        end

      {:error, {:unknown_contexts, unknown}} ->
        Mix.raise("unknown context(s): #{Enum.join(unknown, ", ")}")
    end
  end
end
