# Scribe of Eras — Second Workday Milestone

A Godot 4.7 GDScript prototype for a data-driven historical scribal career simulation.

## Run it

Open the repository root in Godot **4.7.x stable** and press **F5**. The root project launches the case-file interface.

## Headless event test

From the repository root:

```sh
godot --headless --path . --script res://tests/test_event_slice.gd
```

On Windows, if `godot` is not on PATH, run the executable by its full path, for example:

```powershell
& "C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/test_event_slice.gd
```

The test covers both first-case outcomes, archived assessments, persistence across period advances, both condition-driven follow-up branches, and the empty-queue result.

## Current desk loop

1. Examine the surviving dispatch copy, receiving tally, and missing loading observation.
2. Enter one assessment:
   - No individual responsibility assigned
   - Origin-side dispatch count or handling requires verification
3. Choose whether to certify the tally or open a formal inquiry.
4. Select **End Period** to advance the monthly desk turn.
5. The EventScheduler evaluates the available `.tres` cases against the current actor and world state.
   - The `complicit` trait makes **A Routine Adjustment** eligible.
   - The `grain_scandal` flag plus a pending `inquiry` form makes **The Origin-Side Reply** eligible. Its case text quotes the assessment stored on the archived grain levy.
6. When no event is eligible, the desk displays **END OF QUEUE / All cases filed for now**. The player may continue advancing periods; the scheduler checks again each time.

The clock uses 12 periods per year. `WorldState.advance_period()` changes only the clock; it does not recreate world state or discard stockpiles, flags, people, traits, memories, pending forms, resolved forms, or event history.

## Included

- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState, EventContext, ConditionEvaluator, EffectExecutor, EventRunner, EventScheduler
- Persistent 12-period clock
- Pending and archived form records, including assessment and disposition
- Three data-driven case definitions: the missing measures, routine tally adjustment, and origin-side reply
- Case-file UI with an explicit end-of-queue state

## Not included yet

- Versioned save format
- Office roster and extracted relationship component
- Flag expiry/history pruning
- Full calendar presentation and production UI polish
- Seven-era content or simulation systems

## Guardrails

Definitions are Resources; runtime changes affect only world/person state. Unknown condition/effect types fail closed with warnings. Unsupported resource scopes warn and do not mutate state. The scheduler selects only templates whose existing conditions and eligibility gates pass; story branches are data, not day-number script branches.
