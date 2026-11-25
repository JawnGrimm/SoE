# Scribe of Eras — First Playable

A Godot 4.7 GDScript prototype for the first small playable case in **Scribe of Eras**.

## Run it

Open this folder in Godot **4.7.x stable** and press **F6** (run current scene) or **F5** (run project).

The prototype uses a case-file interface and one event: *The Missing Measures*.

## Play loop

1. Examine the surviving dispatch copy, receiving tally, and missing loading observation.
2. Enter one assessment:
   - No individual responsibility assigned
   - Origin-side dispatch count or handling requires verification
3. Choose whether to certify the tally or open a formal inquiry.
4. See the resulting world state and chronicle entry.

The evidence does not identify who caused the discrepancy. The player can record uncertainty or request verification without converting a missing record into an accusation.

## Headless event test

From this directory, run:

```sh
godot --headless --path . --script res://tests/test_event_slice.gd
```

On Windows, if `godot` is not on PATH, run the executable by its full path, for example:

```powershell
& "C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/test_event_slice.gd
```

The test exits non-zero on assertion failure and prints a success line after both outcomes are checked against independent fresh state.

## Included

- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState, EventContext, ConditionEvaluator, EffectExecutor, EventRunner
- Corrupt grain official test fixture
- First playable case-file UI and choice loop

## Not included yet

- Event scheduler, registry autoload, save format, era selection
- Office roster and extracted relationship component
- Flag expiry/history pruning
- Multiple cases, calendar loop, production UI polish
- Seven-era content or simulation systems

## Guardrails

Definitions are Resources; runtime changes affect only world/person state. Unknown condition/effect types fail closed with warnings. The current case definition is assembled as Resources in the prototype script so the interaction can be tested immediately; next step is moving its content into `.tres` data and adding a small resource registry.
