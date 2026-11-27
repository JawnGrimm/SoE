# Phase 1 — LimboConsole Developer Command Router

**Depends on:** Phase 0 ground-truth baseline and removal of the stale Province Map Builder plugin reference.  
**Engine target:** Godot 4.7.2.

## Goal

Make simulation testing faster without introducing a second simulation path. SoE registers a small, namespaced command set with the LimboConsole autoload already present in the project.

The router owns command registration only. It owns no world state and delegates every operation to callbacks supplied by the active desk scene.

## Commands

| Command | Behavior |
|---|---|
| `soe advance_periods <count>` | Advance 1–120 periods, running the same `WorldSimulator.advance_period(world)` and case-scheduling lifecycle used by the desk. Requires completed character creation. Stops early if an era Epic completes. |
| `soe inspect_world` | Report year/period, person and institution counts, forms, active hazards, and active Epic. |
| `soe inspect_person <person_id>` | Report the selected person's identity, office, traits, skills, resources, relationships, and memory count. |
| `soe adjust_resource <resource_id> <amount> [scope] [owner_id] [institution_id]` | Apply a signed resource delta through `WorldState.modify_resource()`; never edits dictionaries directly. |

Stable person and resource IDs are exposed through LimboConsole argument autocomplete.

There is deliberately no `trigger_event` command in this first router. Events are condition- and eligibility-driven. A forced event command that bypasses the scheduler would test a different system from the one the game actually runs. A later test-only event inspection/request workflow can be designed around the existing eligibility rules.

## Simulation safety

- `advance_periods` is a debug-only operation, limited to 1–120 periods per invocation.
- It refuses to run before a player character has been committed to WorldState.
- Each period goes through the normal world simulator, then updates the desk's current case/opportunity presentation.
- It stops when the normal Epic-completion condition is reached.
- The player-facing `_advance_period()` phase gate remains intact. The console calls a shared internal one-period method rather than bypassing the phase gate with a second implementation.
- Resource changes use the existing scoped API and report the before/after values.
- The router registers namespaced commands and unregisters them when the desk scene leaves the tree.

## Release-build guard

LimboConsole's `ConsoleOptions.CONFIG_PATH` is `res://addons/limbo_console.cfg`. The addon-local `addons/limbo_console/limbo_console.cfg` is not the runtime project configuration.

This step adds the project-level config with `disable_in_release_build=true`, and the router independently refuses registration unless `OS.is_debug_build()` is true.

## Tests

`tests/test_dev_command_router.gd` uses a fake console and injected callbacks to verify:

- command registration and namespacing;
- callback delegation and argument forwarding;
- autocomplete registration;
- output/error reporting;
- clean unregistration.

The existing event/period integration test remains unchanged and must continue to pass. CI runs both tests on Godot 4.7.2.
