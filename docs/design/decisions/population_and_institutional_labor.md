# Population and Institutional Labor System

**Project:** Scribe of Eras  
**Status:** Accepted design direction  
**Initial implementation era:** Era I — Uruk  
**Scope:** Regional population, NPC generation, institutional staffing, labor availability, succession, and lifecycle

## 1. Design principle

Scribe of Eras simulates a living society, not a static collection of quest givers.

People age, become ill, change occupations, gain influence, form relationships, hold grudges, move between settlements, get dismissed, and die. Institutions continue operating when the player is absent.

The game does not need every inhabitant to receive bespoke authorship or expensive individual simulation.

**We author the rules that produce and maintain a population.**

## 2. Three-tier population model

### Tier 1 — Anchors

Hand-authored historical and narrative characters.

- Initial target: approximately 6–8.
- Authored CharacterTemplates.
- Specific identities, histories, relationships, traits, and agendas.
- Receive the richest simulation and narrative attention.

Examples include Shuruppak-ilu, Ur-Nanna, and Enlil-kisu.

### Tier 2 — Regional Notables

Procedurally generated, persistent people who operate regional society.

- Initial regional target: approximately 30–60.
- Officials, priests, merchants, household heads, skilled workers, and institutional staff.
- Receive persistent identities, skills, traits, relationships, memories, offices, and appropriate agendas.
- Can be promoted, dismissed, relocated, injured, or killed.
- Persist across visits and save/load cycles.

### Tier 3 — Claimants

Lightweight generated people who bring problems to the player's desk.

- Generated when needed by assignments, events, disputes, and institutional demands.
- Initially require an identity, name, and relevant claim or background.
- Become persistent when the player or simulation creates lasting consequences involving them.
- Retain identity, relationships, and history when promoted to persistent status.

A claimant who acquires a grudge must not be regenerated as a different person the next time their problem appears.

## 3. Data-driven generation

Population generation uses reusable definitions and data tables.

Core data concepts:

- `CharacterTemplate` — authored individuals and reusable character archetypes.
- `OccupationDef` — work roles, qualifications, and skill expectations.
- `OfficeDef` — institutional positions, requirements, authority, and responsibilities.
- `TraitDef` — personality and behavioral modifiers.
- Era- and culture-aware name tables.

Name tables must support historical and cultural constraints. Names must not be drawn indiscriminately from incompatible periods or cultures.

CSV is suitable for bulk naming data. Definitions remain custom Godot Resources where appropriate.

## 4. PopulationService

Implement a reusable `PopulationService` responsible for:

- Generating people from templates and role requirements.
- Assigning unique persistent IDs.
- Generating historically and culturally appropriate identities.
- Initializing skills from occupation and office requirements.
- Assigning suitable traits.
- Establishing initial relationships where required.
- Registering runtime entities in `WorldState`.
- Recording generation provenance and deterministic seed information.

Use the existing entity/component architecture. Do not introduce a competing person model or duplicate existing systems.

Definitions must never hold mutable runtime state.

## 5. Determinism

Population generation must use the existing independent RNG architecture.

- Population generation must not casually consume the general simulation RNG stream.
- The same master seed and generation inputs should produce reproducible population results.
- Adding a name to a data table should not unexpectedly alter unrelated economic or narrative outcomes.

Use a dedicated population RNG stream if the existing stream architecture supports it; otherwise extend that architecture deliberately rather than silently borrowing another system's stream.

## 6. Institutional staffing and succession

Offices are persistent institutional positions, not merely character attributes.

When an office becomes vacant:

1. Register the vacancy.
2. Identify eligible candidates.
3. Evaluate qualifications, skills, reputation, relationships, and suitability.
4. Appoint a replacement.
5. Transfer office responsibilities.
6. Apply appropriate consequences to unsuccessful candidates and institutional relationships.

Succession must be reusable across offices and eras.

A vacancy should create gameplay opportunities rather than break institutional simulation. Appointments may be influenced by patronage, kinship, political pressure, and competence.

## 7. Administrative labor market

Institutions must know which people can perform which forms of work.

Examples include grain levy assessments, travel passes, succession claims, and pension rolls.

Work availability depends on qualified personnel, their location, workload, office, and availability.

- Qualified local personnel should be considered before work is routed to the player.
- When qualified local personnel are unavailable, work may accumulate in an institutional backlog.
- The player must not receive geographically inaccessible local assignments merely because the institution needs work completed.
- Remote work must be explicitly supported by the assignment or document type, with appropriate costs, delays, and limitations.

Administrative labor shortages should be meaningful gameplay. They should affect backlogs, institutional risk, compensation, authority, and the player's value.

## 8. Population lifecycle

The population system should support:

- Aging and life stages.
- Health and illness.
- Death.
- Office succession.
- Household membership.
- Apprenticeship and qualification.
- Occupation changes.
- Promotion and dismissal.
- Movement between locations.
- Persistent relationships and memories.

Not every person requires equally expensive simulation. Tier 1 and important Tier 2 characters receive richer simulation. Less important population members may use simpler rules.

Population is persistent world state. Visiting a settlement must never regenerate its inhabitants indiscriminately.

## 9. Wider population representation

The regional target is approximately 40–80 individually represented people as an initial design target, not a hard limit.

The wider population may be represented through cohorts and groups:

- Labor gangs.
- Households and dependents.
- Field workers.
- Boat crews.
- Craft workshops.
- Institutional labor pools.

Represent enough individual people to produce meaningful social consequences without requiring individual AI for every inhabitant.

## 10. Implementation sequence

1. Audit existing person entities, components, offices, occupations, definitions, and RNG streams.
2. Define reusable role templates and historically constrained name tables.
3. Implement PopulationService and deterministic generation.
4. Populate Tier 2 across Uruk, Nippur, and Umma.
5. Implement institutional vacancies, appointments, and succession.
6. Connect qualified labor to assignment routing and institutional backlogs.
7. Implement lifecycle processing and claimant persistence.
8. Test population behavior over multiple years, including player absence and regional travel.

## 11. Architectural constraints

- Reuse `WorldState`, `WorldSimulator`, existing components, and established RNG streams.
- Do not create a second world simulation system.
- Do not replace existing LimboAI agendas with a competing NPC behavior architecture.
- Do not hardcode era-specific population rules into generic systems.
- Keep era-specific population content in data.
- Preserve save/load compatibility through versioned save migration.
- Do not generate a fresh settlement population on every visit.
- Do not make all generated characters equally expensive to simulate.
- Definitions are immutable at runtime; duplicate mutable Resources before changing them.

## 12. Acceptance criteria

The initial implementation is successful when:

- Uruk, Nippur, and Umma have persistent populations.
- Generated people have valid identities, skills, and appropriate roles.
- Institutions have qualified personnel.
- Work is routed according to actual staff availability and location.
- Vacant offices can be filled through succession.
- NPCs continue their responsibilities while the player travels.
- Claimants retain identity and consequences when they become persistent.
- Population survives save/load and remains deterministic.
- The world continues producing meaningful consequences over multiple years without the player's direct involvement.

**Core design goal:** The player should be able to leave town, return later, and discover that the people and institutions have continued living their lives. Some will have prospered. Some will have died. Some will remember exactly what the player did.
