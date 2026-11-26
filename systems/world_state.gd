class_name WorldState
extends RefCounted

const PERIODS_PER_YEAR := 12

var year: int = 1200
var period: int = 0
var master_seed: int = 0
var rng_narrative := RandomNumberGenerator.new()
var rng_sim := RandomNumberGenerator.new()
var rng_people := RandomNumberGenerator.new()
var stockpiles: Dictionary[StringName, int] = {}
var world_flags: Dictionary[StringName, int] = {}
var pending_forms: Array[Dictionary] = []
var resolved_forms: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var character_event_history: Dictionary[StringName, Array] = {}
var people: Dictionary[StringName, PersonEntity] = {}
var assignments: Dictionary[StringName, Dictionary] = {}
var north_bay_roof_leak_active: bool = false
var north_bay_roof_leak_rate: int = 1
var north_bay_roof_total_spoiled: int = 0
var _next_form_sequence: int = 1

func set_world_seed(new_seed: int) -> void:
	master_seed = new_seed
	rng_narrative.seed = new_seed ^ 0x5DEECE66D
	rng_sim.seed = new_seed ^ 0xDEADBEEF
	rng_people.seed = new_seed ^ 0xCAFEBABE

func current_period_index() -> int:
	return year * PERIODS_PER_YEAR + period

func advance_period() -> void:
	period += 1
	if period >= PERIODS_PER_YEAR:
		period = 0
		year += 1
	_process_period_deadlines()
	_process_roof_leak()

func _process_roof_leak() -> void:
	if not north_bay_roof_leak_active or north_bay_roof_leak_rate <= 0:
		return
	var available := maxi(0, get_resource(&"barley"))
	var spoiled := mini(available, north_bay_roof_leak_rate)
	if spoiled <= 0:
		return
	stockpiles[&"barley"] = available - spoiled
	north_bay_roof_total_spoiled += spoiled

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
		modify_resource(assignment.compensation_resource, assignment.compensation_amount)
		actor.skills.add_xp(&"law", assignment.law_xp)
	employer.opinions[actor_id] = int(employer.opinions.get(actor_id, 0)) + opinion_delta
	var reasons: Array = employer.opinion_reasons.get(actor_id, [])
	reasons.append({
		"year": year,
		"amount": opinion_delta,
		"reason": "North-Bay roof inspection assessment: %s" % ("accurate and supported" if is_accurate else "unsupported; contradicted by physical inspection"),
	})
	employer.opinion_reasons[actor_id] = reasons

	entry["status"] = "completed"
	entry["assessment"] = assessment
	entry["accurate"] = is_accurate
	entry["completed_period"] = current_period_index()
	entry["rewarded"] = is_accurate
	assignments[assignment_id] = entry
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

func get_resource(resource_id: StringName) -> int:
	return stockpiles.get(resource_id, 0)

func modify_resource(resource_id: StringName, amount: int, scope: String = "world") -> void:
	if scope != "world":
		push_warning("WorldState: unsupported resource scope '%s'; no resource changed" % scope)
		return
	if resource_id == &"":
		push_warning("WorldState: refusing resource change with empty id")
		return
	var next_value := get_resource(resource_id) + amount
	if resource_id == &"canal_progress":
		next_value = clampi(next_value, 0, 100)
	stockpiles[resource_id] = next_value

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
