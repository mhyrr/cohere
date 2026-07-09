# Builds the docs site: mix run docs_src/build.exs
# The same render is registered with the freshness gate (config :cohere,
# derived:), so `mix cohere.check` fails while docs/ is stale.
Cohere.Docs.gate_build("docs")
IO.puts("docs/ built")
