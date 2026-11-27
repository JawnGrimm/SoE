extends SceneTree

var checks := 0
var failures: Array[String] = []

const SaveCodecScript = preload("res://systems/save_codec.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var definitions := DefinitionRegistry.new()
	definitions.load_defaults()
	_check(definitions.get_occupation(&"storehouse_worker") != null, "Registry loads occupation definitions")
	_check(definitions.get_character_template(&"uruk_worker_template") != null, "Registry loads character templates")
	_check(definitions.get_trait(&"resourceful") != null, "Registry loads trait definitions")

	var first := _generate_world(84217, definitions)
	var second := _generate_world(84217, definitions)
	_check(first["people"].size() == 9 and second["people"].size() == 9, "Seeded Tier 2 roster creates three residents in each regional settlement")
	_check(_roster_signature(first) == _roster_signature(second), "Same world seed produces the same names, roles, and skills")
	_check(_all_ids_unique(first["people"]), "Generated people have unique persistent entity IDs")
	_check(_all_locations_valid(first), "Every generated person has a registered place")
	_check(_all_have_occupation_and_traits(first), "Generated people receive valid occupations, initialized skills, and defined traits")

	var world: WorldState = first["world"]
	var before_count := world.people.size()
	var population: PopulationService = first["service"]
	var again := population.generate_people(world, definitions, &"uruk", &"sumerian", &"uruk_storehouse", 3, &"population_test")
	_check(again.size() == 3 and world.people.size() == before_count, "Repeated generation with the same batch key is idempotent")

	var encoded := SaveCodecScript.encode_world(world)
	var decoded := SaveCodecScript.decode_save(encoded)
	var restored: WorldState = decoded.get("world") as WorldState
	var original_generated: PersonEntity = first["people"][0]
	var restored_person := restored.get_person(original_generated.id) if restored != null else null
	_check(bool(decoded.get("success", false)) and restored_person != null, "Generated roster survives save/load")
	_check(restored_person != null and restored_person.location_id == original_generated.location_id and restored_person.template_id == original_generated.template_id and restored_person.occupation_id == original_generated.occupation_id and restored_person.name_provenance == &"constructed" and not restored_person.name_source.is_empty() and restored_person.name_gender != &"", "Save/load preserves generated identity and name provenance")
	_check(restored != null and restored.population_batches.size() == world.population_batches.size() and restored.rng_people.state == world.rng_people.state, "Save/load preserves idempotency batches and people RNG state")

	print("Population Phase A: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _generate_world(seed_value: int, definitions: DefinitionRegistry) -> Dictionary:
	var world := WorldState.new()
	world.set_world_seed(seed_value)
	var player := PersonEntity.new()
	player.id = &"population_test_player"
	player.display_name = "Test Player"
	world.set_player(player)
	for place in definitions.all_places():
		world.places[place.id] = {"name": place.display_name, "era_id": place.era_id}
	var service := PopulationService.new()
	service.load_name_table()
	var people: Array[PersonEntity] = []
	for place_id in [&"uruk", &"nippur", &"umma"]:
		people.append_array(service.generate_people(world, definitions, place_id, &"sumerian", &"uruk_storehouse", 3, &"population_test"))
	return {"world": world, "service": service, "people": people}

func _roster_signature(result: Dictionary) -> Array[String]:
	var signature: Array[String] = []
	for person in result["people"]:
		signature.append("%s|%s|%s|%s" % [person.display_name, person.location_id, person.occupation_id, str(person.skills.levels)])
	return signature

func _all_ids_unique(people: Array) -> bool:
	var seen: Dictionary = {}
	for person in people:
		if seen.has(person.id):
			return false
		seen[person.id] = true
	return true

func _all_locations_valid(result: Dictionary) -> bool:
	var world: WorldState = result["world"]
	for person in result["people"]:
		if person.location_id == &"" or not world.places.has(person.location_id):
			return false
	return true

func _all_have_occupation_and_traits(result: Dictionary) -> bool:
	for person in result["people"]:
		if person.occupation_id == &"" or person.skills.get_level(&"stewardship") < 0 or person.traits.is_empty():
			return false
	return true

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
