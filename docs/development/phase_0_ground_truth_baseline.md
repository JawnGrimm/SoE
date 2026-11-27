# Phase 0 — Ground Truth Baseline

**Baseline branch:** `main`  
**Baseline commit:** `37e61307ece64f3e1d3231ecb9b100fa44a087d2`  
**Engine target:** Godot 4.7.2  
**Purpose:** Record the repository and integration facts before adding the SoE developer command router.

## Approved scope and constraints

The next implementation work follows these decisions:

- Use **Worldmap Builder only** for the future regional node-and-connection graph.
- Do not integrate Province Map Builder as a second map workflow. At the recorded baseline commit, its files were still tracked; the later removal from main is noted below.
- The regional map is a survey layer unrolled on the cedar desk. It must not replace the desk view or hide the compound ledger and tool tray.
- Keep each implementation step in its own documented pull request.
- The immediate implementation sequence is this baseline, followed by the LimboConsole developer command router.

No gameplay code or addon installation changes are part of this Phase 0 documentation PR.

## Repository inventory

The repository already contains the relevant foundations:

| Area | Current location | Baseline finding |
|---|---|---|
| Main project | `project.godot` | Configured for Godot 4.7 and GL Compatibility |
| Main gameplay scene/script | `main.tscn`, `main.gd` | Existing cedar-desk gameplay is implemented in the root scene/script |
| Runtime world | `systems/world_state.gd` | `WorldState` owns year, period, people, institutions, stockpiles, forms, hazards, flags, and other runtime records |
| Period simulation | `systems/world_simulator.gd` | `WorldSimulator.advance_period(world)` delegates calendar/deadline/hazard advancement to WorldState and owns autonomous simulation work |
| Console addon | `addons/limbo_console/` | LimboConsole 0.8.0 is already present |
| Console autoload | `project.godot` | `LimboConsole` is already configured as an autoload |
| Console editor plugin | `project.godot` | `res://addons/limbo_console/plugin.cfg` is already enabled |
| Map addon | `addons/worldmap_builder/` | Worldmap Builder is already present and enabled |
| Existing tests | `tests/test_event_slice.gd` | Event, period, world simulation, persistence, and related integration checks live here |
| CI | `.github/workflows/godot-ci.yml` | Imports the project and runs the event/period integration test on Godot 4.7.2 |

At the recorded baseline commit, the repository also tracked `addons/province_map_builder/` and a root-level `province-map-builder-main.zip`. A subsequent main commit (`4d3a138d3000ed30c424cd2ec25f9efd35018ddc`) removed the addon directory. Inspection of that commit found that `project.godot` still lists `res://addons/province_map_builder/plugin.cfg` as an enabled editor plugin. A separate cleanup PR is required to remove that stale reference; it is not bundled into the LimboConsole implementation.

## Existing period-advance path

The current gameplay action in `main.gd` is phase-gated:

1. `_advance_period()` accepts only the `result` and `end_of_queue` phases.
2. It clears transient assignment/stamp state.
3. It calls `world_simulator.advance_period(world)`.
4. It checks Epic completion and otherwise schedules the next case.

`WorldSimulator.advance_period(world)` is the reusable simulation entry point. `WorldState.advance_period()` advances the 12-period calendar and processes deadlines and hazards. The developer command router must reuse the simulation path and must not reproduce its logic or directly edit definition Resources.

The console command should be able to advance multiple periods for testing without requiring the player-facing phase gate or a sequence of button clicks. The router must still preserve the normal per-period simulation and scheduling behavior. Its integration point will be selected after tracing the full initialization and scheduling lifecycle; this document does not pre-empt that code review.

## LimboConsole configuration findings

The addon README documents the public registration API:

```gdscript
LimboConsole.register_command(callable, command_name, description)
```

It also documents `LimboConsole.info()`, `error()`, `warning()`, and argument autocomplete registration.

Current project configuration already includes:

- `LimboConsole` autoload.
- Backtick toggle input action.
- Editor plugin enabled.
- LimboConsole configuration file at `addons/limbo_console/limbo_console.cfg`.

**Release-build guardrail:** the current addon configuration has `disable_in_release_build=false`. That means the console is not currently configured to disable itself in release builds. Phase 1 must correct this before adding SoE-specific commands. Debug commands must not ship as an available release-build interface.

The checked-in addon identifies itself as version 0.8.0. Its README advertises Godot 4.3; the repository's Godot 4.7.2 CI currently imports and tests the project successfully with the addon enabled. Phase 1 should continue to validate the actual checked-in source and CI rather than relying on the README badge as a compatibility guarantee.

## Baseline CI

The latest workflow run attached to the baseline commit is:

- **Workflow:** Godot CI
- **Run:** [45924803863](https://github.com/JawnGrimm/SoE/actions/runs/45924803863)
- **Commit:** `37e61307ece64f3e1d3231ecb9b100fa44a087d2`
- **Result:** Success
- **Godot:** 4.7.2
- **Import/resource validation:** Passed
- **Event and period integration tests:** Passed

This is the baseline pass that subsequent implementation PRs must preserve.

## Phase 0 exit criteria

- [x] Record the exact baseline commit.
- [x] Confirm the installed LimboConsole and Worldmap Builder paths.
- [x] Confirm LimboConsole is already enabled as an autoload and editor plugin.
- [x] Trace the current period-advance entry points.
- [x] Record the current Godot 4.7.2 CI result.
- [x] Record release-build console configuration as a Phase 1 issue.
- [x] Record the approved single-map-plugin and diegetic-desk constraints.
- [ ] Review and merge this documentation PR.

## Phase 1 handoff

Phase 1 will add a small SoE-owned command router that registers commands with the existing LimboConsole. Commands will call normal SoE systems, not mutate definition Resources or maintain a second simulation implementation.

Initial command candidates:

- `advance_periods <count>` — run the normal simulation step repeatedly, including the same world simulation and case-scheduling lifecycle used by gameplay.
- `inspect_world` — report current year/period and selected high-value runtime counts.
- `inspect_person <person_id>` — report a person's runtime state without mutating it.
- `set_resource <resource_id> <amount> [scope] [owner_id]` — a clearly marked debug operation routed through the existing scoped resource API, with validation and explicit output.
- `trigger_event <event_id>` — only if the existing EventRunner exposes a safe, deterministic way to request an event; otherwise defer it rather than bypass eligibility.

The final command list and exact signatures will be based on the code review in Phase 1. The router should register/unregister cleanly with the active gameplay scene, expose useful autocomplete where stable IDs are available, and remain unavailable in release builds.
