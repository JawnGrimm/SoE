class_name UrukSeeder
extends RefCounted

static func seed_campaign(world: WorldState, world_seed: int, add_player_to_world: bool = true) -> PersonEntity:
	world.set_world_seed(world_seed)
	world.year = -3200
	world.period = 0
	world.people.clear()
	world.places.clear()
	world.institutions.clear()
	world.social_groups.clear()
	world.faction_standings.clear()
	for faction_id in [&"eanna_household", &"boatmens_guild", &"city_garrison", &"council_of_elders", &"agricultural_households"]:
		world.faction_standings[faction_id] = 0
	world.assignments.clear()
	world.pending_forms.clear()
	world.resolved_forms.clear()
	world.event_history.clear()
	world.character_event_history.clear()
	world.hazards.clear()
	world.recent_archetypes.clear()
	world.recent_npc_pairs.clear()
	world.cases_settled = 0
	world.local_path_dockets_settled = 0
	world.epic_summon_pending = false
	world.epic_summon_issued = false
	world.silver_earned = 0
	world.traits_gained.clear()
	world.cedar_desk_log.clear()
	world.era_completion_started = false
	world.epics.clear()
	world._next_form_sequence = 1
	world._next_person_sequence = 1
	world.player_id = &""

	# The original eight remain the center of the first playable slice.
	var player := _person(world.allocate_person_id(), "Enlil-barni", &"apprentice_scribe", {"literacy": 1, "arithmetic": 1, "law": 1}, [])
	player.resources[&"silver"] = 2
	if add_player_to_world:
		world.set_player(player)
	var senior := _person(&"shuruppak_ilu", "Shuruppak-ilu", &"archive_keeper", {"literacy": 4, "arithmetic": 4, "law": 3, "rhetoric": 2, "intrigue": 2, "stewardship": 3}, [&"patient", &"exacting"])
	senior.vulnerabilities[&"patience_remaining"] = 3 + world.rng_people.randi_range(0, 2)
	world.people[senior.id] = senior
	var steward := _person(&"ur_nanna", "Ur-Nanna", &"grain_clerk", {"stewardship": 4, "law": 2, "arithmetic": 3}, [&"cautious", &"weather_watcher"])
	steward.vulnerabilities[&"granary_roof_integrity"] = world.rng_people.randi_range(40, 80)
	world.people[steward.id] = steward
	world.people[&"utu_mansum"] = _person(&"utu_mansum", "Utu-mansum", &"tax_scribe", {"arithmetic": 3, "law": 2, "rhetoric": 1}, [&"tired", &"unbending"])
	var foreman := _person(&"enlil_kisu", "Enlil-kisu", &"carrier_foreman", {"rhetoric": 3, "stewardship": 2}, [&"protective_of_crew", &"practical"])
	foreman.vulnerabilities[&"crew_hunger"] = world.rng_people.randi_range(1, 3)
	world.people[foreman.id] = foreman
	world.people[&"lu_nanshe"] = _person(&"lu_nanshe", "Lu-Nanshe", &"court_notary", {"law": 4, "rhetoric": 3}, [&"deliberate", &"unhurried"])
	world.people[&"nin_kasi"] = _person(&"nin_kasi", "Nin-kasi", &"brewer", {"stewardship": 2}, [&"harried", &"devout"])
	world.people[&"geme_inana"] = _person(&"geme_inana", "Geme-Inana", &"trader", {"arithmetic": 2, "intrigue": 2}, [&"patient", &"calculating"])

	# Nine additional people make the existing economy and offices socially legible.
	world.people[&"ama_edin"] = _person(&"ama_edin", "Ama-edin", &"household_head", {"stewardship": 2, "arithmetic": 1}, [&"resourceful", &"protective"])
	world.people[&"ur_gula"] = _person(&"ur_gula", "Ur-gula", &"flock_manager", {"stewardship": 3}, [&"observant", &"stubborn"])
	world.people[&"lu_uru"] = _person(&"lu_uru", "Lu-uru", &"reed_cutter", {"stewardship": 2}, [&"patient", &"independent"])
	world.people[&"ab_kala"] = _person(&"ab_kala", "Ab-kala", &"potter", {"stewardship": 3, "arithmetic": 1}, [&"proud_of_work", &"impatient"])
	world.people[&"nin_dada"] = _person(&"nin_dada", "Nin-dada", &"textile_worker", {"stewardship": 2}, [&"meticulous", &"quiet"])
	world.people[&"ur_amas"] = _person(&"ur_amas", "Ur-amas", &"boat_operator", {"rhetoric": 2, "stewardship": 2}, [&"sociable", &"risk_tolerant"])
	world.people[&"enki_ili"] = _person(&"enki_ili", "Enki-ili", &"external_trader", {"arithmetic": 3, "intrigue": 2}, [&"well_traveled", &"guarded"])
	world.people[&"nin_azu"] = _person(&"nin_azu", "Nin-azu", &"precinct_attendant", {"literacy": 2, "rhetoric": 2}, [&"devout", &"ambitious"])
	world.people[&"geme_tur"] = _person(&"geme_tur", "Geme-tur", &"player_household", {"stewardship": 2}, [&"practical", &"blunt"])

	_seed_places(world)
	_seed_institutions_and_groups(world)
	_seed_relationships(world)
	if add_player_to_world:
		attach_player(world, player)

	world.stockpiles.clear()
	world.stockpiles[&"canal_progress"] = 0
	world.stockpiles[&"barley"] = 450 + world.rng_sim.randi_range(-30, 50)
	world.stockpiles[&"dates"] = 90 + world.rng_sim.randi_range(-10, 15)
	world.stockpiles[&"sheep"] = 34 + world.rng_sim.randi_range(-4, 6)
	world.stockpiles[&"goats"] = 18 + world.rng_sim.randi_range(-3, 4)
	world.stockpiles[&"cattle"] = 7 + world.rng_sim.randi_range(-1, 2)
	world.stockpiles[&"fish"] = 24 + world.rng_sim.randi_range(-5, 5)
	world.stockpiles[&"beer"] = 36 + world.rng_sim.randi_range(-6, 8)
	world.stockpiles[&"wool"] = 22 + world.rng_sim.randi_range(-4, 6)
	world.stockpiles[&"textiles"] = 12 + world.rng_sim.randi_range(-2, 4)
	world.stockpiles[&"clay"] = 80 + world.rng_sim.randi_range(-10, 15)
	world.stockpiles[&"reeds"] = 55 + world.rng_sim.randi_range(-8, 12)
	world.stockpiles[&"bitumen"] = 16 + world.rng_sim.randi_range(-3, 4)
	world.stockpiles[&"timber"] = 8 + world.rng_sim.randi_range(-2, 3)
	world.stockpiles[&"copper"] = 5 + world.rng_sim.randi_range(-1, 2)
	world.stockpiles[&"silver"] = 8 + world.rng_sim.randi_range(0, 4)
	# Keep the old combined key until the first-slice UI and sealed-vessel event migrate.
	world.stockpiles[&"clay_reeds"] = world.get_resource(&"clay") + world.get_resource(&"reeds")
	world.stockpiles[&"labor"] = 25 + world.rng_sim.randi_range(-5, 5)
	# All compound commodities belong to the Eanna institution, not the world
	# or the apprentice's personal purse.
	var eanna: Dictionary = world.institutions.get(&"eanna_household", {})
	var eanna_stockpiles := world.stockpiles.duplicate(true)
	eanna_stockpiles.erase(&"canal_progress")
	eanna["stockpiles"] = eanna_stockpiles
	world.institutions[&"eanna_household"] = eanna
	world.stockpiles.clear()
	world.stockpiles[&"canal_progress"] = 0

	# The North-Bay roof is already leaking; each elapsed period spoils one measure of barley.
	world.hazards.append({"id": &"roof_leak", "place_id": &"north_bay", "resource": &"barley", "rate": 1, "total_lost": 0, "active": true})
	world.enqueue_form({"form_type": &"grain_levy", "subject_id": &"south_court_storehouse", "urgency": 1, "year": world.year})
	return player

static func attach_player(world: WorldState, player: PersonEntity) -> void:
	## Adds the Era I household and roster context after character confirmation.
	## Safe to call more than once; character creation resolution stays era-agnostic.
	if world == null or player == null or player.id == &"":
		push_warning("UrukSeeder.attach_player: world and a valid player are required")
		return
	if world.people.has(player.id) and world.get_person(player.id) != player:
		push_warning("UrukSeeder.attach_player: another person already uses %s" % player.id)
		return
	if not world.set_player(player):
		return

	var household: Dictionary = world.institutions.get(&"eanna_household", {})
	if not household.is_empty():
		var members: Array = household.get("members", []).duplicate()
		if not members.has(player.id):
			members.append(player.id)
		household["members"] = members
		world.institutions[&"eanna_household"] = household

	for person in world.people.values():
		if person == player:
			continue
		person.set_opinion(world.player_id, 5 if person.id == &"shuruppak_ilu" else 0)

	# Restore the baseline mentor and household ties omitted while the player
	# was held outside WorldState during the creation draft.
	_link(world, &"shuruppak_ilu", world.player_id, &"mentor", 7, 8)
	_link(world, &"geme_tur", world.player_id, &"family", 8, 9)

static func _seed_places(world: WorldState) -> void:
	# Keep local Eanna work areas, while canonical settlements come from
	# immutable PlaceDef resources so dockets can share the same geography.
	world.places = {
		&"eanna_precinct": {"name": "Eanna Precinct", "kind": &"institutional_precinct", "parent": &"uruk"},
		&"anu_precinct": {"name": "Anu Precinct", "kind": &"cultic_precinct", "parent": &"uruk"},
		&"agricultural_hinterland": {"name": "Uruk Agricultural Hinterland", "kind": &"productive_land", "parent": &"uruk"},
		&"south_court_storehouse": {"name": "South Court Storehouse", "kind": &"storehouse", "parent": &"eanna_precinct"},
		&"north_bay": {"name": "North-Bay", "kind": &"work_area", "parent": &"eanna_precinct"},
		&"great_canal_cut": {"name": "Great Canal Cut", "kind": &"canal_worksite", "parent": &"agricultural_hinterland"},
		&"djebel_aruda": {"name": "Djebel Aruda", "kind": &"uruk_related_settlement", "region": &"upper_euphrates", "connected_to": [&"habuba_kabira"]}
	}
	var place_ids: Array[String] = ["uruk", "umma", "nippur", "ur", "habuba_kabira", "hacinebi", "susa"]
	for place_id in place_ids:
		var resource_path := "res://data/places/%s.tres" % place_id
		var definition := ResourceLoader.load(resource_path) as PlaceDef
		if definition == null or not definition.is_valid():
			push_warning("UrukSeeder: failed to load canonical place '%s'" % resource_path)
			continue
		world.places[definition.id] = {
			"name": definition.display_name,
			"kind": definition.place_type,
			"region": definition.region,
			"political_relation": definition.political_relation,
			"exports": definition.exports.duplicate(),
			"imports": definition.imports.duplicate(),
			"connected_to": definition.connected_to.duplicate(),
			"era_id": definition.era_id
		}
static func _seed_institutions_and_groups(world: WorldState) -> void:
	var eanna_members: Array[StringName] = [&"shuruppak_ilu", &"ur_nanna", &"utu_mansum", &"enlil_kisu", &"lu_nanshe"]
	world.institutions = {
		&"eanna_household": {"name": "Eanna Institutional Household", "kind": &"institutional_household", "place_id": &"eanna_precinct", "members": eanna_members, "interests": [&"grain", &"labor", &"storage", &"canal_work"]},
		&"anu_establishment": {"name": "Anu Precinct Establishment", "kind": &"cultic_establishment", "place_id": &"anu_precinct", "members": [&"nin_azu", &"nin_kasi"], "interests": [&"offerings", &"beer", &"prestige"]},
		&"exchange_network": {"name": "River and Overland Exchange", "kind": &"exchange_network", "place_id": &"uruk", "members": [&"geme_inana", &"enki_ili", &"ur_amas"], "interests": [&"transport", &"materials", &"exchange"]}
	}
	world.social_groups = {
		&"agricultural_households": {"name": "Agricultural Households", "kind": &"household_group", "place_id": &"agricultural_hinterland", "members": [&"ama_edin", &"geme_tur"], "resources": [&"barley", &"dates"]},
		&"pastoral_households": {"name": "Pastoral Households", "kind": &"household_group", "place_id": &"agricultural_hinterland", "members": [&"ur_gula"], "resources": [&"sheep", &"goats", &"wool"]},
		&"craft_workshops": {"name": "Craft Workshops", "kind": &"workshop_group", "place_id": &"uruk", "members": [&"lu_uru", &"ab_kala", &"nin_dada"], "resources": [&"clay", &"reeds", &"bitumen", &"textiles"]},
		&"transport_crews": {"name": "Transport Crews", "kind": &"work_group", "place_id": &"uruk", "members": [&"enlil_kisu", &"ur_amas"], "resources": [&"labor", &"barley", &"beer"]},
		&"brewers": {"name": "Brewers", "kind": &"craft_group", "place_id": &"uruk", "members": [&"nin_kasi"], "resources": [&"barley", &"beer"]}
	}


static func _seed_relationships(world: WorldState) -> void:
	## Seeds authored NPC-to-NPC ties. Player-relative ties are added only when
	## the character is confirmed through attach_player().

	_link(world, &"ur_nanna", &"shuruppak_ilu", &"professional_respect", 4, 6)
	_link(world, &"ur_nanna", &"enlil_kisu", &"resource_dependency", 3, 5)
	_link(world, &"enlil_kisu", &"ur_amas", &"crew_bond", 6, 7)
	_link(world, &"enlil_kisu", &"nin_kasi", &"supplier_customer", 2, 5)
	_link(world, &"utu_mansum", &"lu_nanshe", &"professional_rivalry", -2, 4)
	_link(world, &"lu_nanshe", &"shuruppak_ilu", &"professional_respect", 3, 6)
	_link(world, &"nin_kasi", &"geme_inana", &"credit_and_supply", 4, 5)
	_link(world, &"geme_inana", &"enki_ili", &"trade_contact", 5, 5)
	_link(world, &"enki_ili", &"ur_amas", &"transport_contract", 3, 6)
	_link(world, &"ama_edin", &"ur_gula", &"household_exchange", 3, 5)
	_link(world, &"ama_edin", &"ur_nanna", &"grain_obligation", -1, 3)
	_link(world, &"ur_gula", &"nin_dada", &"wool_supply", 4, 6)
	_link(world, &"lu_uru", &"ab_kala", &"materials_exchange", 3, 5)
	_link(world, &"ab_kala", &"ur_nanna", &"institutional_supplier", 2, 5)
	_link(world, &"nin_dada", &"geme_inana", &"textile_trade", 3, 5)
	_link(world, &"nin_azu", &"nin_kasi", &"cultic_and_workplace_tie", 2, 5)
	_link(world, &"geme_tur", &"shuruppak_ilu", &"household_reputation", 1, 4)
	_link(world, &"nin_kasi", &"ama_edin", &"brewery_household_supply", 2, 4)

static func _link(world: WorldState, source_id: StringName, target_id: StringName, relation_type: StringName, strength: int, trust: int) -> void:
	var source := world.get_person(source_id)
	var target := world.get_person(target_id)
	if source == null or target == null:
		push_warning("UrukSeeder: relationship references missing person %s -> %s" % [source_id, target_id])
		return
	var tie: Dictionary = source.relationships.get(target_id, {})
	tie["type"] = relation_type
	tie["strength"] = strength
	tie["trust"] = trust
	if not tie.has("opinion"):
		tie["opinion"] = 0
	if not tie.has("reasons"):
		tie["reasons"] = []
	source.relationships[target_id] = tie

static func _person(id: StringName, display_name: String, office: StringName, values: Dictionary, person_traits: Array) -> PersonEntity:
	var person := PersonEntity.new()
	person.id = id
	person.display_name = display_name
	person.office_id = office
	person.traits.assign(person_traits)
	for skill in person.skills.levels.keys():
		person.skills.levels[skill] = int(values.get(String(skill), 0))
	return person
