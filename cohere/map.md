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

### Derive — passive
**Support:** Modules, Group, Routes, Route, Schemas, Schema, Workers, Worker

### Cohere.Drift — service `[surface:33bec9f41f56]`

The drift sentinel: mechanically detects when the project has moved out from under its coherence artifacts.

**API** (2): check/1 format/1
**Support:** Report

### Cohere.Intent — service `[surface:b68cc2992204]`

Loads, parses, generates, and updates intent cards.

**API** (7): accept_drift/3 filename/1 load_all/1 parse/1 parse/2 refs/2 skeleton/2
**Support:** Card

### Cohere.Map — service `[surface:eddee810a03a]`

The derived map: the actual shape of the system, assembled from reflection over the compiled application.

**API** (3): build/1 fetch_group/2 render/1
**Support:** Renderer

### Cohere.Packet — service `[surface:ddbe6f209766]`

Assembles a work packet: context delivered, not discovered.

**API** (4): build/2 build_for_files/2 contexts_for_files/3 group_index/1

### Cohere.Project — service `[surface:99bb8427aebc]`

Discovers the host project: its OTP app, module inventory, namespaces, and which coherence-relevant capabilities are present.

**API** (6): has?/2 intent_dir/1 load/0 load/1 map_path/1 source_index/1

### Cohere.Surface — service `[surface:8ed33ba5b8aa]`

The public function surface of a module, and a stable hash over it.

**API** (4): from_line/1 functions/1 hash/1 to_line/1


## Unclaimed Modules

- Cohere (namespace root)
- Mix.Tasks.Cohere (outside app namespaces)
- Mix.Tasks.Cohere.Drift (outside app namespaces)
- Mix.Tasks.Cohere.Gen.Intent (outside app namespaces)
- Mix.Tasks.Cohere.Init (outside app namespaces)
- Mix.Tasks.Cohere.Map (outside app namespaces)
- Mix.Tasks.Cohere.Packet (outside app namespaces)
