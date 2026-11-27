class_name WorldState
extends RefCounted

const PERIODS_PER_YEAR := 12
const DEFAULT_EPIC_STAGE_PCTS: Array[int] = [0, 25, 50, 75]

func ensure_epic_review_state(epic_id: StringName, epic_def: EpicDef = null) -> void:
	if not epics.has(epic_id):
		return
	var entry: Dictionary = epics[epic_id]
	var target := maxi(1, int(entry.get("target", epic_def.target if epic_def != null else 100)))
	var progress := int(entry.get("progress", 0))
	var stage := get_epic_stage_index(progress, target, epic_def)
	if not entry.has("review_pending"):
		entry["review_pending"] = bool(entry.get("active", false)) and not bool(entry.get("completed", false))
	if not entry.has("review_reason"):
		entry["review_reason"] = "project_opened" if stage == 0 else "stage_reached"
	if not entry.has("review_summary"):
		entry["review_summary"] = "Initial survey, labor tally, and work charter."
	if not entry.has("active_problem"):
		entry["active_problem"] = ""
	if not entry.has("last_problem_key"):
		entry["last_problem_key"] = ""
	if not entry.has("stalled"):
		entry["stalled"] = false
	if not entry.has("review_stage"):
		entry["review_stage"] = stage
	if not entry.has("reviewed_stage"):
		entry["reviewed_stage"] = -1
	if not entry.has("last_reviewed_period"):
		entry["last_reviewed_period"] = -1
	if epic_def != null:
		entry["review_stage_label"] = get_epic_stage_label(stage, epic_def)
	epics[epic_id] = entry

func get_epic_stage_index(progress: int, target: int, epic_def: EpicDef = null) -> int:
	var safe_target := maxi(1, target)
	if epic_def != null and not epic_def.stages.is_empty():
		var custom_stage := 0
		for i in range(epic_def.stages.size()):
			if progress >= int(epic_def.stages[i].get("threshold", 0)):
				custom_stage = i
		return custom_stage
	var pct := int(floor(float(progress) / float(safe_target) * 100.0))
	var resolved := 0
	for i in range(DEFAULT_EPIC_STAGE_PCTS.size()):
		if pct >= DEFAULT_EPIC_STAGE_PCTS[i]:
			resolved = i
	return resolved

func get_epic_stage_label(stage_index: int, epic_def: EpicDef = null) -> String:
	if epic_def != null and stage_index >= 0 and stage_index < epic_def.stages.size():
		var custom_title := str(epic_def.stages[stage_index].get("title", "")).strip_edges()
		if not custom_title.is_empty():
			return custom_title
	match stage_index:
		0: return "Charter & Survey"
		1: return "Excavation & Earthworks"
		2: return "Channel Cut & Revetment"
		3: return "Weir & Headgate Masonry"
		_: return "Stage %d" % (stage_index + 1)

func open_epic_review(epic_id: StringName, reason: String, summary: String, stage_index: int = -1, epic_def: EpicDef = null) -> bool:
	if not epics.has(epic_id):
		return false
	ensure_epic_review_state(epic_id, epic_def)
	var entry: Dictionary = epics[epic_id]
	if not bool(entry.get("active", false)) or bool(entry.get("completed", false)):
		return false
	var target := maxi(1, int(entry.get("target", 100)))
	var resolved_stage := stage_index if stage_index >= 0 else get_epic_stage_index(int(entry.get("progress", 0)), target, epic_def)
	if bool(entry.get("review_pending", false)):
		if reason != "stage_reached" and str(entry.get("review_reason", "")) == "stage_reached":
			entry["review_reason"] = reason
			entry["review_summary"] = summary
			entry["review_stage"] = resolved_stage
			entry["review_stage_label"] = get_epic_stage_label(resolved_stage, epic_def)
			epics[epic_id] = entry
			return true
		return false
	entry["review_pending"] = true
	entry["review_reason"] = reason
	entry["review_summary"] = summary
	entry["review_stage"] = resolved_stage
	entry["review_stage_label"] = get_epic_stage_label(resolved_stage, epic_def)
	epics[epic_id] = entry
	return true

func resolve_epic_review(epic_id: StringName, epic_def: EpicDef = null) -> void:
	if not epics.has(epic_id):
		return
	ensure_epic_review_state(epic_id, epic_def)
	var entry: Dictionary = epics[epic_id]
	var target := maxi(1, int(entry.get("target", 100)))
	var stage := int(entry.get("review_stage", get_epic_stage_index(int(entry.get("progress", 0)), target, epic_def)))
	entry["reviewed_stage"] = maxi(int(entry.get("reviewed_stage", -1)), stage)
	entry["review_stage"] = stage
	entry["review_pending"] = false
	entry["review_reason"] = ""
	entry["review_summary"] = ""
	entry["last_reviewed_period"] = current_period_index()
	epics[epic_id] = entry



var year: int = 1200
var period: int = 0
var current_location_id: StringName = &"uruk"
var master_seed: int = 0
var rng_narrative := RandomNumberGenerator.new()
var rng_sim := RandomNumberGenerator.new()
var rng_people := RandomNumberGenerator.new()
var stockpiles: Dictionary[StringName, int] = {}
var epics: Dictionary[StringName, Dictionary] = {}
var world_flags: Dictionary[StringName, int] = {}
var routes: Dictionary[StringName, Dictionary] = {}
var pending_forms: Array[Dictionary] = []
var resolved_forms: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var character_event_history: Dictionary[StringName, Array] = {}
var people: Dictionary[StringName, PersonEntity] = {}
# Generation batch keys prevent repeated visits/seeding from duplicating Tier 2 residents.
var population_batches: Dictionary[StringName, Array] = {}
var player_id: StringName = &""
var _next_person_sequence: int = 1
# Seeded world graph. These are runtime records, not shared definition Resources.
var places: Dictionary[StringName, Dictionary] = {}
var institutions: Dictionary[StringName, Dictionary] = {}
var social_groups: Dictionary[StringName, Dictionary] = {}
var assignments: Dictionary[StringName, Dictionary] = {}
var hazards: Array[Dictionary] = []
var recent_archetypes: Array[StringName] = []
var recent_npc_pairs: Array[String] = []
var cases_settled: int = 0
var faction_standings: Dictionary[StringName, int] = {}
var local_path_dockets_settled: int = 0
var epic_summon_pending: bool = false
var epic_summon_issued: bool = false
var silver_earned: int = 0
var traits_gained: Array[StringName] = []
var cedar_desk_log: Array[Dictionary] = []
var era_completion_started: bool = false
var _next_form_sequence: int = 1

func get_faction_standing(faction_id: StringName) -> int:
	return int(faction_standings.get(faction_id, 0))

func change_faction_standing(faction_id: StringName, amount: int) -> int:
	if faction_id == &"" or amount == 0:
		return get_faction_standing(faction_id)
	var next_value := clampi(get_faction_standing(faction_id) + amount, -100, 100)
	faction_standings[faction_id] = next_value
	return next_value

func record_local_path_docket() -> bool:
	local_path_dockets_settled += 1
	if local_path_dockets_settled >= 3 and not epic_summon_issued:
		epic_summon_pending = true
		return true
	return false

func record_case_settlement(person: PersonEntity, silver_before: int, traits_before: Array[StringName]) -> void:
	if person == null:
		return
	cases_settled += 1
	var silver_delta := int(person.resources.get(&"silver", 0)) - silver_before
	if silver_delta > 0:
		silver_earned += silver_delta
	for trait_id in person.traits:
		if trait_id not in traits_before and trait_id not in traits_gained:
			traits_gained.append(trait_id)

func reset_epic_for_new_shift(epic_id: StringName, initial_stage: String = "") -> void:
	if epic_id == &"":
		return
	var epic_state: Dictionary = epics.get(epic_id, {})
	var resource_id := StringName(epic_state.get("progress_resource", ""))
	if resource_id != &"":
		stockpiles[resource_id] = 0
	epic_state["progress"] = 0
	epic_state["stage"] = initial_stage if initial_stage != "" else String(epic_state.get("initial_stage", "survey"))
	epic_state["completed"] = false
	epic_state["active"] = true
	epics[epic_id] = epic_state

func reset_active_epics() -> void:
	for epic_id in epics.keys():
		reset_epic_for_new_shift(StringName(epic_id))

func get_active_epic_id() -> StringName:
	for epic_id in epics.keys():
		var state: Dictionary = epics[epic_id]
		if bool(state.get("active", false)):
			return StringName(epic_id)
	return &""

func is_active_epic_complete() -> bool:
	for epic_id in epics.keys():
		var state: Dictionary = epics[epic_id]
		if not bool(state.get("active", false)):
			continue
		var resource_id := StringName(state.get("progress_resource", ""))
		var target := int(state.get("target", 100))
		if resource_id != &"" and get_resource(resource_id) >= target:
			return true
	return false

func set_world_seed(new_seed: int) -> void:
	master_seed = new_seed
	rng_narrative.seed = new_seed ^ 0x5DEECE66D
	rng_sim.seed = new_seed ^ 0xDEADBEEF
	rng_people.seed = new_seed ^ 0xCAFEBABE

func current_period_index() -> int:
	return year * PERIODS_PER_YEAR + period

## Absolute simulation time, measured in the existing 12-period calendar.
var total_periods: int:
	get:
		return current_period_index()

func advance_period() -> void:
	period += 1
	if period >= PERIODS_PER_YEAR:
		period = 0
		year += 1
	_process_period_deadlines()
	_process_hazards()

func _process_hazards() -> void:
	for index in range(hazards.size()):
		var hazard: Dictionary = hazards[index]
		if not bool(hazard.get("active", false)):
			continue
		var rate := maxi(0, int(hazard.get("rate", 0)))
		var resource_id := StringName(hazard.get("resource", ""))
		if rate <= 0 or resource_id == &"":
			continue
		var place_id := StringName(hazard.get("place_id", ""))
		var institution_id := StringName(hazard.get("institution_id", _get_place_institution_id(place_id)))
		var resource_scope := String(hazard.get("resource_scope", "institution"))
		var available := maxi(0, get_resource(resource_id, resource_scope, "", institution_id))
		var lost := mini(available, rate)
		if lost <= 0:
			continue
		modify_resource(resource_id, -lost, resource_scope, "", institution_id)
		hazard["total_lost"] = int(hazard.get("total_lost", 0)) + lost
		hazards[index] = hazard

func _get_place_institution_id(place_id: StringName) -> StringName:
	var cursor := place_id
	var visited: Dictionary = {}
	while cursor != &"" and not visited.has(cursor):
		visited[cursor] = true
		for institution_id in institutions:
			var institution: Dictionary = institutions[institution_id]
			if StringName(institution.get("place_id", "")) == cursor:
				return StringName(institution_id)
		var place: Dictionary = places.get(cursor, {})
		cursor = StringName(place.get("parent", ""))
	return &""

func has_active_hazard(place_id: StringName, hazard_id: StringName = &"") -> bool:
	for hazard in hazards:
		if not bool(hazard.get("active", false)):
			continue
		if StringName(hazard.get("place_id", "")) != place_id:
			continue
		if hazard_id == &"" or StringName(hazard.get("id", "")) == hazard_id:
			return true
	return false

func get_hazard_total_lost(place_id: StringName = &"", hazard_id: StringName = &"") -> int:
	var total := 0
	for hazard in hazards:
		if place_id != &"" and StringName(hazard.get("place_id", "")) != place_id:
			continue
		if hazard_id != &"" and StringName(hazard.get("id", "")) != hazard_id:
			continue
		total += int(hazard.get("total_lost", 0))
	return total

func repair_hazard(place_id: StringName, hazard_id: StringName) -> bool:
	if place_id == &"" or hazard_id == &"":
		return false
	for index in range(hazards.size()):
		var hazard: Dictionary = hazards[index]
		if StringName(hazard.get("place_id", "")) != place_id:
			continue
		if StringName(hazard.get("id", "")) != hazard_id:
			continue
		if not bool(hazard.get("active", false)):
			return false
		hazard["active"] = false
		hazards[index] = hazard
		return true
	return false

func offer_assignment(assignment_id: StringName, employer_id: StringName) -> bool:
	if assignment_id == &"" or employer_id == &"" or assignments.has(assignment_id):
		return false
	if get_person(employer_id) == null:
		push_warning("WorldState: assignment employer '%s' does not exist" % employer_id)
		return false
	assignments[assignment_id] = {
		"status": "offered",
		"employer_id": employer_id,
		"offered_period": current_period_index(),
		"actions": {},
		"consultations": [],
		"assessment": &"",
	}
	return true

func start_assignment(assignment_id: StringName) -> bool:
	if not assignments.has(assignment_id):
		return false
	var entry: Dictionary = assignments[assignment_id]
	if String(entry.get("status", "")) != "offered":
		return false
	entry["status"] = "active"
	assignments[assignment_id] = entry
	return true

func record_assignment_action(assignment_id: StringName, action_id: StringName, consulted_person_id: StringName = &"") -> bool:
	if assignment_id == &"" or action_id == &"" or not assignments.has(assignment_id):
		return false
	var entry: Dictionary = assignments[assignment_id]
	if String(entry.get("status", "")) != "active":
		return false
	if consulted_person_id != &"" and get_person(consulted_person_id) == null:
		push_warning("WorldState: consultation references unknown person %s" % consulted_person_id)
		return false
	var actions: Dictionary = entry.get("actions", {})
	if actions.has(action_id):
		return false
	actions[action_id] = true
	entry["actions"] = actions
	if consulted_person_id != &"":
		var consultations: Array = entry.get("consultations", [])
		consultations.append({"person_id": consulted_person_id, "period": current_period_index()})
		entry["consultations"] = consultations
	assignments[assignment_id] = entry
	return true

func complete_assignment(assignment: AssignmentDef, actor_id: StringName, assessment: StringName, is_accurate: bool) -> bool:
	if assignment == null or not assignment.is_valid() or actor_id == &"" or assessment == &"":
		return false
	var assignment_id := assignment.id
	if not assignments.has(assignment_id):
		return false
	var entry: Dictionary = assignments[assignment_id]
	if String(entry.get("status", "")) != "active":
		return false
	if StringName(entry.get("employer_id", "")) != assignment.employer:
		push_warning("WorldState: assignment employer does not match its definition")
		return false
	var actor := get_person(actor_id)
	var employer := get_person(assignment.employer)
	if actor == null or employer == null:
		push_warning("WorldState: assignment settlement could not resolve actor and employer")
		return false
	var actions: Dictionary = entry.get("actions", {})
	for action_id in assignment.required_actions:
		if not actions.has(action_id):
			return false

	var opinion_delta := assignment.opinion_penalty
	if is_accurate:
		opinion_delta = assignment.opinion_reward
		actor.resources[assignment.compensation_resource] = int(actor.resources.get(assignment.compensation_resource, 0)) + assignment.compensation_amount
		actor.skills.add_xp(&"law", assignment.law_xp)
	employer.change_opinion(actor_id, opinion_delta, "North-Bay roof inspection assessment: %s" % ("accurate and supported" if is_accurate else "unsupported; contradicted by physical inspection"), year)

	entry["status"] = "completed"
	entry["assessment"] = assessment
	entry["accurate"] = is_accurate
	entry["completed_period"] = current_period_index()
	entry["rewarded"] = is_accurate
	assignments[assignment_id] = entry
	if is_accurate and has_active_hazard(&"north_bay", &"roof_leak"):
		enqueue_form({"form_type": &"north_bay_roof_repair", "subject_id": &"north_bay", "urgency": 2, "year": year})
	return true

func get_assignment_state(assignment_id: StringName) -> Dictionary:
	if not assignments.has(assignment_id):
		return {}
	return assignments[assignment_id].duplicate(true)

func _process_period_deadlines() -> void:
	var now := current_period_index()
	for flag in world_flags.keys():
		if int(world_flags[flag]) != -1 and now >= int(world_flags[flag]):
			world_flags.erase(flag)
	for route_id in routes.keys():
		var route_state: Dictionary = routes[route_id]
		var expiry := int(route_state.get("expiry_period", -1))
		if bool(route_state.get("has_expiry", false)) and now >= expiry:
			routes.erase(route_id)
	for person in people.values():
		for flag in person.flags.keys():
			if int(person.flags[flag]) != -1 and now >= int(person.flags[flag]):
				person.flags.erase(flag)
	for form in pending_forms:
		if form.has("due_period") and int(form["due_period"]) < now:
			form["status"] = "overdue"

func get_overdue_form_count() -> int:
	var count := 0
	for form in pending_forms:
		if String(form.get("status", "pending")) == "overdue":
			count += 1
	return count

func get_person(person_id: StringName) -> PersonEntity:
	return people.get(person_id)

func get_player() -> PersonEntity:
	return get_person(player_id)

func set_player(person: PersonEntity) -> bool:
	if person == null or person.id == &"":
		player_id = &""
		return false
	if people.has(person.id) and people[person.id] != person:
		push_warning("WorldState: player ID '%s' belongs to another person" % person.id)
		return false
	people[person.id] = person
	player_id = person.id
	return true

func allocate_person_id() -> StringName:
	while true:
		var candidate := StringName("character_%04d" % _next_person_sequence)
		_next_person_sequence += 1
		if not people.has(candidate):
			return candidate
	return &""

func has_pending_form(form_type: StringName = &"") -> bool:
	for form in pending_forms:
		if form_type == &"" or StringName(form.get("form_type", "")) == form_type:
			return true
	return false

func get_latest_resolved_form(form_type: StringName) -> Dictionary:
	for index in range(resolved_forms.size() - 1, -1, -1):
		var form: Dictionary = resolved_forms[index]
		if StringName(form.get("form_type", "")) == form_type:
			return form
	return {}

func enqueue_form(form: Dictionary) -> StringName:
	var stored_form := form.duplicate(true)
	var form_id := StringName(stored_form.get("id", ""))
	if form_id == &"":
		form_id = StringName("form_%06d" % _next_form_sequence)
		_next_form_sequence += 1
	stored_form["id"] = form_id
	stored_form["status"] = String(stored_form.get("status", "pending"))
	if stored_form.has("due_period") and int(stored_form["due_period"]) < current_period_index():
		stored_form["status"] = "overdue"
	pending_forms.append(stored_form)
	return form_id

func record_form_assessment(form_id: StringName, assessment: String) -> bool:
	if form_id == &"" or assessment.strip_edges().is_empty():
		return false
	for form in pending_forms:
		if StringName(form.get("id", "")) == form_id:
			form["assessment"] = assessment
			form["assessed_year"] = year
			return true
	return false

func resolve_form(parameters: Dictionary, current_year: int) -> bool:
	var requested_id := StringName(parameters.get("form_id", ""))
	var requested_type := StringName(parameters.get("form_type", ""))
	if requested_id == &"" and requested_type == &"":
		push_warning("WorldState: resolve_form requires form_id or form_type")
		return false
	var match_index := -1
	for i in range(pending_forms.size()):
		var form: Dictionary = pending_forms[i]
		if requested_id != &"":
			if StringName(form.get("id", "")) == requested_id:
				match_index = i
				break
		elif StringName(form.get("form_type", "")) == requested_type:
			match_index = i
			break
	if match_index < 0:
		push_warning("WorldState: no pending form matched resolve_form request")
		return false
	var archived: Dictionary = pending_forms[match_index].duplicate(true)
	archived["was_overdue"] = String(archived.get("status", "pending")) == "overdue"
	archived["status"] = "resolved"
	if parameters.has("assessment"):
		archived["assessment"] = String(parameters["assessment"])
		archived["assessed_year"] = current_year
	archived["disposition"] = String(parameters.get("disposition", "closed"))
	archived["closing_year"] = current_year
	if parameters.has("notes"):
		archived["closing_notes"] = String(parameters["notes"])
	resolved_forms.append(archived)
	pending_forms.remove_at(match_index)
	return true

func get_resource(resource_id: StringName, scope: String = "world", owner_id: String = "", institution_id: StringName = &"") -> int:
	if resource_id == &"":
		return 0
	match scope:
		"actor":
			var person := get_person(StringName(owner_id))
			return person.resources.get(resource_id, 0) if person != null else 0
		"office", "institution":
			var resolved_id := institution_id if institution_id != &"" else get_institution_for_person(StringName(owner_id))
			if resolved_id == &"" and owner_id != "":
				return 0
			if resolved_id == &"":
				resolved_id = &"eanna_household"
			var institution: Dictionary = institutions.get(resolved_id, {})
			var resources: Dictionary = institution.get("stockpiles", {})
			return int(resources.get(resource_id, 0))
		"world":
			if stockpiles.has(resource_id):
				return int(stockpiles[resource_id])
			# Legacy world-scope callers resolve seeded household commodities to
			# Eanna until all authored data has explicit institution scope.
			return get_resource(resource_id, "institution", "", &"eanna_household")
		_:
			return 0

func institution_has_resource(resource_id: StringName, institution_id: StringName = &"eanna_household") -> bool:
	var institution: Dictionary = institutions.get(institution_id, {})
	var resources: Dictionary = institution.get("stockpiles", {})
	return resources.has(resource_id)

func get_institution_for_person(person_id: StringName) -> StringName:
	if person_id == &"":
		return &""
	for institution_id in institutions.keys():
		var institution: Dictionary = institutions[institution_id]
		if person_id in institution.get("members", []):
			return StringName(institution_id)
	return &""

func modify_resource(resource_id: StringName, amount: int, scope: String = "world", owner_id: String = "", institution_id: StringName = &"") -> bool:
	if resource_id == &"":
		push_warning("WorldState: refusing resource change with empty id")
		return false
	if scope not in ["world", "actor", "office", "institution"]:
		push_warning("WorldState: unsupported resource scope '%s'; no resource changed" % scope)
		return false
	if scope == "actor":
		var person := get_person(StringName(owner_id))
		if person == null:
			push_warning("WorldState: actor resource change has no owner")
			return false
		var personal_next := int(person.resources.get(resource_id, 0)) + amount
		if personal_next < 0:
			return false
		person.resources[resource_id] = personal_next
		return true
	if scope == "office" or scope == "institution" or (scope == "world" and not stockpiles.has(resource_id) and institution_has_resource(resource_id, &"eanna_household")):
		var resolved_id := institution_id if institution_id != &"" else get_institution_for_person(StringName(owner_id))
		if resolved_id == &"" and owner_id != "":
			push_warning("WorldState: actor has no institution for scoped resource change")
			return false
		if resolved_id == &"":
			resolved_id = &"eanna_household"
		if not institutions.has(resolved_id):
			push_warning("WorldState: institution resource change cannot resolve '%s'" % resolved_id)
			return false
		var institution: Dictionary = institutions[resolved_id]
		var resources: Dictionary = institution.get("stockpiles", {}).duplicate(true)
		var institution_next := int(resources.get(resource_id, 0)) + amount
		if institution_next < 0:
			return false
		resources[resource_id] = institution_next
		institution["stockpiles"] = resources
		institutions[resolved_id] = institution
		return true
	var next_value := int(stockpiles.get(resource_id, 0)) + amount
	var is_epic_progress := String(resource_id).ends_with("_progress")
	var progress_target := 100
	for epic_state in epics.values():
		if StringName(epic_state.get("progress_resource", "")) != resource_id:
			continue
		is_epic_progress = true
		if bool(epic_state.get("active", false)):
			progress_target = int(epic_state.get("target", 100))
			break
	if is_epic_progress:
		next_value = clampi(next_value, 0, progress_target)
	stockpiles[resource_id] = next_value
	return true

func set_flag(flag: StringName, expiry_period: int) -> void:
	if flag != &"":
		world_flags[flag] = expiry_period

func clear_flag(flag: StringName) -> void:
	world_flags.erase(flag)

func has_flag(flag: StringName, current_period: int) -> bool:
	if not world_flags.has(flag):
		return false
	var expiry: int = world_flags[flag]
	return expiry == -1 or current_period < expiry

func record_event(event_id: StringName, actor_id: StringName, current_year: int) -> void:
	event_history.append({"event_id": event_id, "actor_id": actor_id, "year": current_year})
	if actor_id != &"":
		if not character_event_history.has(actor_id):
			character_event_history[actor_id] = []
		character_event_history[actor_id].append({"event_id": event_id, "year": current_year})

func has_event_fired(event_id: StringName) -> bool:
	for entry in event_history:
		if StringName(entry.get("event_id", "")) == event_id:
			return true
	return false

func has_character_fired(event_id: StringName, actor_id: StringName) -> bool:
	for entry in character_event_history.get(actor_id, []):
		if StringName(entry.get("event_id", "")) == event_id:
			return true
	return false

func was_event_recent(event_id: StringName, current_year: int, within_years: int) -> bool:
	for entry in event_history:
		if StringName(entry.get("event_id", "")) == event_id:
			var age := current_year - int(entry.get("year", -999999))
			if age >= 0 and age <= within_years:
				return true
	return false
