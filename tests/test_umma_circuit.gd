extends SceneTree

const RegistryScript = preload("res://systems/definition_registry.gd")
const SeederScript = preload("res://systems/uruk_seeder.gd")
const NetworkScript = preload("res://systems/route_network.gd")
const TravelScript = preload("res://systems/travel_service.gd")
const SimulatorScript = preload("res://systems/world_simulator.gd")
const PipelineScript = preload("res://systems/assignment_pipeline.gd")
const SaveCodecScript = preload("res://systems/save_codec.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := RegistryScript.new()
	registry.load_defaults()
	var world := WorldState.new()
	SeederScript.seed_campaign(world, 32003200, true, registry)
	var umma: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	_check(not umma.is_empty() and StringName(umma.get("place_id", "")) == &"umma", "Registry seeding creates Umma's canal bailiff institution")
	var office_map: Dictionary = umma.get("offices", {})
	var staffed_offices: Array = umma.get("staffed_offices", [])
	_check(staffed_offices.has(&"canal_bailiff") and staffed_offices.has(&"granary_clerk"), "Umma canal institution declares both canal_bailiff and granary_clerk office roles")	
	var nin_enlil := world.get_person(&"character_0012")
	var ur_mes := world.get_person(&"character_0013")
	var granary: Dictionary = world.institutions.get(&"umma_granary", {})
	_check(nin_enlil != null and nin_enlil.office_id == &"granary_clerk" and nin_enlil.id in granary.get("members", []) and nin_enlil.id not in umma.get("members", []), "Nin-Enlil is seated as granary_clerk only in the Umma granary")
	_check(ur_mes != null and ur_mes.office_id == &"canal_bailiff" and ur_mes.id in umma.get("members", []) and StringName(office_map.get(&"canal_bailiff", "")) == ur_mes.id, "Ur-Mes is seated as canal_bailiff in the Umma canal institution")
	var seated_ids: Array[StringName] = []
	for office_id in [&"canal_bailiff", &"granary_clerk"]:
		var person_id := StringName(office_map.get(office_id, ""))
		var person := world.get_person(person_id)
		_check(person != null and person.location_id == &"umma" and person.office_id == office_id, "Umma office %s is held by a seated local Tier 2 resident" % office_id)
		if person != null:
			seated_ids.append(person.id)
	_check(seated_ids.size() == 2 and seated_ids[0] != seated_ids[1], "Umma seats two distinct residents without duplication")

	var second_world := WorldState.new()
	SeederScript.seed_campaign(second_world, 32003200, true, registry)
	var second_umma: Dictionary = second_world.institutions.get(&"umma_canal_bailiff", {})
	var second_offices: Dictionary = second_umma.get("offices", {})
	_check(StringName(second_offices.get(&"canal_bailiff", "")) == seated_ids[0] and StringName(second_offices.get(&"granary_clerk", "")) == seated_ids[1], "Institutional seating is deterministic for an identical world seed")

	var network := NetworkScript.new()
	_check(network.configure(world, registry.all_places(), registry.all_routes(), &"uruk_storehouse"), "Regional route graph configures for Umma")
	var simulator := SimulatorScript.new(registry)
	var umma_initial_state: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	var umma_initial_stock: Dictionary = umma_initial_state.get("stockpiles", {}).duplicate(true)
	simulator._simulate_institutions(world)
	_check(int(world.institutions.get(&"umma_canal_bailiff", {}).get("resource_pressure", -1)) == 0, "Umma's authored local thresholds should be calm at initial/harvest stock levels")
	umma_initial_state["stockpiles"] = {&"barley": 90, &"labor": 6, &"textiles": 4}
	world.institutions[&"umma_canal_bailiff"] = umma_initial_state
	simulator._simulate_institutions(world)
	_check(int(world.institutions.get(&"umma_canal_bailiff", {}).get("resource_pressure", 0)) >= 2, "Umma should register real pressure during lean barley and labor months")
	# Keep the office in the lean-month state for the regional circuit test.
	# The player should see local shortage work because Umma itself is strained.
	var travel := TravelScript.new()
	_check(travel.configure(network, simulator), "Travel service uses the authoritative simulator")
	var outbound := travel.travel(world, &"land_uruk_umma", &"umma")
	_check(bool(outbound.get("success", false)) and world.current_location_id == &"umma", "Uruk-to-Umma travel advances and changes the current location")

	var player := world.get_player()
	var opportunities := PipelineScript.generate_opportunities(world, player)
	var umma_ledger: Dictionary = {}
	var local_form: Dictionary = {}
	var procedural: Dictionary = {}
	var local_pressure: Dictionary = {}
	for opportunity in opportunities:
		var source: Dictionary = opportunity.get("source_data", {})
		if StringName(opportunity.get("kind", "")) == &"ledger" and StringName(opportunity.get("source_id", "")) == &"umma_canal_bailiff":
			umma_ledger = opportunity
		if StringName(opportunity.get("kind", "")) == &"form" and StringName(source.get("form_type", "")) == &"bailiff_requisition":
			local_form = opportunity
		if StringName(opportunity.get("kind", "")) == &"pressure" and StringName(source.get("institution_id", "")) == &"umma_canal_bailiff":
			local_pressure = opportunity
		if StringName(opportunity.get("kind", "")) == &"procedural_docket":
			procedural = opportunity
	_check(not umma_ledger.is_empty(), "Umma's institution-specific ledger is on the local board")
	_check(not local_form.is_empty(), "Umma's own low labor stock generates a local bailiff requisition")
	_check(int(local_form.get("priority", 0)) >= 7, "The local bailiff requisition keeps priority on the four-slot Umma board")
	var canal_after_travel: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	_check(int(canal_after_travel.get("last_bailiff_requisition_period", -100)) == world.current_period_index() and int(canal_after_travel.get("office_agenda_evaluation_count", 0)) > 0, "The seeded canal bailiff agenda ticks and records Ur-Mes's requisition during travel")
	_check(not local_pressure.is_empty(), "Umma pressure work is derived from Umma stockpiles")
	for candidate in opportunities:
		var candidate_source: Dictionary = candidate.get("source_data", {})
		_check(StringName(candidate_source.get("institution_id", "")) != &"eanna_household" and StringName(candidate.get("source_id", "")) != &"roof_leak", "Uruk institution work and hazards do not leak onto Umma's board")
	var local_employer_id := StringName(local_form.get("employer_id", ""))
	var local_employer := world.get_person(local_employer_id)
	_check(local_employer != null and local_employer.location_id == &"umma" and local_employer.office_id == &"canal_bailiff", "Local requisition employer resolves to Umma's seated bailiff")
	_check(not procedural.is_empty(), "A local procedural docket is generated at Umma")
	var procedural_source: Dictionary = procedural.get("source_data", {})
	var left_id := StringName(procedural_source.get("left_card", {}).get("speaker_id", ""))
	var right_id := StringName(procedural_source.get("right_card", {}).get("speaker_id", ""))
	_check(world.get_person(left_id) != null and world.get_person(left_id).location_id == &"umma" and world.get_person(right_id) != null and world.get_person(right_id).location_id == &"umma", "Umma procedural docket speakers are local residents")
	var procedural_employer := world.get_person(StringName(procedural.get("employer_id", "")))
	_check(procedural_employer != null and procedural_employer.location_id == &"umma" and procedural_employer.office_id != &"", "Procedural docket employer resolves to a seated Umma official")

	var assignment_id := StringName(local_form.get("id", ""))
	_check(PipelineScript.begin(world, local_form, player), "Umma requisition begins through the shared assignment lifecycle")
	var first := PipelineScript.perform_action(world, player, assignment_id, &"examine_records")
	var second := PipelineScript.perform_action(world, player, assignment_id, &"reconcile_accounts")
	_check(bool(first.get("success", false)) and bool(second.get("success", false)), "Two investigation actions can be recorded against Umma's requisition")
	var before_silver := int(player.resources.get(&"silver", 0))
	var resolution := PipelineScript.resolve(world, player, assignment_id, &"certify")
	_check(bool(resolution.get("success", false)) and player.resources.get(&"silver", 0) > before_silver, "Resolving Umma work awards career silver")
	_check(not world.resolved_forms.is_empty() and not world.cedar_desk_log.is_empty(), "Umma resolution archives its form and writes the cedar desk chronicle")

	var umma_stock_before_save: Dictionary = world.institutions.get(&"umma_canal_bailiff", {}).get("stockpiles", {}).duplicate(true)
	var opinions_before_save: Dictionary = {}
	for person_id in seated_ids:
		opinions_before_save[person_id] = world.get_person(person_id).get_opinion(player.id)
	var save := SaveCodecScript.decode_save(SaveCodecScript.encode_world(world))
	var restored: WorldState = save.get("world") as WorldState
	_check(bool(save.get("success", false)) and restored != null, "Full world JSON save round-trip restores the regional world")
	if restored != null:
		var restored_institution: Dictionary = restored.institutions.get(&"umma_canal_bailiff", {})
		var restored_stock: Dictionary = restored_institution.get("stockpiles", {})
		_check(restored_stock.has(&"barley") and int(restored_stock.get(&"barley", -1)) == int(umma_stock_before_save.get(&"barley", -2)), "Institution stockpile keys restore as StringName after save/load")
		var restored_thresholds: Dictionary = restored_institution.get("pressure_thresholds", {})
		_check(restored_thresholds.has(&"barley_warn") and int(restored_thresholds.get(&"barley_warn", -1)) == 95, "Institution pressure thresholds survive save/load with StringName keys")
		_check(restored.resolved_forms.size() == world.resolved_forms.size() and restored.cedar_desk_log.size() == world.cedar_desk_log.size(), "Resolved local forms and cedar desk entries survive save/load")
		for person_id in seated_ids:
			_check(restored.get_person(person_id).get_opinion(player.id) == opinions_before_save[person_id], "Umma resident opinion survives save/load")

	var return_result := travel.travel(world, &"land_uruk_umma", &"uruk")
	_check(bool(return_result.get("success", false)) and world.current_location_id == &"uruk", "Return travel restores Uruk after another simulation period")
	var returned := PipelineScript.generate_opportunities(world, player)
	var uruk_work := false
	for opportunity in returned:
		var source: Dictionary = opportunity.get("source_data", {})
		var kind := StringName(opportunity.get("kind", ""))
		if kind == &"hazard" and StringName(opportunity.get("source_id", "")) == &"roof_leak":
			uruk_work = true
		if kind == &"form" and StringName(source.get("subject_id", "")) == &"north_bay":
			uruk_work = true
	_check(uruk_work, "Uruk's North-Bay work returns after the regional circuit")
	_check(world.resolved_forms.size() == 1 and world.cedar_desk_log.size() == 1, "Umma form resolution and chronicle entry remain after returning to Uruk")
	var umma_after_return: Dictionary = world.institutions.get(&"umma_canal_bailiff", {})
	_check(not umma_after_return.is_empty() and umma_after_return.get("stockpiles", {}).has(&"barley"), "Umma institution and its stockpile continue to exist after return")
	var final_save := SaveCodecScript.decode_save(SaveCodecScript.encode_world(world))
	var final_world: WorldState = final_save.get("world") as WorldState
	_check(bool(final_save.get("success", false)) and final_world != null and final_world.institutions.get(&"umma_canal_bailiff", {}).get("stockpiles", {}).has(&"barley"), "The returned regional state survives a second full save/load round-trip")

	print("Umma institutional circuit: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
