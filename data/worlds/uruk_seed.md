# Uruk World Seed

The Uruk opening now seeds a small connected world rather than a handful of isolated event actors.

## Starting conditions

- Campaign year: 3200 BCE
- Starting character: Enlil-barni, apprentice scribe
- Seeded people: 17
- Places: 9
- Institutions and exchange networks: 3
- Household and working groups: 5
- Directed person-to-person relationship edges: 19

## People

| Person | Role | Connections that matter |
|---|---|---|
| Enlil-barni | Apprentice scribe / player | Mentored by Shuruppak-ilu; member of Geme-tur's household |
| Shuruppak-ilu | Archive keeper | Mentor to the player; respected by Ur-Nanna and Lu-Nanshe |
| Ur-Nanna | Grain clerk | Depends on carrier capacity; receives grain obligations from households |
| Utu-mansum | Tax scribe | Professional rivalry with Lu-Nanshe |
| Enlil-kisu | Carrier foreman | Crew bond with Ur-amas; supplier relationship with Nin-kasi |
| Lu-Nanshe | Court notary | Professional respect for Shuruppak-ilu; rivalry with Utu-mansum |
| Nin-kasi | Brewer | Supply and credit ties with Geme-Inana; precinct connection through Nin-azu |
| Geme-Inana | Trader | Trade contact with Enki-ili; textile trade with Nin-dada |
| Ama-edin | Agricultural household head | Household exchange with Ur-gula; grain obligation to Ur-Nanna |
| Ur-gula | Flock manager | Supplies wool into Nin-dada's textile work |
| Lu-uru | Reed cutter | Materials exchange with Ab-kala |
| Ab-kala | Potter | Supplies through Ur-Nanna's institutional channel |
| Nin-dada | Textile worker | Receives wool from Ur-gula; trades through Geme-Inana |
| Ur-amas | Boat operator | Works with Enlil-kisu's crews and Enki-ili's transport contracts |
| Enki-ili | External trader | Connects Geme-Inana's trade to river transport |
| Nin-azu | Precinct attendant | Social and work tie to Nin-kasi |
| Geme-tur | Player household member | Explicit family tie to Enlil-barni |

Names and personal histories are authored for the game. The world uses period-appropriate places, materials, occupations, and institutional patterns without turning the seed into an archaeological catalogue.

## Places

- Uruk
- Eanna Precinct
- Anu Precinct
- Uruk Agricultural Hinterland
- South Court Storehouse
- North-Bay
- Great Canal Cut
- Susa
- Habuba Kabira

South Court Storehouse and North-Bay remain local playable locations. Susa and Habuba Kabira are external settlements connected to Uruk's exchange network.

## Institutions and groups

**Institutions / networks**
- Eanna Institutional Household
- Anu Precinct Establishment
- River and Overland Exchange

**Households and working groups**
- Agricultural Households
- Pastoral Households
- Craft Workshops
- Transport Crews
- Brewers

These categories are not interchangeable: an institutional household has administrative interests and obligations; a working group describes people whose livelihoods or labor connect them.

## Seeded commodities

Barley, dates, sheep, goats, cattle, fish, beer, wool, textiles, clay, reeds, bitumen, timber, copper, and silver.

The existing `clay_reeds` combined stockpile remains initialized as a compatibility bridge for the current sealed-vessel event and desk UI. New world data also has separate `clay` and `reeds` stockpiles. The existing `labor` pool remains for the current prototype; it is not a claim that people are a commodity.

## Implementation

- `WorldState.people` stores runtime people.
- `PersonEntity.relationships` stores each person's directed ties.
- `WorldState.relationships` stores the corresponding world-level edge list for graph traversal and simulation.
- `WorldState.places`, `institutions`, and `social_groups` hold runtime seed records.
- `UrukSeeder` creates the graph from a campaign seed. It does not mutate shared definition Resources.

The current edges are starting conditions, not a relationship simulation. Trust, obligations, reputation, supply, and institutional behavior still need systems that can change them over time. The next simulation step should consume these records rather than adding more hand-authored NPCs.
