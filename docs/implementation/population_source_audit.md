# Population System Source Audit

**Repository baseline:** `main` at `dd8221a551b5452d0c67e8e1ba27d86dfa2a1a42`  
**Audit branch:** `feature/population-tier-two`  
**Audit date:** 2026-11-27  
**Purpose:** Establish the actual implementation baseline before adding Tier 2 population generation.

This audit is based on the checked-in GDScript and Resources, not on earlier planning summaries. It is an implementation inventory, not a claim that the full population architecture already exists.

## Executive finding

The project has a useful persistent person model and deterministic population RNG, but the current population is still assembled manually in `UrukSeeder`. There is no reusable population factory, no reusable occupation or office definition layer, and no general person lifecycle or succession system.

The current seeder creates **17 named people**: the player, seven named core NPCs, and nine additional named NPCs. That is a useful first cast, not a regional population model.

## Existing foundations

| Area | Verified implementation | Consequence |
|---|---|---|
| Person runtime | `components/person_entity.gd` defines `PersonEntity : RefCounted` | Reuse this entity; do not introduce a competing person class. |
| Skills | `SkillsComponent` stores levels and XP for literacy, arithmetic, law, rhetoric, intrigue, stewardship | Skill initialization can be data-driven without replacing the component. |
| Social state | PersonEntity already stores office, traits, vulnerabilities, flags, memory, directed relationships, and personal resources | Most Tier 2 identity state can be added compositionally. |
| World ownership | `WorldState.people` is a dictionary of `PersonEntity`; `allocate_person_id()` provides unique sequential IDs | PopulationService should register into this authoritative collection. |
| Deterministic RNG | WorldState has `rng_people`; `set_world_seed()` derives it independently from narrative and simulation streams | Use this stream for people generation; avoid consuming `rng_sim`. |
| Save persistence | SaveCodec serializes people, skills, relationships, memories, and the people RNG seed/state | New PersonEntity fields require matching encode/decode coverage and save-version consideration. |
| Definitions | DefinitionRegistry indexes Events, Eras, Epics, Assignments, Places, Routes, and Institutions | It currently has no CharacterTemplate, OccupationDef, OfficeDef, or TraitDef category. |
| Places | PlaceDefs are loaded and seeded into `WorldState.places` | Place definitions exist, but people do not have a general location field. |
| Institutions | InstitutionDef creates runtime dictionaries with place, members, interests, stockpiles, and ledger metadata | Institutions can host membership and staffing data; current member lists are authored IDs. |
| Social groups | WorldState has `social_groups`; UrukSeeder currently builds five groups inline | Group definitions and population cohort rules remain hardcoded. |
| AI | Ur-Nanna's behavior tree is driven through the existing LimboAI integration | Keep this agenda architecture; generalize ownership/eligibility rather than replacing it. |

## Current population construction

File: `systems/uruk_seeder.gd`

The seeder manually constructs:

- Player: Enlil-barni.
- Core NPCs: Shuruppak-ilu, Ur-Nanna, Utu-mansum, Enlil-kisu, Lu-Nanshe, Nin-kasi, Geme-Inana.
- Additional named NPCs: Ama-edin, Ur-gula, Lu-uru, Ab-kala, Nin-dada, Ur-amas, Enki-ili, Nin-azu, Geme-tur.

The `_person()` helper creates a PersonEntity, sets its ID/name/office/traits, and overwrites skill levels from a literal dictionary. Individual vulnerabilities are then assigned inline. Relationships are authored through a list of hardcoded `_link()` calls.

The seeder also hardcodes five social groups and their membership. Institutions and places are already definition-driven, but people, group membership, relationships, and starting skill profiles are not.

**Finding:** adding a second settlement's population by copying this pattern would multiply era-specific code and create a maintenance trap.

## Missing data definitions and state

No files currently exist under `data/characters/`, `data/tables/`, or `data/traits/`. The registry's default definition folders do not include these categories.

The following reusable definitions do not currently exist:

- `CharacterTemplate`
- `OccupationDef`
- `OfficeDef`
- `TraitDef`
- A household definition or other reusable cohort definition

PersonEntity currently has no general fields for:

- Current place/location.
- Age, birth period/year, or life stage.
- Health state or illness.
- Generation source/provenance.
- Household membership as a first-class relationship.
- Availability, workload, or apprenticeship/qualification status.

These are not all required for the first generator commit. The first pass should add only fields required to create and persist a valid Tier 2 person, then introduce lifecycle fields in a separate, tested step.

## Simulation coupling

File: `systems/world_simulator.gd`

The current `_simulate_people()` implementation directly retrieves Ur-Nanna, Enlil-kisu, and Shuruppak-ilu by fixed IDs. It applies a small number of player-relative opinion reactions to labor and barley thresholds. It is not a general population lifecycle or social simulation.

The period tick also invokes Ur-Nanna's LimboAI agenda by fixed ID and checks his `grain_clerk` office directly. The agenda itself should remain LimboAI-based; its eligibility and character lookup are future generalization points.

The economy and parts of institutional simulation also contain Era I / Eanna-specific assumptions. The current work should not claim that the entire world simulator is era-agnostic merely because population generation becomes data-driven.

## Assignment and labor-market coupling

File: `systems/assignment_pipeline.gd`

- Form employers are selected by a hardcoded form-type-to-person-ID switch in `_form_employer()`.
- Hazards use Ur-Nanna as employer.
- Pressure, project-review, and ledger work use Shuruppak-ilu as employer.
- Local filtering exists for forms, hazards, institution pressure, and institution ledgers through `_is_local_to_current_location()`.
- Unplaced or empty-location work is treated as compound-wide.
- The Epic project-review loop does not currently apply the same local-place filter.

**Finding:** qualified staff availability and institutional assignment routing are not yet implemented. The current local filtering is not a substitute for a labor market. The Epic project-review locality gap should be separately tested and resolved before claiming all opportunities respect geography.

## Save and determinism considerations

File: `systems/save_codec.gd`

- Current save format version is 1.
- Person fields are explicitly written in `_person_to_data()` and restored in `_person_from_data()`.
- The people RNG seed and state are already persisted.
- `decode_save()` currently rejects any version other than the exact current version; there is no migration chain.

**Implementation requirement:** when adding persistent person fields, update both directions of the codec and add round-trip tests. Before adding a field that old saves need to interpret, decide whether to introduce a versioned migration path. Do not silently break existing saves.

## Existing tests to extend

- `tests/test_event_slice.gd` — existing person identity, skills, save round-trip, and RNG-state coverage.
- `tests/test_grain_clerk_agenda.gd` — Ur-Nanna's LimboAI behavior and world tick.
- `tests/test_route_network.gd` and `tests/test_travel_circuit.gd` — regional place graph and travel simulation.
- `tests/test_dev_command_router.gd` — developer tooling.

There is no dedicated population, generation, succession, or demographic lifecycle test suite yet.

## Recommended implementation sequence

### Phase A — Reusable Tier 2 generation

1. Add data definitions for reusable occupations and character-generation templates, with registry lookup and validation.
2. Add historically constrained name data for Era I, with explicit culture/era eligibility rather than an undifferentiated name bucket.
3. Implement `PopulationService` to generate PersonEntity instances using `rng_people`, `WorldState.allocate_person_id()`, existing SkillsComponent, and existing trait/relationship storage.
4. Replace the manually duplicated Tier 2 roster construction in UrukSeeder with authored Tier 1 anchors plus data-driven Tier 2 role requests.
5. Keep the existing named cast stable; generated people must not collide with authored IDs.
6. Add deterministic generation, ID uniqueness, role qualification, and save/load round-trip tests.

### Phase B — Institutional staffing and labor market

1. Define office requirements and occupation qualifications.
2. Represent staff assignments and vacancies in authoritative runtime institution/world state.
3. Resolve qualified local staff before routing work to the player.
4. Preserve genuine backlogs when nobody qualified is available.
5. Add succession and candidate evaluation as a reusable service.
6. Correct and test locality for every assignment source, including Epic project reviews.

### Phase C — Lifecycle and claimant persistence

1. Add birth/age/life-stage and health state with a clear calendar convention.
2. Add illness, death, retirement, movement, and office-vacancy events.
3. Add household membership and apprenticeship/qualification progression.
4. Promote claimants to persistent people when lasting consequences are created.
5. Ensure all lifecycle state survives save/load and remains deterministic.

## Guardrails

- Reuse PersonEntity, SkillsComponent, WorldState, DefinitionRegistry, SaveCodec, WorldSimulator, and LimboAI.
- Do not add a second person model or a second world simulator.
- Do not make every Tier 3 claimant a full AI agent.
- Do not regenerate settlement populations on visit.
- Do not put runtime state on shared definition Resources.
- Do not let population generation consume simulation or narrative RNG streams.
- Keep generic systems free of hardcoded era numbers and specific historical NPC IDs where practical; preserve intentional authored anchor behavior through explicit data/configuration.
- Do not claim the population system is complete merely because a roster count increases.

## Acceptance target for the first implementation phase

A fixed world seed must produce a stable Tier 2 roster across Uruk, Nippur, and Umma; each generated person must have a unique persistent ID, culturally eligible name, valid occupation/office role, initialized skills, and a registered location. Repeating generation must not duplicate people. Save/load must preserve the generated roster and people RNG state.

This is a first milestone, not the full population simulation. Succession, aging, illness, death, and labor-market routing remain explicit follow-up phases.
