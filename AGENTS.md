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
