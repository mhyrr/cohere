defmodule Cohere.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/mhyrr/cohere"

  def project do
    [
      app: :cohere,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Cohere",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:crypto]
    ]
  end

  # Zero runtime dependencies. Ecto and Phoenix appear here only so the test
  # suite can exercise real reflection against real schemas and routers —
  # consumers never inherit them through cohere. Everything else (Oban,
  # boundary, Ash, Tidewave) is probed for at derivation time and exercised
  # in tests via fixture doubles.
  defp deps do
    [
      {:ecto, "~> 3.10", only: [:dev, :test]},
      {:phoenix, "~> 1.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "A coherence layer for Elixir/Phoenix: a derived map of your system that " <>
      "cannot lie, thin authored intent cards, and a drift sentinel that keeps them honest."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "Cohere",
      extras: ["README.md", "CHANGELOG.md", "usage-rules.md"]
    ]
  end
end
