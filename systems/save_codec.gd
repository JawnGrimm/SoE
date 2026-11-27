class_name SaveCodec
extends RefCounted

const FORMAT_ID := "scribe_of_eras"
const CURRENT_VERSION := 1

static func encode_world(world: WorldState, session: Dictionary = {}) -> Dictionary:
	if world == null:
		return {}
	var people_data: Dictionary = {}
	for person_id in world.people:
		var person: PersonEntity = world.people[person_id]
		if person != null:
			people_data[String(person_id)] = _person_to_data(person)
	return {
		"format": FORMAT_ID, "version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true, true),
		"world": {
			"year": world.year, "period": world.period, "current_location_id": String(world.current_location_id), "master_seed": world.master_seed,
			"rng": {
				"narrative_seed": str(world.rng_narrative.seed), "narrative_state": str(world.rng_narrative.state),
				"simulation_seed": str(world.rng_sim.seed), "simulation_state": str(world.rng_sim.state),
				"people_seed": str(world.rng_people.seed), "people_state": str(world.rng_people.state),
			},
			"stockpiles": _json_safe(world.stockpiles), "epics": _json_safe(world.epics),
			"faction_standings": _json_safe(world.faction_standings),
			"world_flags": _json_safe(world.world_flags), "routes": _json_safe(world.routes), "pending_forms": _json_safe(world.pending_forms),
			"resolved_forms": _json_safe(world.resolved_forms), "event_history": _json_safe(world.event_history),
			"character_event_history": _json_safe(world.character_event_history), "people": people_data,
			"population_batches": _json_safe(world.population_batches),
			"player_id": String(world.player_id), "next_person_sequence": world._next_person_sequence,
			"places": _json_safe(world.places), "institutions": _json_safe(world.institutions),
			"social_groups": _json_safe(world.social_groups), "assignments": _json_safe(world.assignments),
			"hazards": _json_safe(world.hazards), "recent_archetypes": _json_safe(world.recent_archetypes),
			"recent_npc_pairs": _json_safe(world.recent_npc_pairs), "cases_settled": world.cases_settled,
			"local_path_dockets_settled": world.local_path_dockets_settled,
			"epic_summon_pending": world.epic_summon_pending, "epic_summon_issued": world.epic_summon_issued,
			"silver_earned": world.silver_earned, "traits_gained": _json_safe(world.traits_gained),
			"cedar_desk_log": _json_safe(world.cedar_desk_log),
			"era_completion_started": world.era_completion_started,
			"next_form_sequence": world._next_form_sequence,
		},
		"session": _json_safe(session),
	}

static func decode_save(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"success": false, "error": "Save data is not a JSON object."}
	if String(payload.get("format", "")) != FORMAT_ID:
		return {"success": false, "error": "This file is not a Scribe of Eras save."}
	var version := int(payload.get("version", 0))
	if version != CURRENT_VERSION:
		return {"success": false, "error": "Unsupported save version %d. This build supports version %d." % [version, CURRENT_VERSION]}
	var data: Variant = payload.get("world", null)
	if not (data is Dictionary):
		return {"success": false, "error": "Save is missing its world snapshot."}
	var world := _world_from_data(data)
	if world.get_player() == null:
		return {"success": false, "error": "Save has no valid current player."}
	var session: Variant = payload.get("session", {})
	if not (session is Dictionary):
		session = {}
	return {"success": true, "world": world, "session": session.duplicate(true)}

static func _world_from_data(data: Dictionary) -> WorldState:
	var world := WorldState.new()
	world.year = int(data.get("year", -3200))
	world.period = clampi(int(data.get("period", 0)), 0, 11)
	world.current_location_id = StringName(data.get("current_location_id", "uruk"))
	world.master_seed = int(data.get("master_seed", 0))
	var rng: Dictionary = data.get("rng", {})
	world.rng_narrative.seed = int(String(rng.get("narrative_seed", world.master_seed)))
	world.rng_narrative.state = int(String(rng.get("narrative_state", world.rng_narrative.seed)))
	world.rng_sim.seed = int(String(rng.get("simulation_seed", world.master_seed)))
	world.rng_sim.state = int(String(rng.get("simulation_state", world.rng_sim.seed)))
	world.rng_people.seed = int(String(rng.get("people_seed", world.master_seed)))
	world.rng_people.state = int(String(rng.get("people_state", world.rng_people.seed)))
	world.stockpiles = _name_int_map(data.get("stockpiles", {}))
	world.epics = _name_dictionary_map(data.get("epics", {}))
	world.faction_standings = _name_int_map(data.get("faction_standings", {}))
	world.world_flags = _name_int_map(data.get("world_flags", {}))
	world.routes = _name_dictionary_map(data.get("routes", {}))
	world.pending_forms = _dictionary_array(data.get("pending_forms", []))
	world.resolved_forms = _dictionary_array(data.get("resolved_forms", []))
	world.event_history = _dictionary_array(data.get("event_history", []))
	world.character_event_history = _name_array_map(data.get("character_event_history", {}))
	world.people.clear()
	world.population_batches = _name_array_map(data.get("population_batches", {}))
	var people_data: Dictionary = data.get("people", {})
	for key in people_data:
		var person := _person_from_data(people_data[key])
		if person != null and person.id != &"":
			world.people[person.id] = person
	world.player_id = StringName(data.get("player_id", ""))
	world._next_person_sequence = maxi(1, int(data.get("next_person_sequence", 1)))
	world.places = _name_dictionary_map(data.get("places", {}))
	world.institutions = _name_dictionary_map(data.get("institutions", {}))
	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		institution["place_id"] = StringName(institution.get("place_id", ""))
		institution["era_id"] = StringName(institution.get("era_id", ""))
		institution["members"] = _name_array(institution.get("members", []))
		institution["interests"] = _name_array(institution.get("interests", []))
		institution["staffed_offices"] = _name_array(institution.get("staffed_offices", []))
		institution["stockpiles"] = _name_int_map(institution.get("stockpiles", {}))
		institution["periodic_deltas"] = _name_int_map(institution.get("periodic_deltas", {}))
		institution["harvest_deltas"] = _name_int_map(institution.get("harvest_deltas", {}))
		institution["pressure_thresholds"] = _name_int_map(institution.get("pressure_thresholds", {}))
		institution["offices"] = _name_name_map(institution.get("offices", {}))
		world.institutions[institution_id] = institution
	world.social_groups = _name_dictionary_map(data.get("social_groups", {}))
	world.assignments = _name_dictionary_map(data.get("assignments", {}))
	for assignment_id in world.assignments.keys():
		var assignment: Dictionary = world.assignments[assignment_id]
		for field in [&"kind", &"source_id", &"employer_id", &"actor_id", &"path_id"]:
			assignment[field] = StringName(assignment.get(field, ""))
		assignment["actions"] = _name_key_map(assignment.get("actions", {}))
		assignment["evidence"] = _name_key_map(assignment.get("evidence", {}))
		world.assignments[assignment_id] = assignment
	world.hazards = _dictionary_array(data.get("hazards", []))
	world.recent_archetypes = _name_array(data.get("recent_archetypes", []))
	world.recent_npc_pairs = _string_array(data.get("recent_npc_pairs", []))
	world.cases_settled = int(data.get("cases_settled", 0))
	world.local_path_dockets_settled = maxi(0, int(data.get("local_path_dockets_settled", 0)))
	world.faction_standings = _name_int_map(data.get("faction_standings", {}))
	world.epic_summon_pending = bool(data.get("epic_summon_pending", false))
	world.epic_summon_issued = bool(data.get("epic_summon_issued", false))
	world.silver_earned = int(data.get("silver_earned", 0))
	world.traits_gained = _name_array(data.get("traits_gained", []))
	world.cedar_desk_log = _dictionary_array(data.get("cedar_desk_log", []))
	world.era_completion_started = bool(data.get("era_completion_started", false))
	world._next_form_sequence = maxi(1, int(data.get("next_form_sequence", 1)))
	return world

static func _person_to_data(person: PersonEntity) -> Dictionary:
	return {
		"id": String(person.id), "display_name": person.display_name,
		"pronouns": String(person.pronouns), "institutional_designation": person.institutional_designation,
		"location_id": String(person.location_id), "template_id": String(person.template_id),
		"occupation_id": String(person.occupation_id), "generation_source": String(person.generation_source),
		"generation_key": String(person.generation_key), "name_provenance": String(person.name_provenance),
		"name_source": person.name_source, "name_gender": String(person.name_gender),
		"skills": {"levels": _json_safe(person.skills.levels), "xp": _json_safe(person.skills.xp)},
		"office_id": String(person.office_id), "traits": _json_safe(person.traits),
		"vulnerabilities": _json_safe(person.vulnerabilities), "flags": _json_safe(person.flags),
		"memory": _json_safe(person.memory), "relationships": _json_safe(person.relationships),
		"resources": _json_safe(person.resources), "liege_id": String(person.liege_id),
		"spouse_id": String(person.spouse_id), "rival_id": String(person.rival_id),
	}

static func _person_from_data(data: Variant) -> PersonEntity:
	if not (data is Dictionary):
		return null
	var person := PersonEntity.new()
	person.id = StringName(data.get("id", ""))
	person.display_name = String(data.get("display_name", ""))
	person.pronouns = StringName(data.get("pronouns", ""))
	person.institutional_designation = String(data.get("institutional_designation", ""))
	person.location_id = StringName(data.get("location_id", ""))
	person.template_id = StringName(data.get("template_id", ""))
	person.occupation_id = StringName(data.get("occupation_id", ""))
	person.generation_source = StringName(data.get("generation_source", ""))
	person.generation_key = StringName(data.get("generation_key", ""))
	person.name_provenance = StringName(data.get("name_provenance", ""))
	person.name_source = String(data.get("name_source", ""))
	person.name_gender = StringName(data.get("name_gender", ""))
	person.office_id = StringName(data.get("office_id", ""))
	person.traits = _name_array(data.get("traits", []))
	person.vulnerabilities = _name_int_map(data.get("vulnerabilities", {}))
	person.flags = _name_int_map(data.get("flags", {}))
	person.memory = _dictionary_array(data.get("memory", []))
	person.relationships = _name_dictionary_map(data.get("relationships", {}))
	person.resources = _name_int_map(data.get("resources", {}))
	person.liege_id = StringName(data.get("liege_id", ""))
	person.spouse_id = StringName(data.get("spouse_id", ""))
	person.rival_id = StringName(data.get("rival_id", ""))
	var skills: Dictionary = data.get("skills", {})
	person.skills.levels = _name_int_map(skills.get("levels", {}))
	person.skills.xp = _name_int_map(skills.get("xp", {}))
	return person

static func _json_safe(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[String(key)] = _json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_json_safe(item))
		return result
	return value

static func _name_key_map(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		for key in source:
			result[StringName(key)] = source[key]
	return result

static func _name_int_map(source: Variant) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if source is Dictionary:
		for key in source:
			result[StringName(key)] = int(source[key])
	return result

static func _name_name_map(source: Variant) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	if source is Dictionary:
		for key in source:
			result[StringName(key)] = StringName(source[key])
	return result

static func _name_dictionary_map(source: Variant) -> Dictionary[StringName, Dictionary]:
	var result: Dictionary[StringName, Dictionary] = {}
	if source is Dictionary:
		for key in source:
			if source[key] is Dictionary:
				result[StringName(key)] = source[key].duplicate(true)
	return result

static func _name_array_map(source: Variant) -> Dictionary[StringName, Array]:
	var result: Dictionary[StringName, Array] = {}
	if source is Dictionary:
		for key in source:
			if source[key] is Array:
				result[StringName(key)] = source[key].duplicate(true)
	return result

static func _dictionary_array(source: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source is Array:
		for item in source:
			if item is Dictionary:
				result.append(item.duplicate(true))
	return result

static func _name_array(source: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if source is Array:
		for item in source:
			result.append(StringName(item))
	return result

static func _string_array(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if source is Array:
		for item in source:
			result.append(String(item))
	return result
