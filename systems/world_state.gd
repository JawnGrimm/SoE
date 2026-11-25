class_name WorldState
extends RefCounted

var year: int = 1200
# Zero-based period: 0..11. The UI displays period + 1.
var period: int = 0
var stockpiles: Dictionary[StringName, int] = {}
var world_flags: Dictionary[StringName, int] = {}
var pending_forms: Array[Dictionary] = []
var resolved_forms: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var character_event_history: Dictionary[StringName, Array] = {}
var people: Dictionary[StringName, PersonEntity] = {}
var _next_form_sequence: int = 1

func current_period_index() -> int:
	return year * 12 + period

func advance_period() -> void:
	period += 1
	if period >= 12:
		period = 0
		year += 1
	_process_period_deadlines()

func _process_period_deadlines() -> void:
	var now := current_period_index()
	for flag in world_flags.keys():
		if int(world_flags[flag]) >= 0 and now >= int(world_flags[flag]):
			world_flags.erase(flag)
	for person in people.values():
		for flag in person.flags.keys():
			if int(person.flags[flag]) >= 0 and now >= int(person.flags[flag]):
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
	stockpiles[resource_id] = get_resource(resource_id) + amount

func set_flag(flag: StringName, expiry_period: int) -> void:
	if flag != &"":
		world_flags[flag] = expiry_period

func clear_flag(flag: StringName) -> void:
	world_flags.erase(flag)

func has_flag(flag: StringName, current_period: int) -> bool:
	if not world_flags.has(flag):
		return false
	var expiry: int = world_flags[flag]
	return expiry < 0 or current_period < expiry

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
