# Regional World Loop — Uruk Slice

**Status:** Approved direction / implementation in progress  
**Scope:** First playable regional career loop for Scribe of Eras

## Identity

Uruk is a metropolitan hub in a connected regional world, not a village-scale sandbox. The player's desk is a point of leverage over people, goods, institutions, and events that the character cannot personally witness.

The Storehouse Reckoning remains the introductory tutorial and a regression fixture. It is not the assignment template, the career fantasy, or the dominant source of work.

Historical detail serves the fiction and play. The project may use deliberate compression, invented institutions, and dramatic geography where that creates a stronger RPG. Do not shrink the world to avoid uncertainty about historical reconstruction.

## Locked turn and work decisions

- The world advances through 12 periods per year: four seasons, three turns per season.
- Each turn presents three work opportunities generated from the living world.
- Opportunity generation is mixed: current world conditions, institutional needs, regional flows, events, and career connections.
- Declining is free.
- Assignment engagement length varies with the job.
- The world advances whether or not the player accepts work.
- Assignments are professional RPG encounters, not a mandatory four-step investigation checklist.
- Career XP, Challenges, Works, and Historical Progress remain distinct systems. Routine regional assignments do not award Historical Progress XP.

## Regional world model

### Places

Places include metropolitan districts, settlements, outposts, ports/landings, worksites, and route stations. Each place has identity, region, local institutions, political relationships, and relevant economic activity.

Initial regional anchors:

- Uruk / Eanna / Kullaba and the agricultural hinterland
- Eridu, Ur, Umma, and Nippur
- Habuba Kabira and Djebel Aruda
- Mari
- Tell Brak and Hamoukar
- Susa and Godin Tepe

### Routes

Routes are immutable RouteDef Resources. Runtime route state belongs to WorldState.

A route records its endpoints, mode, travel duration, and risk. Routes form a directed graph; pathfinding selects connected legs. A route's condition can later be affected by season, regional events, political control, hazards, and local agreements.

Distance matters as elapsed periods, resource pressure, uncertainty, and exposure—not merely a map coordinate.

### Goods and information flows

Shipments are runtime records with:

- origin and destination
- commodity and declared quantity
- seal and sender
- route legs and departure period
- actual quantity remaining after simulated route events
- arrival period and disposition

The world simulates shipment movement. Arrival creates a remote dispatch form from the actual shipment record. The assignment may establish what was declared, what arrived, and where the record chain becomes uncertain. A shortfall is not automatically theft; it may result from loss, damage, diversion, fraud, or incomplete evidence.

Correspondence is delayed. A request for an origin-side copy creates a later reply rather than instantly revealing distant facts.

## Assignment experience

Remote dispatches use context-appropriate approaches, such as:

- examining the seal and origin record
- comparing manifest and arrival quantities
- questioning the carrier
- inspecting the cargo at landing

Skill determines the reliability and precision of what the character establishes. The player does not perform spreadsheet work; the character's skill resolves the calculation and communicates the result.

The player's consequential decisions include accepting the cargo, holding it, requesting an origin account, assigning responsibility, amending the record, or allowing a relationship or institution to absorb the risk.

Field postings use the same regional route graph but a different encounter flow. The player accepts a posting, travels over periods, experiences route friction, arrives at a place with local institutions and relationships, and works under conditions that differ from Uruk. Travel and posting are world/career systems, not a special storehouse assignment.

## Simulation boundaries

- The world creates and resolves movement, production, shortages, route disruptions, institutional pressure, and regional events without waiting for the player.
- Assignment generation surfaces meaningful opportunities from those conditions; it does not invent a discrepancy solely to create a puzzle.
- LimboAI manages the player's assignment and posting phases. It does not own the world simulation, shipment truth, skill math, or consequences.
- Definition Resources are immutable. Runtime shipments, route conditions, travel, and assignment progress live in WorldState and are saved separately.
- The same systems serve later eras; data changes the places, routes, institutions, commodities, and document practices.

## First regional proof

The first proof is a sealed timber consignment from Habuba Kabira to Uruk:

1. It departs with a declared quantity and seal.
2. It moves over the upper Euphrates route across three periods.
3. The simulation may produce route loss; the arrival record uses actual received quantity.
4. Arrival creates a remote dispatch opportunity.
5. The player uses relevant skills and chooses a consequential disposition.
6. The shipment, institution, relationships, and work log reflect the decision.

The next expansion is field posting and travel friction, followed by broader regional flow generation. Do not return the assignment board to routine local storehouse inspections as its default content.
