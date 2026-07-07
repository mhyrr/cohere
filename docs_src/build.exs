# Builds the docs site: mix run docs_src/build.exs
# CI proves freshness afterwards with: git diff --exit-code docs/
Cohere.Docs.build(base_url: "https://mhyrr.github.io/cohere")
IO.puts("docs/ built")
