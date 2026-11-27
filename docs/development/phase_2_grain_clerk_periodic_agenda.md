# Phase 2 — Ur-Nanna's Periodic Grain-Clerk Agenda

## Scope

This slice gives exactly one NPC, Ur-Nanna, one LimboAI behavior tree:
`res://data/behavior_trees/bt_grain_clerk_agenda.tres`.

The tree is evaluated once by `WorldSimulator.advance_period()`. It does not run on frame, physics, daily, or hourly clocks. No merchant, laborer, sleep, food, or daily-routine trees are introduced.

## Decision contract

**The behavior tree chooses intent. SoE systems validate and resolve it.**

The selector evaluates these branches in order:

1. **Emergency Cover-Up / Self-Preservation**
   - North-Bay `roof_leak` is active.
   - Ur-Nanna's `personal_fear` is greater than 5.
   - Requests `intent_hide_spoilage`.
2. **Skim the Surplus / Greed and Debt**
   - Eanna household barley exceeds 400.
   - Eanna household silver is below 5.
   - Requests `intent_pocket_measures`.
3. **Routine Custody**
   - Requests `intent_log_deliveries` as the default.

The custom LimboAI tasks only query the temporary `GrainClerkAgent` adapter or request an intent. `GrainClerkAgendaResolver` revalidates each illicit condition and mutates only runtime `WorldState` data.

## Evidence rule

Secret actions queue evidence in the Eanna institution's runtime record. The queue is delivered on the following period and attached to the existing `held_barley` form where possible. The normal assignment board then exposes a contradictory docket; normal investigation reveals both source records and the discrepancy.

The cover-up records a prime-seed-corn declaration while the independent threshold tally records damp, mold-marked barley. Skimming records a two-measure intake adjustment and queues its own independent tally conflict. Neither action silently changes physical stock.

## Dependency

The project uses LimboAI 1.8.1 GDExtension for Godot 4.7.2. Native binaries are intentionally excluded from Git. The Windows installer at `tools/install_limboai.ps1` downloads the pinned release and verifies SHA-256. CI downloads and verifies the pinned cross-platform GDExtension package before Godot import and tests.

## Headless acceptance

`tests/test_grain_clerk_agenda.gd` verifies:

- one Ur-Nanna grain clerk and the seeded fear threshold;
- emergency branch priority when both emergency and skimming conditions are true;
- SoE-side validation and concealed-spoilage record mutation;
- evidence delivery exactly one period later;
- visibility through the existing assignment board and investigation flow;
- exactly one agenda evaluation per period;
- the skimming branch and the routine default branch.

No visual map or UI scene is introduced by this slice.
