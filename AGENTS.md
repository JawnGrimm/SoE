# Repository Instructions for Coding Agents

Before changing gameplay architecture or implementing a major system, read the relevant accepted design decisions in `docs/design/decisions/`.

In particular, **`docs/design/decisions/population_and_institutional_labor.md` is canonical for population, NPC generation, institutional staffing, succession, administrative labor availability, and population lifecycle.** Consult it before changing person entities/components, seeding, offices, assignment routing, or NPC lifecycle behavior.

Accepted decision documents are architectural constraints, not optional suggestions. If implementation reality requires a change, explain the conflict and propose an explicit revision before silently diverging.

General project rules:

- Godot 4.7.x and GDScript.
- Prefer composition over inheritance.
- Definitions are custom Resources and must not hold mutable runtime state.
- Keep logic in systems and values in data.
- Reuse the authoritative `WorldState`, `WorldSimulator`, existing components, registries, and LimboAI integration; do not create competing simulation systems.
- Keep era-specific content in data rather than hardcoding era numbers or era-specific branches into generic systems.
- Preserve deterministic RNG stream boundaries and versioned save compatibility.
- Add tests for behavior and regression boundaries; do not claim visual verification from headless tests.
- Read `ACCESSIBILITY.md` before UI work and verify contrast, keyboard focus, scaling, and reduced-motion behavior against it.
- Keep presentation/UI orchestration in `ui/`; simulation, assignment generation/resolution, and world mutation remain in `systems/`. UI must not bypass pipeline or SaveManager APIs.
- Keep modular UI components presentation-only where possible; do not serialize transient UI state or change save schema for UI redesigns.


## Era I Slice A gameplay guardrails

- The Great Canal Cut begins dormant. It must not advance, erode, or request stage reviews until activated by its authored career milestone or an explicit summons. Keep launch thresholds centralized and test both dormant and launched states.
- A world assignment permits at most two investigative actions. The third action must fail closed; the desk disables remaining inquiry choices and prompts for disposition. Do not expand the assignment UI layout to implement this rule.
- Investigation must reveal distinct evidence: tablet origin/claim, numeric account reconciliation, physical site/bin state, and the responsible official's situated stance. Do not expose raw simulation metric keys or generic ledger boilerplate as player-facing copy.
- Consequential Epic verdicts must preserve their authored, choice-specific result text through resolution; never overwrite it with a generic receipt after the verdict match.
- Assignment verdicts must change persistent world state when the matter warrants it: institutional stock/pressure, concealed records, relationships, audit exposure, and the career chronicle. Silver pressure must create debt/reprimand rather than a travel or work soft-lock.
- Uruk work-record sub-places resolve to their responsible institution through explicit ownership first, then parent-place routing. Do not leave assignment institution_id or employer_id blank when a valid local institution/person exists.
- Slice A does not add settlements, redesign the desk, or implement Phase B succession. Keep Era I work focused on the apprentice's local/regional career and the first meaningful judgment loop.

## UI and accessibility guardrails

- Read `ACCESSIBILITY.md` before changing desk, HUD, menus, overlays, or other player-facing controls.
- Keep reusable presentation components under `ui/`; keep assignment generation/resolution, world mutation, and save behavior in `systems/`.
- UI controls must call the existing pipeline and SaveManager APIs. Do not directly mutate simulation state from presentation scripts.
- Keep transient UI state (open panels, focus, queue filters, animation state) out of save data.
- Provide keyboard equivalents for clickable desk props, visible focus, meaningful labels/tooltips, and Escape handling for overlays. Cuneiform glyphs are decorative/atmospheric and must always be paired with plain-language labels.
- Hide evidence/character panels when a screen needs the full workspace (character creation, regional survey); restore them when returning to normal desk phases.
- Verify contrast, focus order/restoration, resize behavior, and reduced motion manually in a running build. Headless tests do not establish visual accessibility.


## Locked career-work taxonomy and circuit

- Layer 1 is **Assignments**: day-to-day forms, inspections, ledger work, and local disputes.
- Layer 2 is **Challenges**: consequential crossroads triggered by persistent career/world conditions.
- Layer 3 is **Epics**: macro-historical undertakings and milestone reviews. `Works` is deprecated terminology; legacy `kind: &"work"` records must be categorized as Epics during compatibility handling.
- Event opportunities whose event ID begins `challenge_` or whose authored tags include `challenge` must be classified as Challenges before entering the desk queue. Do not classify all events as routine assignments.
- Every Epic review and institutional-pressure assignment must expose a meaningful asymmetric disposition after the two-action investigation limit. Verdict costs must be validated and committed in `AssignmentPipeline.resolve()`; UI must not mutate simulation state.
- Challenge conditions must be linked to world flags/resources produced by actual assignment verdicts. Resource-gated Challenge outcomes must validate affordability before effects/rewards. For Quayside, gate only the personal-silver outcome; keep its non-silver verdicts available to broke scribes.
- An Epic audit verdict applies a bounded one-period audit hold through the existing Epic simulator. It must not create a permanent stall or a second project simulation.
- Epic review assignment IDs must include both `review_cycle` and `review_stage`; completed review records are immutable history and must never block a later review of the same stage.
- Epic `inspect_source` evidence must resolve the sponsor institution from the assignment record or its source snapshot before falling back to location inference; sponsor storehouse counts must reflect the actual bins.
- Pending external requisitions older than four simulation periods become priority-8 provincial dispatches, carry a visible `DISPATCH FROM <PROVINCE>` tag, and remain on the board ahead of routine work. They may be opened only after the player travels to the issuing institution's place; enqueue timestamps must be persisted as `created_period`.
- Regional journeys are executed exactly once by `TravelService` against the authoritative `WorldSimulator`, charging the passage fare or recording the existing unpaid-route-fee debt before arrival. The journey vignette blocks desk interaction until explicit disembark; only disembark refreshes the local assignment board. Never advance periods or mutate travel resources in UI code.
- Keep these regressions covered by headless tests: queue routing, verdict stock/flags/progress/opinion/traits, Challenge eligibility, silver affordability, and save/load of active docket state.
- Headless SceneTree tests must not preload `main.gd` merely to reach UI helpers: it depends on project autoload singletons that are absent in `--script` test runs. Extract reusable pure decision logic into a small `RefCounted` system/helper and test that directly.

## Evidence, regional compound, and period-delta rules

- Evidence is player-facing prose, never a debug console. Strip capability diagnostics, raw action tokens, internal form IDs, and raw hazard keys. Translate known document types and site issues into authored labels.
- Evidence inventories include only resources actually tracked by the institution. Empty inventories read `COMMODITY BALANCES: None on record`; do not fabricate zero barley, labor, or textiles.
- Render each recorded stock resource with a readable title-case label (for example, `Clay: 4` and `Labor: 2`), preserving arbitrary resource IDs and their actual recorded quantities.
- Compound information is scoped to `WorldState.current_location_id`. Uruk factions and Eanna content must not leak into Umma or Nippur; show local institutions and seated officials.
- `WorldSimulator` and `TravelService` record categorized changes in `WorldState.last_period_deltas`. Clear at the start of each simulation period, persist via `SaveCodec`, and render only the latest four in `SINCE LAST PERIOD`. UI must not infer causal events from resource snapshots.
- Cuneiform fonts belong under `res://assets/fonts/`; preserve license/provenance text when moving existing assets.


## Living office agenda invariants

- `WorldSimulator._simulate_people()` iterates institution members and invokes one generic `OfficeRunner`; no named-character dispatch or per-office decision logic belongs there.
- `OfficeRunner` selects a LimboAI `.tres` by office ID, seeds Blackboard with `actor`, `institution`, and `world` (plus institution ID), and ticks manually once per period.
- BT resources own decision flow. Shared condition/action tasks read Blackboard; one `OfficeAgendaResolver` validates and commits typed mutations. Never create per-office agent or resolver classes.
- Grain-clerk and granary-clerk tokens share the grain BT. Umma granary and canal office are separate institutions. Nin-Enlil is seated only in `umma_granary`; Ur-Mes only in `umma_canal_bailiff`.
- The Umma canal institution declares both `canal_bailiff` and `granary_clerk` in its staffed-office roles; the actual named seats remain distinct: Ur-Mes holds `canal_bailiff` in the canal institution, and Nin-Enlil holds `granary_clerk` in the granary. Do not double-list Nin-Enlil as a canal member.
- Runtime membership and office maps rebuild from living valid members. Vacancies may be filled by eligible unseated people in the institution's place or parent settlement; do not retain orphan pointers.
- Office cooldowns use the absolute calendar index, which is negative in BCE. Treat a missing prior timestamp as first-use-ready; do not use a small negative sentinel such as `-100` for elapsed-time comparisons.
- `umma_granary` is registry-loaded from a Resource, uses a child place under Umma, and owns local stockpiles. Definitions remain immutable.
- Bailiff forms retain issuing/target institution IDs and `created_period`; local canal requisitions carry priority 7 so they survive the four-slot board, and requests older than four periods escalate through the existing dispatch circuit. A requisition that becomes a dispatch while remote keeps its dispatch flag/tag/priority on arrival, but the travel gate clears once the player is local. Archive and foreman consequences name the acting official and use existing debt/opinion/period-delta/Epic state.
- Office agendas, seats, pending forms, and local state round-trip through `SaveCodec`.

## Living office acceptance commands

Run these headlessly with the pinned Godot 4.7.2 and LimboAI 1.8.1 GDExtension installed:

```sh
godot --headless --path . -s tests/test_living_offices.gd
godot --headless --path . -s tests/test_evidence_and_compound_context.gd
godot --headless --path . -s tests/test_travel_circuit.gd
godot --headless --path . -s tests/test_epics_and_challenges_circuit.gd
godot --headless --editor --path . --quit
```

The office regression must exercise actual seeded seating and BT execution, not manually assigning the named officials' office IDs in the test fixture.


## Player consequence visibility invariants

Run the focused regression with `godot --headless --path . -s tests/test_consequence_visibility.gd` before the existing Era I circuit checks.

- Assignment and procedural docket resolution return a transient typed `consequences` array alongside authored result text. Include named NPC opinion changes with reason, skill XP and any level-up, personal silver/debt, audit exposure, acquired traits, and newly changed flags where applicable.
- Result presentation shows the authored narrative first, then a readable consequence ledger. Do not replace choice-specific Epic result text with generic receipts.
- Consequence presentation and remote courier text are derived views; they do not mutate `WorldState`, `SaveCodec`, or the versioned save schema.
- The Great Canal Cut remains visible from Uruk as backdrop and sends an urgent capital dispatch to a remote player in Umma or Nippur while stalled, disrupted, or awaiting review. Do not expose raw internal problem keys in courier prose.
- Pending Great Canal Cut reviews appear in the remote work queue with `[REQUIRES TRAVEL TO URUK]`; selecting one explains that passage must be booked on the regional survey map and must not open a remote verdict.
- Period audit/arrears deltas must be surfaced as archive notices after the desk board refreshes, so routine HUD refreshes cannot immediately erase them.
