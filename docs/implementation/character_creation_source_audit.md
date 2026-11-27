# Character Creation Source Audit

**Audit date:** 27 November 2026  
**Audited ref:** main at 89716dcd9f3ab338455335c98d550ac5063b61ce  
**Design authority:** Approved Scribe of Eras Character Creation Intake Sequence (27 November 2026)  
**Scope:** Existing character creation, person/world state, effect pipeline, save/load, first-workday handoff, and relevant tests. Source audit and implementation recommendation only; not mechanics approval.

## Executive summary

The approved intake sequence fits the existing architecture. No engine rewrite or parallel person model is needed. The repo already has a draft-first creation flow, an Era I JSON catalog, a resolver that builds biography/effects, a shared EventEffect executor, PersonEntity memory/skills/traits/relationships, and SaveCodec support for personal memory.

The current implementation is an earlier character-creation design and does not implement the approved narrative. This is a controlled replacement of catalog content and UI stage presentation, with a few additive persisted identity/world fields and focused compile-time/runtime application.

## Findings

### Draft state — reusable
Source: systems/character_creation_selections.gd

- Holds answers, typed name, and committed guard outside WorldState.
- Allows answer revision before commit and provides a deep-copy snapshot.
- Does not hold pronouns or a separate institutional designation.

Recommendation: retain the class; add draft-only pronouns and any explicit name spelling input. Derive designation from Origin data in the resolver/catalog.

### Resolver — reusable core, old validation policy
Source: systems/character_creation_resolver.gd

Existing responsibilities include catalog loading, answer availability/pruning, validation, biography compilation, effect compilation, and one-time commit through EventEffect/EffectExecutor.

Current conflicts:
- Requires constraints block answers and prune downstream choices.
- Validation rejects incompatible combinations.
- Approved friction rule says choices are independent and odd combinations are recorded/reacted to, never blocked.
- Biography does not compose designation, clerk reactions, or irregularity count.
- Commit does not apply pronouns/designation, Stage 7 trait, or irregularity classification.

Recommendation: preserve preview/compile/commit shape. Remove dependency gating from the approved catalog. Validate completeness and choice integrity only. Compile a structured creation result before mutation; keep preview pure.

### Catalog and UI — replace old content/schema carefully
Sources: data/character_creation/era_1_uruk.json, main.gd

Current catalog has six questions: origin (4 answers), responsibility (5), formative_experience (4), entry_into_scribal_work (4), first_instruction (4), professional_orientation (4). It contains trait/ambition placeholders and several requires constraints.

UI is hardcoded:
- Screens 1–6 index catalog questions directly.
- Screen 7 is name entry.
- Screen 8 is biography/confirmation.
- Navigation labels are fixed.
- First workday is not a distinct mentor-delivery scene in this flow.

Approved design has eight narrative stages, with two independent Formative memories, pronouns chosen before the scene, and Stage 7 combining typed name/designation with the revealing integrity scene.

Recommendation: use a data-driven stage presentation model. Stage 3 stores two separate answers (formative memory and vulnerability) but displays as one stage. Pronoun selection is pre-scene and not a ninth narrative stage. Keep review/confirmation as UI chrome, not narrative stage.

### PersonEntity — existing components cover most consequences
Source: components/person_entity.gd

Already present: skills, traits, vulnerabilities, flags, memory, relationships, resources. Memory is an Array of Dictionaries. display_name stores the typed name. name_gender is name-generation metadata, not pronouns.

Missing: pronouns (he/she/they), institutional designation as a distinct identity field, and an explicit persisted irregularity breakdown if later systems need it.

Recommendation: add only minimal identity fields. Do not overload name_gender, replace display_name, or create a parallel Identity entity. Keep typed name distinct from clerk-added designation.

### EventEffect / EffectExecutor — reuse existing vocabulary
Sources: data/definitions/event_effect.gd, systems/effect_executor.gd

Existing handlers include add_trait, remove_trait, change_opinion, set_relationship, gain_skill_xp, create_form, set_flag, clear_flag, modify_resource, resolve_form, add_memory, and repair_hazard.

This covers most Stage 1–6 consequences. Existing add_memory records memory ID, text, year, and involved IDs.

Recommendation: reuse existing effects. If creation memories need source stage, privacy/archival visibility, or fragment key, define that record shape while remaining compatible with PersonEntity.memory. Add a new effect type only if existing effects cannot express a required consequence.

### WorldState — irregularity and risk are not implemented
Source: systems/world_state.gd

WorldState has flags, people, history, calendar, and simulation state. No dedicated audit_risk or character-creation irregularity counter exists.

Recommendation: do not equate the clerk’s irregularity count with audit risk without a rule. Keep separate concepts:
- Irregularity count/breakdown: deterministic narrative classification of choices.
- Audit risk: gameplay-facing consequence value, only if approved.

Compile clerk dialogue bands from the count. Represent collision rules as data keyed by choice IDs/categories, not a hardcoded pairwise branch tree.

### Save/load — existing identity and memory serialization
Source: systems/save_codec.gd

- Save version is 1.
- Person identity, flags, traits, vulnerabilities, memory, relationships, skills, and resources are serialized.
- WorldState fields are explicitly serialized.
- Memory round-trip is already tested.
- New fields require updates to person/world encode and decode.

Recommendation: additive optional fields with safe defaults can preserve v1 compatibility if semantics remain backward-compatible; verify with an old-v1 fixture. If semantics change or defaults are unsafe, bump version and migrate.

### First workday / mentor line
Source: main.gd

After creation commit, current flow attaches the player and calls _schedule_next_case(). No dedicated first-workday mentor line matching Appendix A was found in this startup/confirmation path.

Recommendation: add a one-time Turn 1 / The First Workday beat after successful creation and before the ordinary first case/assignment. Resolve line from selected mentor. Do not advance time or create another work assignment unless separately designed. Persist a consumed marker so load/re-entry cannot replay it.

### Tests and CI — useful base, assertions need revision
Sources: tests/test_event_slice.gd, .github/workflows/godot-ci.yml

Existing tests cover draft isolation, preview nonmutation, old gating/pruning, biography compilation, commit, relationships, memory, one-time commit, and save/load memory.

The old tests explicitly assert dependency gating and pruning. Replace those assertions with tests proving combinations are retained and accepted. Existing CI runs the headless integration suite.

## Recommended implementation sequence

1. Author the approved eight-stage Era I catalog with stable IDs. Separate narrative fragments, choice metadata, skill affinity, and collision/comment rules. Keep proposals marked or omit until approved.
2. Extend draft state with pronouns and the second Formative answer; preserve draft-only behavior.
3. Preserve pure preview and one-time commit; compile structured result; remove requires gating; generate Biography and clerk count/comment.
4. Add pronoun/designation fields without repurposing name_gender; serialize and test.
5. Add exacting, pliable, severe, cautious TraitDefs and apply exactly one selected trait using existing trait mechanisms. Verify registry validity.
6. Define irregularity count separately from audit risk before adding WorldState values; persist approved runtime values.
7. Add one-time mentor line at Turn 1 before first ordinary case.
8. Test independent choices/no pruning, distinct Formative memories, four traits, identity persistence, collision matrix, preview nonmutation, exactly-once commit/mentor line, and old-save compatibility.

## Out of scope

- Designation correction cost/mechanism.
- Archival Reconstruction trigger/timing.
- Final philological/historical validation.
- Creditor/kinsman names and Martial institutions.
- New personality, identity-component, or simulation architecture.
- Gameplay audit-risk tuning before irregularity/risk distinction is approved.
