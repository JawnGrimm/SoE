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
	var seated_ids: Array[StringName] = []
	for office_id in [&"canal_bailiff", &"umma_granary_clerk"]:
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
	_check(StringName(second_offices.get(&"canal_bailiff", "")) == seated_ids[0] and StringName(second_offices.get(&"umma_granary_clerk", "")) == seated_ids[1], "Institutional seating is deterministic for an identical world seed")

	var network := NetworkScript.new()
	_check(network.configure(world, registry.all_places(), registry.all_routes(), &"uruk_storehouse"), "Regional route graph configures for Umma")
	var simulator := SimulatorScript.new(registry)
	var travel := TravelScript.new()
	_check(travel.configure(network, simulator), "Travel service uses the authoritative simulator")
	var outbound := travel.travel(world, &"land_uruk_umma", &"umma")
	_check(bool(outbound.get("success", false)) and world.current_location_id == &"umma", "Uruk-to-Umma travel advances and changes the current location")

	var player := world.get_player()
	var opportunities := PipelineScript.generate_opportunities(world, player)
	var umma_ledger: Dictionary = {}
	var local_form: Dictionary = {}
	var procedural: Dictionary = {}
	for opportunity in opportunities:
		var source: Dictionary = opportunity.get("source_data", {})
		if StringName(opportunity.get("kind", "")) == &"ledger" and StringName(opportunity.get("source_id", "")) == &"umma_canal_bailiff":
			umma_ledger = opportunity
		if StringName(opportunity.get("kind", "")) == &"form" and StringName(source.get("form_type", "")) == &"bailiff_requisition":
			local_form = opportunity
		if StringName(opportunity.get("kind", "")) == &"procedural_docket":
			procedural = opportunity
	_check(not umma_ledger.is_empty(), "Umma's institution-specific ledger is on the local board")
	_check(not local_form.is_empty(), "Umma's own low labor stock generates a local bailiff requisition")
	var local_employer_id := StringName(local_form.get("employer_id", ""))
	var local_employer := world.get_person(local_employer_id)
	_check(local_employer != null and local_employer.location_id == &"umma" and local_employer.office_id == &"canal_bailiff", "Local requisition employer resolves to Umma's seated bailiff")
	_check(not procedural.is_empty(), "A local procedural docket is generated at Umma")
	var procedural_source: Dictionary = procedural.get("source_data", {})
	var left_id := StringName(procedural_source.get("left_card", {}).get("speaker_id", ""))
	var right_id := StringName(procedural_source.get("right_card", {}).get("speaker_id", ""))
	_check(world.get_person(left_id) != null and world.get_person(left_id).location_id == &"umma" and world.get_person(right_id) != null and world.get_person(right_id).location_id == &"umma", "Umma procedural docket speakers are local residents")

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
		_check(restored.resolved_forms.size() == world.resolved_forms.size() and restored.cedar_desk_log.size() == world.cedar_desk_log.size(), "Resolved local forms and cedar desk entries survive save/load")
		for person_id in seated_ids:
			_check(restored.get_person(person_id).get_opinion(player.id) == opinions_before_save[person_id], "Umma resident opinion survives save/load")

	var return_result := travel.travel(world, &"land_uruk_umma", &"uruk")
	_check(bool(return_result.get("success", false)) and world.current_location_id == &"uruk", "Return travel restores Uruk after another simulation period")
	var returned := PipelineScript.generate_opportunities(world, player)
	var uruk_work := false
	for opportunity in returned:
		var source: Dictionary = opportunity.get("source_data", {})
		if StringName(opportunity.get("kind", "")) == &"ledger" and StringName(source.get("institution_id", "")) == &"eanna_household":
			uruk_work = true
	_check(uruk_work, "Uruk's local institution work returns after the regional circuit")

	print("Umma institutional circuit: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
