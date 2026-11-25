# Scribe of Eras — First Playable

A Godot 4.7 GDScript prototype for the first small playable case in **Scribe of Eras**.

## Run it

Open the repository root in Godot **4.7.x stable** and press **F5**. The root project launches the case-file interface for *The Missing Measures*.

## Headless event test

From the repository root:

```sh
godot --headless --path . --script res://tests/test_event_slice.gd
```

On Windows, if `godot` is not on PATH, run the executable by its full path, for example:

```powershell
& "C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/test_event_slice.gd
```

The test checks both player choices against isolated world state, including the preservation and archival of the entered assessment.

## Play loop

1. Examine the surviving dispatch copy, receiving tally, and missing loading observation.
2. Enter one assessment:
   - No individual responsibility assigned
   - Origin-side dispatch count or handling requires verification
3. Choose whether to certify the tally or open a formal inquiry.
4. See the resulting world state and chronicle entry.

The evidence does not identify who caused the discrepancy. The player can record uncertainty or request verification without converting a missing record into an accusation.

## Included

- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState, EventContext, ConditionEvaluator, EffectExecutor, EventRunner
- Pending and archived form records, including assessment and disposition
- Corrupt grain official event definition
- First playable case-file UI and choice loop

## Not included yet

- Event scheduler, registry autoload, save format, era selection
- Office roster and extracted relationship component
- Flag expiry/history pruning
- Multiple cases, calendar loop, production UI polish
- Seven-era content or simulation systems

## Guardrails

Definitions are Resources; runtime changes affect only world/person state. Unknown condition/effect types fail closed with warnings. Unsupported resource scopes warn and do not mutate state. Event definitions remain data-driven; this slice is deliberately one case, not the seven-era simulation.
