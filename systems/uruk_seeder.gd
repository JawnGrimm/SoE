class_name UrukSeeder
extends RefCounted

const PLAYER_ID: StringName = &"player_apprentice"

static func seed_campaign(world: WorldState, seed: int) -> PersonEntity:
	world.set_world_seed(seed)
	world.year = -3200
	world.period = 0
	world.people.clear()
	world.places.clear()
	world.institutions.clear()
	world.social_groups.clear()
	world.relationships.clear()
	world.assignments.clear()
	world.pending_forms.clear()
	world.resolved_forms.clear()
	world.event_history.clear()
	world.character_event_history.clear()
	world.hazards.clear()
	world._next_form_sequence = 1

	# The original eight remain the center of the first playable slice.
	var player := _person(&"player_apprentice", "Enlil-barni", &"apprentice_scribe", {"literacy": 1, "arithmetic": 1, "law": 1}, [])
	world.people[player.id] = player
	var senior := _person(&"shuruppak_ilu", "Shuruppak-ilu", &"archive_keeper", {"literacy": 4, "arithmetic": 4, "law": 3, "rhetoric": 2, "intrigue": 2, "stewardship": 3}, [&"patient", &"exacting"])
	senior.opinions[PLAYER_ID] = 5
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

	# The North-Bay roof is already leaking; each elapsed period spoils one measure of barley.
	world.hazards.append({"id": &"roof_leak", "place_id": &"north_bay", "resource": &"barley", "rate": 1, "total_lost": 0, "active": true})
	world.enqueue_form({"form_type": &"grain_levy", "subject_id": &"south_court_storehouse", "urgency": 1, "year": world.year})
	return player

static func _seed_places(world: WorldState) -> void:
	world.places = {
		&"uruk": {"name": "Uruk", "kind": &"city", "region": &"southern_mesopotamia", "connected_to": [&"eanna_precinct", &"anu_precinct", &"agricultural_hinterland"]},
		&"eanna_precinct": {"name": "Eanna Precinct", "kind": &"institutional_precinct", "parent": &"uruk"},
		&"anu_precinct": {"name": "Anu Precinct", "kind": &"cultic_precinct", "parent": &"uruk"},
		&"agricultural_hinterland": {"name": "Uruk Agricultural Hinterland", "kind": &"productive_land", "parent": &"uruk"},
		&"south_court_storehouse": {"name": "South Court Storehouse", "kind": &"storehouse", "parent": &"eanna_precinct"},
		&"north_bay": {"name": "North-Bay", "kind": &"work_area", "parent": &"eanna_precinct"},
		&"great_canal_cut": {"name": "Great Canal Cut", "kind": &"canal_worksite", "parent": &"agricultural_hinterland"},
		&"susa": {"name": "Susa", "kind": &"external_settlement", "region": &"susiana", "connected_to": [&"uruk"]},
		&"habuba_kabira": {"name": "Habuba Kabira", "kind": &"external_settlement", "region": &"upper_euphrates", "connected_to": [&"uruk"]}
	}

static func _seed_institutions_and_groups(world: WorldState) -> void:
	world.institutions = {
		&"eanna_household": {"name": "Eanna Institutional Household", "kind": &"institutional_household", "place_id": &"eanna_precinct", "members": [&"shuruppak_ilu", &"ur_nanna", &"utu_mansum", &"enlil_kisu", &"lu_nanshe", &"player_apprentice"], "interests": [&"grain", &"labor", &"storage", &"canal_work"]},
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
	_link(world, &"shuruppak_ilu", &"player_apprentice", &"mentor", 7, 8)
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
	_link(world, &"geme_tur", &"player_apprentice", &"family", 8, 9)
	_link(world, &"geme_tur", &"shuruppak_ilu", &"household_reputation", 1, 4)

static func _link(world: WorldState, source_id: StringName, target_id: StringName, relation_type: StringName, strength: int, trust: int) -> void:
	var source := world.get_person(source_id)
	var target := world.get_person(target_id)
	if source == null or target == null:
		push_warning("UrukSeeder: relationship references missing person %s -> %s" % [source_id, target_id])
		return
	var tie := {"type": relation_type, "strength": strength, "trust": trust}
	source.relationships[target_id] = tie
	world.relationships.append({"source_id": source_id, "target_id": target_id, "type": relation_type, "strength": strength, "trust": trust})

static func _person(id: StringName, display_name: String, office: StringName, values: Dictionary, person_traits: Array) -> PersonEntity:
	var person := PersonEntity.new()
	person.id = id
	person.display_name = display_name
	person.office_id = office
	if id != PLAYER_ID:
		person.opinions[PLAYER_ID] = 0
	person.traits.assign(person_traits)
	for skill in person.skills.levels.keys():
		person.skills.levels[skill] = int(values.get(String(skill), 0))
	return person
