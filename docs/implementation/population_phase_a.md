# Population Phase A — Reusable Tier 2 Generation

Phase A introduces reusable generation definitions and a persistent regional roster without replacing the existing authored Tier 1 cast.

## Runtime model

- `PersonEntity` remains the single person runtime model.
- `PopulationService` creates people and registers them in `WorldState.people`.
- Generation uses only `WorldState.rng_people`.
- `WorldState.population_batches` records idempotency keys, so a repeated request returns the same generated residents rather than creating duplicates.
- Person location, template, occupation, generation key/source, and name provenance are persisted by `SaveCodec`. These fields are optional on decode, so existing version-1 saves remain readable; the save format version remains 1.
- Existing 17 authored people remain the Tier 1 anchors. The Uruk seeder adds four Tier 2 residents each at Uruk, Nippur, and Umma.

## Definitions

- `TraitDef`: `data/definitions/trait_def.gd`
- `OccupationDef`: `data/definitions/occupation_def.gd`
- `CharacterTemplate`: `data/definitions/character_template.gd`
- Definitions are indexed by `DefinitionRegistry` categories `traits`, `occupations`, and `character_templates`; the `Registry` autoload exposes typed lookup.

Occupation skill ranges are stored as `Vector2i(min, max)`. Templates identify culture, era eligibility, occupation, trait additions, skill bonuses, and selection weight. Shared Resources are read-only during generation.

## Names and historical provenance

The Era I table is `data/tables/era1_sumerian_names.csv`. Every entry is explicitly marked `constructed`, not an attested historical individual. The source/provenance note says the name is developer-constructed and requires philological review. This is deliberate: the initial generator proves the data pipeline, not a claim that every generated name is epigraphically attested. Before expanding the name table or treating it as historical reference data, review each entry against appropriate specialist sources.

## API

`PopulationService.generate_people(world, definitions, location_id, culture_id, era_id, count, generation_key)`

A non-empty generation key is mandatory. It is combined with location, culture, and era to form a stable batch identity. The caller must seed/register place records before generation.

## Tests

`tests/test_population_phase_a.gd` covers registry loading, deterministic same-seed roster generation, unique IDs, valid locations and occupations, trait/skill initialization, idempotency, and save/load of generated identity and RNG state.

Phase A does not implement succession, staffing/labor routing, aging, illness, death, household lifecycle, or persistent claimant promotion. Those remain separate phases.
