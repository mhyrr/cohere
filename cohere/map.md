# System Map — cohere

> Derived from the compiled application by `mix cohere.map`. Do not edit;
> regenerate instead. If this file disagrees with the code, the file is
> stale — never the other way around.

## Capabilities

- `phoenix` 1.8.8 — routes derived from compiled routers
- `ecto` 3.14.0 — objects and links derived from schema reflection
- `boundary` absent — write-path governance is convention only, not compiler-checked
- `tidewave` absent — no runtime introspection; agents verify via tests only

## Contexts

### Cohere.Check — service `[surface:33bec9f41f56]`

The check verb: every finding cohere can make, in one iterative command — the same command locally and in CI. Fix what it lists, run it again.

**API** (2): check/1 format/1
**Support:** Report

### Derive — passive
**Support:** Modules, Group, Routes, Route, Schemas, Schema, Workers, Worker

### Cohere.Design — service `[surface:c3bf3d14798e]`

Design docs: the authored artifact of the feature loop.

**API** (14): accept/2 accept/3 anchored_to/3 filename/1 ground/2 issues/3 load_all/1 open_questions/1 parse/1 parse/2 promised_refs/1 skeleton/2 skeleton/3 unmet_promises/1
**Support:** Doc

### Cohere.Docs — service `[surface:80923c3ecdeb]`

Renders the cohere docs site: authored markdown in `docs_src/` becomes static HTML in `docs/`, alongside pages derived from the compiled tasks and the repo's own coherence artifac…

**API** (4): build/0 build/1 gate_build/1 render_markdown/1

### Cohere.Drift — service `[surface:4f4931c09525]`

The drift sentinel: mechanically detects when the project has moved out from under its coherence artifacts.

**API** (3): check/1 derived_status/2 format/1
**Support:** Report

### Cohere.Intent — service `[surface:b57e1a565df7]`

Loads, parses, generates, and updates intent cards.

**API** (8): accept_drift/3 accept_drift/4 filename/1 load_all/1 parse/1 parse/2 refs/2 skeleton/2
**Support:** Card

### Cohere.Map — service `[surface:eddee810a03a]`

The derived map: the actual shape of the system, assembled from reflection over the compiled application.

**API** (3): build/1 fetch_group/2 render/1
**Support:** Renderer

### Cohere.Markdown — service `[surface:67dd9bda9d60]`

Frontmatter and section mechanics shared by every authored artifact — intent cards and design docs.

**API** (6): append_to_section/3 code_refs/1 ref_exists?/1 replace_frontmatter/3 sections/1 split_frontmatter/1

### Cohere.Onboarding — service `[surface:a950d1fd2f87]`

Owns the cohere block in the host's agent guidance file (`AGENTS.md`).

**API** (5): block/1 sync/1 sync/2 synced?/1 synced?/2

### Cohere.Packet — service `[surface:ce98880a2916]`

Assembles a work packet: context delivered, not discovered.

**API** (5): build/2 build_for_files/2 contexts_for_files/3 group_index/1 guidance_paths/2

### Cohere.Project — service `[surface:50329f4db6fe]`

Discovers the host project: its OTP app, module inventory, namespaces, and which coherence-relevant capabilities are present.

**API** (8): changed_files/1 design_dir/1 has?/2 intent_dir/1 load/0 load/1 map_path/1 source_index/1

### Cohere.Surface — service `[surface:8ed33ba5b8aa]`

The public function surface of a module, and a stable hash over it.

**API** (4): from_line/1 functions/1 hash/1 to_line/1


## Unclaimed Modules

- Cohere (namespace root)
- Mix.Tasks.Cohere (outside app namespaces)
- Mix.Tasks.Cohere.Check (outside app namespaces)
- Mix.Tasks.Cohere.Complete (outside app namespaces)
- Mix.Tasks.Cohere.Design (outside app namespaces)
- Mix.Tasks.Cohere.Gen.Intent (outside app namespaces)
- Mix.Tasks.Cohere.Init (outside app namespaces)
- Mix.Tasks.Cohere.Map (outside app namespaces)
- Mix.Tasks.Cohere.Packet (outside app namespaces)
