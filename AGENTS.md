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

## UI and accessibility guardrails

- Read `ACCESSIBILITY.md` before changing desk, HUD, menus, overlays, or other player-facing controls.
- Keep reusable presentation components under `ui/`; keep assignment generation/resolution, world mutation, and save behavior in `systems/`.
- UI controls must call the existing pipeline and SaveManager APIs. Do not directly mutate simulation state from presentation scripts.
- Keep transient UI state (open panels, focus, queue filters, animation state) out of save data.
- Provide keyboard equivalents for clickable desk props, visible focus, meaningful labels/tooltips, and Escape handling for overlays. Cuneiform glyphs are decorative/atmospheric and must always be paired with plain-language labels.
- Hide evidence/character panels when a screen needs the full workspace (character creation, regional survey); restore them when returning to normal desk phases.
- Verify contrast, focus order/restoration, resize behavior, and reduced motion manually in a running build. Headless tests do not establish visual accessibility.

## Assignment and character-creation UX backlog

Treat the following as acceptance criteria for the next focused desk polish pass; preserve the existing assignment action budget and simulation pipeline.

- **Formative choice completion:** after a player selects an answer, recompute completion/continue eligibility from the actual required-answer state. A choice must satisfy its requirement and unlock Continue immediately; no stale disabled state. Answers may legitimately remain unavailable until their prerequisite is met, so show the missing prerequisite in plain language.
- **Character creation closeout:** use the established **“Take up the reed”** action as the single final confirmation. Remove redundant confirmation/summary screens that ask the player to affirm the same choices again.
- **Skill-based NPC preview:** retain assignment choice hover previews that tint affected NPC cards red/green. Compute the preview from the relevant character skills and choice requirements/effects, not a fixed choice-to-color mapping. Color must be accompanied by a readable cue/icon or short explanation; preview on focus as well as hover.
- **Contextual assignment actions:** replace generic NPC requests to perform four uncontextualized actions with assignment-specific, situated requests. Each request must explain what it would establish or change, consider the assignment's remaining inquiry-action budget, and never offer an action that exceeds the limit. At the limit, present disposition choices without another investigation affordance.
- **Assignment choice density:** reduce screen jumping and unnecessary scrolling by keeping the assignment prompt, current evidence/context, available choices, and remaining action count together in the existing desk workspace. Prefer compact sections and inline expansion over navigating between screens; do not expand the overall desk layout.
- **Mentor trait clarity:** never show a trait such as “Pliable” as unexplained jargon. Pair the trait with a concise player-facing explanation of what it signals, how the player learned it, and what practical implication it has (without implying certainty where it is only a tendency).
- **Music continuity:** avoid frequent music changes between adjacent desk/assignment states. Keep the current track across routine UI transitions; change music only on a meaningful scene/era/mood boundary, with explicit transition rules and no repeated restart when the same state is re-entered.

