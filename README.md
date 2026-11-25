# Scribe of Eras — First Event Engine Slice

A deliberately narrow Godot 4.7.x foundation: a data-driven event template, runtime person/world state, condition and effect handler maps, and a headless assertion test for the corrupt grain official.

## Run the test

From this directory, with Godot 4.7.x installed:

```sh
godot --headless --path . --script res://tests/test_event_slice.gd
```

The test exits non-zero on an assertion failure and prints a success line only after both player choices have been checked against independent fresh state.

## Scope

Included:
- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState with stockpiles, flags, pending forms, and event history
- EventContext, ConditionEvaluator, EffectExecutor, EventRunner
- Corrupt grain official test fixture

Not included yet:
- UI, scheduler, save format, era registry, office roster, relationship component extraction
- production-grade flag expiry/history pruning
- seven-era content or simulation systems

## Design guardrails

Definitions are immutable at runtime; mutate only runtime entities/world state. Unknown condition/effect types fail closed with warnings. Keep the first vertical slice small enough to understand in one sitting.
