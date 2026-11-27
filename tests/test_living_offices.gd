extends SceneTree
## Headless regression coverage for office-driven agendas, seating, succession, and save/load.
var _checks := 0
var _failures: Array[String] = []
var _finished := false
const SaveCodecScript = preload("res://systems/save_codec.gd")
func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")
func _watchdog() -> void:
	await create_timer(40.0).timeout
	if not _finished:
		printerr("TEST WATCHDOG: living offices test did not finish")
		quit(2)
func _run() -> void:
	var definitions := DefinitionRegistry.new()
	definitions.load_defaults()
	var world := WorldState.new()
	UrukSeeder.seed_campaign(world, 32001127, true, definitions)
	var simulator := WorldSimulator.new(definitions)
	var nin := world.get_person(&"character_0012")
	var ur_mes := world.get_person(&"character_0013")
	var granary: Dictionary = world.institutions.get(&"umma_granary", {})
	var canal: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	_check(nin != null and nin.display_name == "Nin-Enlil" and nin.office_id == &"granary_clerk", "Seed seats Nin-Enlil as Umma granary clerk")
	_check(ur_mes != null and ur_mes.display_name == "Ur-Mes" and ur_mes.office_id == &"canal_bailiff", "Seed seats Ur-Mes as Umma canal bailiff")
	_check(StringName(granary.get("place_id", "")) == &"umma_granary_yard" and StringName(world.places.get(&"umma_granary_yard", {}).get("parent", "")) == &"umma", "Granary yard is a child place under Umma")
	_check(nin != null and nin.id in granary.get("members", []) and nin.id not in canal.get("members", []), "Nin-Enlil is not double-listed in canal office")
	_check(ur_mes != null and ur_mes.id in canal.get("members", []) and StringName(canal.get("offices", {}).get(&"canal_bailiff", "")) == ur_mes.id, "Ur-Mes occupies canal bailiff office map")
	_check(int(granary.get("stockpiles", {}).get(&"barley", 0)) == 100, "Granary starts with authored 100 barley")
	_check(world.people.size() == 29, "Named officials replace two generated slots; population count stays stable")
	if nin != null:
		granary["stockpiles"] = {&"barley": 12, &"labor": 5}
		granary["pressure_thresholds"] = {&"barley_warn": 80, &"labor_warn": 7}
		world.institutions[&"umma_granary"] = granary
	canal["resource_pressure"] = 2
	canal["stockpiles"] = {&"barley": 40, &"labor": 3}
	canal["pressure_thresholds"] = {&"labor_warn": 7}
	world.institutions[&"umma_canal_bailiff"] = canal
	simulator.advance_period(world)
	_check(nin != null and _has_form_from(world, &"contradictory_grain_docket", nin.id), "Umma shortage produces Nin-Enlil's local discrepancy docket")
	_check(int(world.institutions[&"umma_granary"].get("agenda_evaluation_count", 0)) > 0, "Umma grain BT ticks independently of Uruk")
	_check(nin != null and StringName(world.institutions[&"umma_granary"].get("last_grain_clerk_agenda", {}).get("official_id", "")) == nin.id, "Grain agenda records current clerk identity")
	_check(ur_mes != null and _has_form_from(world, &"bailiff_requisition", ur_mes.id), "Canal BT generates Ur-Mes's requisition")
	var requisition := _find_form(world, &"bailiff_requisition", &"umma")
	_check(StringName(requisition.get("target_institution_id", "")) == &"umma_granary", "Requisition targets regional granary")
	world.period = 6 # Advance the BCE calendar index; periods_elapsed alone does not age created_period.
	world.periods_elapsed = 6
	simulator._simulate_people(world)
	requisition = _find_form(world, &"bailiff_requisition", &"umma")
	_check(bool(requisition.get("agenda_escalated", false)) and int(requisition.get("urgency", 0)) >= 8, "Requisition older than four periods escalates")
	var archive_id := &"eanna_household"
	var archive: Dictionary = world.institutions.get(archive_id, {})
	var former := world.get_person(&"shuruppak_ilu")
	var successor := PersonEntity.new()
	successor.id = world.allocate_person_id()
	successor.display_name = "Generated Archive Keeper"
	successor.location_id = &"uruk"
	successor.generation_source = &"tier2"
	successor.generation_key = &"test_archive_succession"
	for skill_id in [&"literacy", &"arithmetic", &"law", &"stewardship"]:
		successor.skills.levels[skill_id] = 3
	world.people[successor.id] = successor
	var archive_members: Array = archive.get("members", []).duplicate()
	if former != null:
		archive_members.erase(former.id)
		former.office_id = &""
	archive_members.append(successor.id)
	archive["members"] = archive_members
	world.institutions[archive_id] = archive
	PopulationService.new().seat_institution_staff(world, definitions)
	_check(successor.office_id == &"archive_keeper", "PopulationService seats generated successor into archive office")
	_check(StringName(world.institutions[archive_id].get("offices", {}).get(&"archive_keeper", "")) == successor.id, "Office map points to successor, not former archivist")
	var player := world.get_player()
	player.resources[&"silver"] = 0
	player.flags[&"audit_exposure"] = 2
	if &"pliable" not in player.traits: player.traits.append(&"pliable")
	world.periods_elapsed = 6
	simulator._simulate_people(world)
	_check(int(player.flags.get(&"audit_debt", 0)) == 2, "Archive BT fines or records debt")
	_check(successor.get_opinion(player.id) == -2, "Successor applies audit opinion penalty")
	_check(_delta_contains(world, "Generated Archive Keeper"), "Archive delta names successor")
	_check(not _delta_contains(world, "Shuruppak-ilu"), "Archive consequence drops former holder identity")
	var foreman := _find_official(world, [&"carrier_foreman", &"labor_foreman"])
	_check(foreman != null, "Carrier foreman is seated")
	var epic: Dictionary = world.epics.get(&"great_canal_cut", {})
	epic["active"] = true
	world.epics[&"great_canal_cut"] = epic
	world.set_flag(&"thirsty_diggers", world.current_period_index() + 2) # Expiry is exclusive; keep it active through the next simulated period.
	simulator.advance_period(world)
	var foreman_debug: Array[String] = []
	for institution_id in world.institutions.keys():
		var office_state: Dictionary = world.institutions[institution_id]
		if foreman.id in office_state.get("members", []):
			foreman_debug.append("%s last=%s ticks=%s" % [institution_id, office_state.get("last_foreman_reaction_period", "missing"), office_state.get("office_agenda_evaluation_count", 0)])
	print("FOREMAN DEBUG: id=%s office=%s now=%s thirsty=%s institutions=%s epic=%s deltas=%s" % [foreman.id, foreman.office_id, world.current_period_index(), world.world_flags.get(&"thirsty_diggers", "missing"), foreman_debug, world.epics.get(&"great_canal_cut", {}), world.last_period_deltas])
	_check(world.has_flag(&"canal_crew_slowdown", world.current_period_index()), "Thirsty diggers trigger canal crew slowdown")
	epic = world.epics.get(&"great_canal_cut", {})
	_check(bool(epic.get("crew_disruption", false)), "Foreman marks active Epic disrupted")
	_check(_delta_contains(world, "crew unrest"), "Foreman reaction appears in period deltas")
	var decoded := SaveCodecScript.decode_save(SaveCodecScript.encode_world(world, {}))
	_check(bool(decoded.get("success", false)), "Living office save payload decodes")
	if bool(decoded.get("success", false)):
		var loaded: WorldState = decoded.world
		var loaded_nin := loaded.get_person(&"character_0012")
		_check(loaded_nin != null and loaded_nin.office_id == &"granary_clerk", "Save/load preserves Nin-Enlil office")
		_check(loaded_nin.id in loaded.institutions[&"umma_granary"].get("members", []), "Save/load preserves granary seating")
		_check(loaded_nin.id not in loaded.institutions[&"umma_canal_bailiff"].get("members", []), "Save/load avoids duplicate seating")
		_check(_has_form_from(loaded, &"bailiff_requisition", &"character_0013"), "Save/load preserves pending requisition")
		_check(StringName(loaded.institutions[archive_id].get("offices", {}).get(&"archive_keeper", "")) == successor.id, "Save/load preserves successor office map")
		_check(StringName(loaded.institutions[&"umma_granary"].get("last_grain_clerk_agenda", {}).get("official_id", "")) == &"character_0012", "Save/load preserves grain agenda owner")
	_finish()
func _find_official(world: WorldState, office_ids: Array[StringName]) -> PersonEntity:
	for institution in world.institutions.values():
		for member_id in institution.get("members", []):
			var person := world.get_person(StringName(member_id))
			if person != null and office_ids.has(person.office_id): return person
	return null
func _find_form(world: WorldState, form_type: StringName, subject_id: StringName) -> Dictionary:
	for form in world.pending_forms:
		if StringName(form.get("form_type", "")) == form_type and StringName(form.get("subject_id", "")) == subject_id: return form
	return {}
func _has_form_from(world: WorldState, form_type: StringName, official_id: StringName) -> bool:
	for form in world.pending_forms:
		if StringName(form.get("form_type", "")) == form_type and StringName(form.get("generated_by", "")) == official_id: return true
	return false
func _delta_contains(world: WorldState, phrase: String) -> bool:
	for entry in world.last_period_deltas:
		if String(entry.get("text", "")).contains(phrase): return true
	return false
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		printerr("FAIL: ", label)
func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("PASS: %d living office checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d living office checks failed" % [_failures.size(), _checks])
		for failure in _failures: printerr(" - ", failure)
		quit(1)
