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
			"year": world.year, "period": world.period, "master_seed": world.master_seed,
			"rng": {
				"narrative_seed": String(world.rng_narrative.seed), "narrative_state": String(world.rng_narrative.state),
				"simulation_seed": String(world.rng_sim.seed), "simulation_state": String(world.rng_sim.state),
				"people_seed": String(world.rng_people.seed), "people_state": String(world.rng_people.state),
			},
			"stockpiles": _json_safe(world.stockpiles), "epics": _json_safe(world.epics),
			"world_flags": _json_safe(world.world_flags), "pending_forms": _json_safe(world.pending_forms),
			"resolved_forms": _json_safe(world.resolved_forms), "event_history": _json_safe(world.event_history),
			"character_event_history": _json_safe(world.character_event_history), "people": people_data,
			"player_id": String(world.player_id), "next_person_sequence": world._next_person_sequence,
			"places": _json_safe(world.places), "institutions": _json_safe(world.institutions),
			"social_groups": _json_safe(world.social_groups), "assignments": _json_safe(world.assignments),
			"hazards": _json_safe(world.hazards), "recent_archetypes": _json_safe(world.recent_archetypes),
			"recent_npc_pairs": _json_safe(world.recent_npc_pairs), "cases_settled": world.cases_settled,
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
	world.world_flags = _name_int_map(data.get("world_flags", {}))
	world.pending_forms = _dictionary_array(data.get("pending_forms", []))
	world.resolved_forms = _dictionary_array(data.get("resolved_forms", []))
	world.event_history = _dictionary_array(data.get("event_history", []))
	world.character_event_history = _name_array_map(data.get("character_event_history", {}))
	world.people.clear()
	var people_data: Dictionary = data.get("people", {})
	for key in people_data:
		var person := _person_from_data(people_data[key])
		if person != null and person.id != &"":
			world.people[person.id] = person
	world.player_id = StringName(data.get("player_id", ""))
	world._next_person_sequence = maxi(1, int(data.get("next_person_sequence", 1)))
	world.places = _name_dictionary_map(data.get("places", {}))
	world.institutions = _name_dictionary_map(data.get("institutions", {}))
	world.social_groups = _name_dictionary_map(data.get("social_groups", {}))
	world.assignments = _name_dictionary_map(data.get("assignments", {}))
	world.hazards = _dictionary_array(data.get("hazards", []))
	world.recent_archetypes = _name_array(data.get("recent_archetypes", []))
	world.recent_npc_pairs = _string_array(data.get("recent_npc_pairs", []))
	world.cases_settled = int(data.get("cases_settled", 0))
	world.silver_earned = int(data.get("silver_earned", 0))
	world.traits_gained = _name_array(data.get("traits_gained", []))
	world.cedar_desk_log = _dictionary_array(data.get("cedar_desk_log", []))
	world.era_completion_started = bool(data.get("era_completion_started", false))
	world._next_form_sequence = maxi(1, int(data.get("next_form_sequence", 1)))
	return world

static func _person_to_data(person: PersonEntity) -> Dictionary:
	return {
		"id": String(person.id), "display_name": person.display_name,
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

static func _name_int_map(source: Variant) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if source is Dictionary:
		for key in source:
			result[StringName(key)] = int(source[key])
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
