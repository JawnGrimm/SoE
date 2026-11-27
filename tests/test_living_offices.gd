extends SceneTree

var _checks := 0
var _failures: Array[String] = []
var _finished := false

const SaveCodecScript = preload("res://systems/save_codec.gd")

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(35.0).timeout
	if not _finished:
		printerr("TEST WATCHDOG: living offices test did not finish")
		quit(2)

func _run() -> void:
	var definitions := DefinitionRegistry.new()
	definitions.load_defaults()
	var world := WorldState.new()
	UrukSeeder.seed_campaign(world, 32001127, true, definitions)
	var simulator := WorldSimulator.new(definitions)

	# The seed roster assigns the named Umma officials persistent generated IDs.
	var grain_clerk := world.get_person(&"character_0012")
	var bailiff := world.get_person(&"character_0013")
	_check(grain_clerk != null and grain_clerk.display_name == "Nin-Enlil", "Seeded Umma granary clerk is Nin-Enlil")
	_check(bailiff != null and bailiff.display_name == "Ur-Mes", "Seeded Umma canal bailiff is Ur-Mes")
	if grain_clerk != null:
		grain_clerk.office_id = &"granary_clerk"
	if bailiff != null:
		bailiff.office_id = &"canal_bailiff"
	var umma_granary: Dictionary = world.institutions.get(&"umma_granary", {})
	var umma_canal: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	umma_granary["members"] = [grain_clerk.id] if grain_clerk != null else []
	umma_granary["stockpiles"] = {&"barley": 12, &"labor": 5}
	umma_granary["pressure_thresholds"] = {&"barley_warn": 80, &"labor_warn": 7}
	world.institutions[&"umma_granary"] = umma_granary
	umma_canal["members"] = [bailiff.id] if bailiff != null else []
	umma_canal["resource_pressure"] = 2
	umma_canal["stockpiles"] = {&"barley": 40, &"labor": 3}
	umma_canal["pressure_thresholds"] = {&"labor_warn": 7}
	world.institutions[&"umma_canal_bailiff"] = umma_canal

	simulator._simulate_people(world)
	_check(_has_form_from(world, &"contradictory_grain_docket", &"character_0012"), "Umma grain shortage produces Nin-Enlil's local contradictory docket")
	_check(int(world.institutions[&"umma_granary"].get("agenda_evaluation_count", 0)) > 0, "Umma granary agenda ticks independently of Uruk")
	_check(_has_form_from(world, &"bailiff_requisition", &"character_0013"), "Umma canal pressure generates Ur-Mes's requisition")
	var requisition := _find_form(world, &"bailiff_requisition", &"umma")
	_check(StringName(requisition.get("target_institution_id", "")) == &"umma_granary", "Bailiff requisition targets the regional Umma granary")
	world.periods_elapsed = 6
	simulator._simulate_people(world)
	requisition = _find_form(world, &"bailiff_requisition", &"umma")
	_check(bool(requisition.get("agenda_escalated", false)) and int(requisition.get("urgency", 0)) >= 8, "An unanswered requisition older than four periods escalates")

	# Replace the named archivist with a generated successor; agenda ownership
	# follows the seated office, not the old character ID.
	var archive: Dictionary = world.institutions.get(&"eanna_archive", world.institutions.get(&"eanna_household", {}))
	var original := world.get_person(&"shuruppak_ilu")
	var successor := PersonEntity.new()
	successor.id = world.allocate_person_id()
	successor.display_name = "Generated Archive Keeper"
	successor.location_id = &"uruk"
	successor.office_id = &""
	successor.generation_source = &"tier2"
	world.people[successor.id] = successor
	if original != null:
		original.office_id = &""
		var old_members: Array = archive.get("members", []).duplicate()
		old_members.erase(original.id)
		archive["members"] = old_members
	var archive_members: Array = archive.get("members", []).duplicate()
	archive_members.append(successor.id)
	archive["members"] = archive_members
	var archive_institution_id := &"eanna_archive" if world.institutions.has(&"eanna_archive") else &"eanna_household"
	world.institutions[archive_institution_id] = archive
	PopulationService.new().seat_institution_staff(world, definitions)
	_check(successor.office_id == &"archive_keeper", "Generated successor is seated into the vacant archive keeper office")
	_check(StringName(world.institutions[archive_institution_id].get("offices", {}).get(&"archive_keeper", "")) == successor.id, "Office map points to the successor rather than the former archivist")
	var player := world.get_player()
	player.resources[&"silver"] = 0
	player.flags[&"audit_exposure"] = 2
	player.traits.append(&"pliable")
	world.periods_elapsed = 6
	simulator._simulate_people(world)
	_check(int(player.flags.get(&"audit_debt", 0)) == 2, "Successor archivist audits exposure and records unpaid fine as debt")
	_check(successor.get_opinion(player.id) == -2, "Successor archivist applies the audit opinion penalty")
	_check(_delta_contains(world, "Generated Archive Keeper"), "Archive reprimand delta names the seated successor")
	_check(not _delta_contains(world, "Shuruppak-ilu"), "Archive reprimand no longer names the replaced archivist")

	# The foreman response uses the active Epic disruption flag already consumed
	# by the canal simulator's inundation/regression logic.
	var foreman := _find_official(world, [&"carrier_foreman", &"labor_foreman"])
	_check(foreman != null, "A carrier/labor foreman is seated in the transport institution")
	world.epics[&"great_canal_cut"]["active"] = true
	world.set_flag(&"thirsty_diggers", world.current_period_index())
	if foreman != null:
		simulator.advance_period(world)
	_check(world.has_flag(&"canal_crew_slowdown", world.current_period_index()), "Thirsty diggers trigger canal crew slowdown")
	var epic_state: Dictionary = world.epics.get(&"great_canal_cut", {})
	_check(bool(epic_state.get("crew_disruption", false)), "Foreman marks the active Epic as disrupted")
	_check(_delta_contains(world, "crew unrest"), "Foreman reaction is recorded in period deltas")

	# Office IDs, member lists, pending forms, and agenda state survive codec roundtrip.
	var save_payload := SaveCodecScript.encode_world(world, {})
	var decoded := SaveCodecScript.decode_save(save_payload)
	_check(bool(decoded.get("success", false)), "Living office world save decodes")
	if bool(decoded.get("success", false)):
		var loaded: WorldState = decoded.world
		var loaded_grain := loaded.get_person(&"character_0012")
		_check(loaded_grain != null and loaded_grain.office_id == &"granary_clerk", "Save/load preserves Nin-Enlil's seated office")
		_check(_has_form_from(loaded, &"bailiff_requisition", &"character_0013"), "Save/load preserves pending bailiff agenda forms")
		_check(StringName(loaded.institutions[&"umma_granary"].get("last_grain_clerk_agenda", {}).get("official_id", "")) == &"character_0012", "Save/load preserves the institution's last agenda state")
		_check(loaded.get_person(successor.id).office_id == &"archive_keeper" and StringName(loaded.institutions[archive_institution_id].get("offices", {}).get(&"archive_keeper", "")) == successor.id, "Save/load preserves successor office mapping without stale archivist pointers")

	_finish()

func _find_official(world: WorldState, office_ids: Array[StringName]) -> PersonEntity:
	for institution in world.institutions.values():
		for member_id in institution.get("members", []):
			var person := world.get_person(StringName(member_id))
			if person != null and office_ids.has(person.office_id):
				return person
	return null

func _find_form(world: WorldState, form_type: StringName, subject_id: StringName) -> Dictionary:
	for form in world.pending_forms:
		if StringName(form.get("form_type", "")) == form_type and StringName(form.get("subject_id", "")) == subject_id:
			return form
	return {}

func _has_form_from(world: WorldState, form_type: StringName, official_id: StringName) -> bool:
	for form in world.pending_forms:
		if StringName(form.get("form_type", "")) == form_type and StringName(form.get("generated_by", "")) == official_id:
			return true
	return false

func _delta_contains(world: WorldState, phrase: String) -> bool:
	for entry in world.last_period_deltas:
		if String(entry.get("text", "")).contains(phrase):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)

func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("PASS: %d living office checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d living office checks failed" % [_failures.size(), _checks])
		quit(1)
