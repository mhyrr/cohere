# The map

The map is the derived half of the coherence layer: contexts and their
public API, Ecto schemas with real types and associations, Phoenix
routes with LiveView unwrapped, Oban workers with queue and cron
wiring. It regenerates on demand, which is the whole trick:
**a document produced by reflection cannot drift from the code it
reflects.**

## Derivation is functional, not textual

Classification reads the *compiled* application, never source text:
`__schema__/1` makes a schema, `__adapter__/0` makes a repo,
`__routes__/0` makes a router, the `Oban.Worker` behaviour makes a
worker. Names lie; a module named `Deals` could be anything. Compiled
modules don't.

That discipline was earned against a real ~185-module Phoenix app: an
encrypted Cloak type living in the schema layer (caught as an Ecto
type, not a schema), contexts with zero CRUD-named functions,
`belongs_to` associations with custom foreign keys. The map reports
what the code *is*, not what its names suggest.

## What it looks like

```markdown
### Revrec.Deals — domain [surface:df8be63a83b8]

**API** (32): approve_deal/1 create_deal/1 extract_deal_data/1 ...
**Schemas:** Deal, DealParty, DealPartyFeeComponent

### Revrec.Deals.Deal → deals
- fields: ..., side:enum(listing|buyer|both|lease|referral),
  status:enum(draft|needs_review|approved|posting|posted|reversed), ...
- belongs_to reviewed_by → Revrec.Users.User via reviewed_by_user_id
```

Entries read like the language of the business because they *are* the
business, reflected out of the compiled code. Enum vocabularies, custom
foreign keys, queue wiring: the facts agents otherwise rediscover by
grepping, in one git-tracked file whose PR diff is the ontology change.

## The rules it lives by

- **100% derived.** No hand-authored content survives regeneration, by
  design. Anything a human needs to say belongs in an
  [intent card](intent-cards.html), not the map.
- **Deterministic.** Stable ordering, no timestamps. Regenerating
  without a code change is a no-op diff, so staleness is simple byte
  inequality and the CI gate can prove freshness.
- **Compiled modules and app config only.** Never source text, never a
  running server, never the database. The map derives anywhere
  `mix compile` runs, including CI.

## Surface hashes

Every context heading carries a hash of its public function surface;
that is the `[surface:df8be63a83b8]` above. Those hashes are what
[intent cards](intent-cards.html) bind to: when a context's surface
moves, every card bound to the old surface is flagged until a human
re-reviews it. The map states what is. The hash turns that statement
into something other documents can be held to.
