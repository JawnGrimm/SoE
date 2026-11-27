# Regional World and Travel Systems

## Ownership

- `PlaceDef` (`data/places/*.tres`) is the authored source for settlements, precincts, work areas, parent-place hierarchy, region, era, and survey coordinates.
- `InstitutionDef` (`data/institutions/*.tres`) is the authored source for institutional identity, location, era, members, interests, starting stores, and local ledger-work presentation.
- `RouteDef` (`data/routes/*.tres`) is the authored source for route endpoints, mode, direction, duration, display name, and era.
- `EraDef.starting_place_id` chooses the campaign's starting settlement.
- `DefinitionRegistry` loads and validates these references. Definitions are read-only after loading.
- `WorldState` owns mutable place, institution, route-disruption, hazard, assignment, and current-location records. Seeded state is copied from definitions.
- `RouteNetwork` is the headless route graph and filters route/place definitions for the active era.
- `TravelCalculator` calculates direction, duration, closure, and disruption penalties.
- `TravelService` validates and executes a complete journey. It calls `WorldSimulator.advance_period(world)` once for every transit period, then changes the current location only on arrival.
- `WorldSimulator` owns the authoritative world tick. LimboAI owns autonomous NPC intent selection; SoE resolvers validate and apply those intents to world state.
- `AssignmentPipeline` generates local forms, hazards, institutional pressure, and ledger work from the current settlement's place hierarchy.
- `RegionalSurveyMap` is a cedar-desk presentation component. It renders the route graph using Worldmap Builder's `WorldmapView` and `WorldmapGraph`; it does not own travel rules.

## Authoring a place

Create a `PlaceDef` Resource in `res://data/places/`. Set `id`, `display_name`, `place_type`, `region`, `era_id`, and optional `parent_place_id`. Route endpoints must also have a non-zero `survey_position` authored for the Worldmap Builder survey.

A work area is a place with a parent. For example, North-Bay belongs to Eanna Precinct, which belongs to Uruk. Local assignment and hazard ownership follow this hierarchy; they do not need settlement-specific branches.

## Authoring an institution

Create an `InstitutionDef` Resource in `res://data/institutions/`. Set `place_id` to an authored place and `era_id` to the era in which it exists. Runtime stockpiles, activity, pressure, membership changes, and audit history are copied into `WorldState` and never written back to the definition.

Optional `ledger_work_title`, `ledger_work_summary`, and `ledger_work_priority` customize the routine ledger opportunity without adding institution IDs to the assignment system.

## Authoring a route

Create a `RouteDef` Resource in `res://data/routes/`. Its endpoints must resolve to registered places. `era_id` scopes it to an era; an empty era ID means shared route data. River direction and base transit periods remain in `TravelCalculator`, while disruptions are runtime records in `WorldState.routes`.

## Desk interaction

The **Unroll Regional Survey** control opens the survey in the docket bay on the cedar desk. The compound ledger, evidence cards, and tool tray remain visible. Selecting a connected node shows the authored route name, live route status, and calculated duration. The board action emits a travel request to `main.gd`, which delegates execution to `TravelService`.

Travel is blocked while a case or accepted engagement is active. A clear desk may depart. Closing or completing local work returns the player to the survey-ready desk.

## Verification

Run the headless project import, then:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_route_network.gd
godot --headless --path . --script res://tests/test_travel_circuit.gd
godot --headless --path . --script res://tests/test_grain_clerk_agenda.gd
```

The travel-circuit test drives the Worldmap Builder node-input signal, selects the Nippur barge, advances the real simulator for two periods, completes Nippur's data-authored ledger assignment, returns downstream for one period, and verifies the persistent Ur-Nanna cover-up evidence and delivered grain docket.
