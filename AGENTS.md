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


## Era I Slice A gameplay guardrails

- The Great Canal Cut begins dormant. It must not advance, erode, or request stage reviews until activated by its authored career milestone or an explicit summons. Keep launch thresholds centralized and test both dormant and launched states.
- A world assignment permits at most two investigative actions. The third action must fail closed; the desk disables remaining inquiry choices and prompts for disposition. Do not expand the assignment UI layout to implement this rule.
- Investigation must reveal distinct evidence: tablet origin/claim, numeric account reconciliation, physical site/bin state, and the responsible official's situated stance. Do not expose raw simulation metric keys or generic ledger boilerplate as player-facing copy.
- Assignment verdicts must change persistent world state when the matter warrants it: institutional stock/pressure, concealed records, relationships, audit exposure, and the career chronicle. Silver pressure must create debt/reprimand rather than a travel or work soft-lock.
- Uruk work-record sub-places resolve to their responsible institution through explicit ownership first, then parent-place routing. Do not leave assignment institution_id or employer_id blank when a valid local institution/person exists.
- Slice A does not add settlements, redesign the desk, or implement Phase B succession. Keep Era I work focused on the apprentice's local/regional career and the first meaningful judgment loop.