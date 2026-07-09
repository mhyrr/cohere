import Config

# Cohere dogfoods its own gates. The docs site is a committed derived
# artifact; `mix cohere.check` fails while docs/ doesn't match a fresh
# render (cohere/design/derived-artifacts.md).
config :cohere,
  derived: [
    {"docs site", "docs", {Cohere.Docs, :gate_build}, "mix run docs_src/build.exs"}
  ]
