# Scribe of Eras

*A historical career RPG about the people who keep civilization running—and the records that outlive them.*

Scribe of Eras is a single-player historical career RPG and administrative simulation. You are not a king, general, or famous inventor. You are a working person inside the institutions of your time: a clerk, official, merchant, religious functionary, quartermaster, or other quiet operator whose decisions can ripple outward.

You record deliveries, allocate resources, certify claims, manage obligations, cultivate relationships, and decide when to follow the rules—or bend them. The world has its own people, pressures, and history. It does not exist merely to provide you with jobs.

The game is built around one idea:

**History is made by countless people whose names were never written down. You get to play one of them.**

---

## The game

The player's career and the wider historical world are connected, but they are not the same thing. Character creation establishes where the player enters that world. Ordinary work builds a record of their actions. Challenges respond to that record. Epics develop on their own timelines, with or without the player's involvement.

~~~mermaid
flowchart TD
    A["CHARACTER CREATION"] --> B["Backstory & stat questions"]
    B --> C["Family, reputation, relationships & obligations"]
    C --> D{"Choose a path"}

    D --> P1["Civil"]
    D --> P2["Religious"]
    D --> P3["Martial"]
    D --> P4["Merchant"]

    P1 --> E["PLAYER ENTERS THE WORLD"]
    P2 --> E
    P3 --> E
    P4 --> E

    E --> F["ORDINARY WORK"]
    F --> G["Assignments, people & decisions"]
    G --> H["PLAYER WORK RECORD"]
    G --> W["WORLD STATE CHANGES"]
    H --> W

    H --> I["CHALLENGE GENERATION"]
    W --> I
    I --> J["PERSONALIZED MAJOR CHALLENGE"]
    J --> K["Difficult work · consequential choices · better rewards"]
    K --> H
    K --> W

    W --> L["EPICS"]
    L --> M["Historical actors, institutions, resources & events"]
    M --> N["Development continues with or without the player"]
    W -. "Player may contribute" .-> L
    H -. "Reputation, relationships & prior actions" .-> L
    N --> O{"Historical milestone reached?"}
    O -- "Not yet" --> M
    O -- "Yes" --> Q["ERA TRANSITION"]
    Q --> R["NEXT ERA"]
    R --> F
~~~

The diagram is a relationship map, not a mandatory quest chain. Challenges can seed or be seeded by historical developments. The player's actions can affect an Epic's conditions, but the player is never required to be the famous person at its center.

## Core systems

### Paths

Character creation is an authored sequence of questions, not just a stat allocation screen. Answers establish the player's background, family circumstances, skills, reputation, relationships, and obligations. The player then chooses a professional path:

- **Civil** — administration, law, records, taxation, labor, and public works.
- **Religious** — temple or religious institutions, ritual obligations, property, resources, and authority.
- **Martial** — military administration, supply, logistics, service, and the people attached to them.
- **Merchant** — trade, contracts, transport, credit, materials, and commercial relationships.

Paths shape the player's entry into the world and the kinds of work and people they encounter. They are starting positions, not four separate games.

### Work

Work is the ordinary business of a career: assignments, responsibilities, records, and decisions. It gives the player a place in an institution and a reason to interact with other people.

Ordinary work is not filler between major quests. It creates the player's history. Who received the grain? Which crew was paid? Whose claim was certified? Which shortage was ignored? Those actions should matter later.

### Work Record

The Work Record is the accumulated history of what the player actually did and decided. It is more than a score or a list of completed tasks. It provides the context from which the world—and especially its people—can respond.

It can include actions, authorizations, omissions, resource movements, relationships affected, obligations created, and institutional consequences.

### Challenges

Challenges are substantial, difficult jobs generated in response to the player's Work Record and current circumstances. They are not simply random quests or a fixed list of authored missions.

A Challenge might arise because of a previous decision, a damaged relationship, an obligation left unresolved, a pattern noticed by an institution, or a problem the player is unusually well placed to handle. Challenges offer greater difficulty and better rewards, and their outcomes change both the player's record and the world.

Challenges are authored situations assembled and contextualized against the player's history—not arbitrary procedural stories.

### Epics

Epics are major historical developments: inventions, texts, buildings, reforms, trade networks, conflicts, discoveries, and other events that shape the passage from one era to another.

They have their own actors, institutions, needs, resources, obstacles, and timelines. They continue whether or not the player gets involved.

The player may contribute directly, indirectly, or not at all. A printing press needs materials, tools, labor, money, transport, suppliers, and permissions. The player might arrange a purchase, extend credit, approve a shipment, delay a delivery, or divert supplies. They do not need to invent the press—or even meet its famous inventor—to affect what happens.

The historical figure may be remembered. The people who made the work possible usually are not. The player gets to occupy one of those places.

Epics provide the historical milestones that can move the campaign into a new era. Era progression is therefore tied to developments in the world, not simply to the calendar advancing or the player filling an experience bar.

## Historical approach

The world can be complex without making every document complex.

The earliest eras should present writing and records appropriate to their historical context. In Uruk around 3200 BCE, that means simple administrative records: people, commodities, quantities, ownership, dates, seals, and basic marks—not modern prose reports disguised as clay tablets.

The written record is the player's instrument, not the entirety of the game. Most play concerns people, relationships, institutions, resources, and circumstances around the record. The document may be brief; the human situation behind it need not be.

The simulation distinguishes between:

1. **What happened** in the world.
2. **What people know, believe, suspect, or claim** happened.
3. **What an institution formally records.**

Those accounts can disagree. The player is not an omniscient detective. They are an administrative actor making decisions with incomplete information.

As eras change, documentary forms, institutions, communication, markets, and the reach of administration change too. This is not a simple progression from primitive to sophisticated: different societies and writing traditions have their own forms, purposes, and constraints.

## Current prototype

The current playable prototype is an early Uruk administrative desk scenario. It is a systems and interaction slice, not yet a complete implementation of the full game described above.

The current desk loop includes:

1. Examine the surviving dispatch copy, receiving tally, and missing loading observation.
2. Enter an assessment:
   - No individual responsibility assigned.
   - Origin-side dispatch count or handling requires verification.
3. Choose whether to certify the tally or open a formal inquiry.
4. Select **End Period** to advance the monthly desk turn.
5. The EventScheduler evaluates available .tres cases against the current actor and world state. The North-Bay Roof Inspection currently appears as a separate cedar-desk docket in the prototype. Consult Ur-Nanna, inspect the beams, and submit a supported assessment.
   - The **complicit** trait makes **A Routine Adjustment** eligible.
   - The **grain_scandal** flag plus a pending **inquiry** form makes **The Origin-Side Reply** eligible. Its case text quotes the assessment stored on the archived grain levy.
6. When no event is eligible, the desk displays **END OF QUEUE / All cases filed for now**. The player may continue advancing periods; the scheduler checks again each time.

The prototype clock uses 12 periods per year. WorldState.current_period_index() provides an absolute period index (year * 12 + period) for durations and deadlines. Flag effects accept periods (or legacy years, converted to 12 periods per year); flags expire automatically when their expiry period begins. Forms may include an absolute due_period; they become overdue after that period passes, remain pending until resolved, and retain an overdue record in the archive. Forms without a deadline are unaffected.

These are current implementation details, not restrictions on the final design. In particular, the current temple-path gate for North-Bay is a prototype shortcut; the intended game will offer work based on the character's path, qualifications, history, and world circumstances.

## Technical overview

- **Engine:** Godot 4.7.x
- **Language:** GDScript
- **Definitions:** Custom Resources (.tres); definitions are data, not runtime state.
- **Runtime:** World and person state are held separately from definition Resources.
- **Events:** Data-driven condition, effect, outcome, and event-template Resources.
- **Evaluation:** Handler maps for conditions and effects; unknown handlers warn and fail closed.
- **Registry:** Autoload indexes definitions by ID.
- **Time:** Persistent 12-period calendar in the current prototype.

The project favors composition over inheritance. Systems operate on runtime state; definitions describe available content. The same underlying systems should support different eras through data rather than era-specific script branches.

## Run it

Open the repository root in Godot **4.7.x stable** and press **F5**. The root project launches the case-file interface.

## Headless tests

From the repository root:

~~~sh
godot --headless --path . --script res://tests/test_event_slice.gd
~~~

On Windows, if godot is not on PATH, run the executable by its full path, for example:

~~~powershell
& "C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/test_event_slice.gd
~~~

The current test covers the first-case outcomes, archived assessments, persistence across period advances, era-aware eligibility, flag expiry, form deadlines, condition-driven follow-up branches, and the empty-queue result.

## Current prototype includes

- Event condition/effect/outcome/template Resources
- Skills and person runtime state
- WorldState, EventContext, ConditionEvaluator, EffectExecutor, EventRunner, and EventScheduler
- Persistent 12-period clock
- Pending and archived form records, including assessment and disposition
- Three data-driven case definitions: the missing measures, routine tally adjustment, and origin-side reply
- North-Bay assignment offer, consultation and inspection records, and assessment settlement
- Persistent North-Bay roof leak that spoils one measure of barley per elapsed period
- Case-file UI with an explicit end-of-queue state

## Not implemented yet

- Versioned save/load format
- Complete character creation and family-history generation
- Four playable career paths and their full work content
- Generalized Work and Challenge generation
- Epics and era-transition logic
- Full NPC social simulation and institutional knowledge
- Era-specific documentary systems and content
- Production menus, audio, and UI polish

## Development guardrails

- Definitions are Resources; runtime changes affect only world/person state. Duplicate mutable Resources before changing them.
- Unknown condition/effect types fail closed with warnings.
- Unsupported resource scopes warn and do not mutate state.
- The scheduler selects only templates whose existing conditions and eligibility gates pass; story branches are data, not day-number script branches.
- The world should not wait for the player. Historical actors, institutions, and developments have their own needs and timelines.
- Do not confuse internal simulation precision with what the player can know or what an era's documents can express.
