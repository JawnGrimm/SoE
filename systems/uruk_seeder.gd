class_name UrukSeeder
extends RefCounted

const PLAYER_ID: StringName = &"player_apprentice"

static func seed_campaign(world: WorldState, seed: int) -> PersonEntity:
	world.set_world_seed(seed)
	world.year = -3200
	world.period = 0
	world.people.clear()
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
	world.people[&"nin_kasi"] = _person(&"nin_kasi", "Nin-kasi", &"brewer", {}, [&"harried", &"devout"])
	world.people[&"geme_inana"] = _person(&"geme_inana", "Geme-Inana", &"trader", {}, [&"patient", &"calculating"])
	world.stockpiles.clear()
	world.stockpiles[&"canal_progress"] = 0
	world.stockpiles[&"barley"] = 450 + world.rng_sim.randi_range(-30, 50)
	world.stockpiles[&"silver"] = 8 + world.rng_sim.randi_range(0, 4)
	world.stockpiles[&"clay_reeds"] = 60 + world.rng_sim.randi_range(-10, 10)
	world.stockpiles[&"labor"] = 25 + world.rng_sim.randi_range(-5, 5)
	# The North-Bay roof is already leaking; each elapsed period spoils one measure of barley.
	world.north_bay_roof_leak_active = true
	world.north_bay_roof_leak_rate = 1
	world.enqueue_form({"form_type": &"grain_levy", "subject_id": &"south_court_storehouse", "urgency": 1, "year": world.year})
	return player

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
