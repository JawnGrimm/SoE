extends SceneTree

const QueueScript = preload("res://ui/work_queue_overlay.gd")
const Pipeline = preload("res://systems/assignment_pipeline.gd")
const EventRunnerScript = preload("res://systems/event_runner.gd")
const SaveCodec = preload("res://systems/save_codec.gd")
const PopulationServiceScript = preload("res://systems/population_service.gd")
const Quayside: EventTemplate = preload("res://data/events/challenge_quayside_stoppage.tres")
const LedgerInquest: EventTemplate = preload("res://data/events/challenge_ledger_inquest.tres")
const SiltBreach: EventTemplate = preload("res://data/events/challenge_dry_kettles_silt_breach.tres")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(QueueScript.category_for({"kind": &"project_review"}) == "epics", "Epic milestone reviews route to Epics")
	_check(QueueScript.category_for({"kind": &"epic"}) == "epics", "Epic records route to Epics")
	_check(QueueScript.category_for({"kind": &"challenge"}) == "challenges", "Challenge event opportunities route to Challenges")
	_check(QueueScript.category_for({"source_id": &"challenge_quayside_stoppage"}) == "challenges", "Challenge source IDs route to Challenges")
	_check(QueueScript.category_for({"kind": &"form"}) == "assignments", "Routine forms remain Assignments")
	var population := PopulationServiceScript.new()
	_check(population.load_name_table() and population._names_by_culture.get(&"sumerian", []).size() >= 60, "Era I Sumerian name table contains at least sixty eligible entries")
	var scribe_template: CharacterTemplate = load("res://data/characters/uruk_scribe_template.tres")
	_check(scribe_template != null and scribe_template.trait_ids.has(&"meticulous") and int(scribe_template.skill_bonuses.get(&"literacy", 0)) == 2 and int(scribe_template.skill_bonuses.get(&"arithmetic", 0)) == 1, "Uruk scribe template carries meticulous and literacy/arithmetic bonuses")

	var world := WorldState.new()
	world.year = -3199
	world.stockpiles[&"test_epic_progress"] = 0
	var actor := PersonEntity.new()
	actor.id = &"circuit_scribe"
	actor.display_name = "Circuit Scribe"
	actor.office_id = &"apprentice_scribe"
	actor.traits = [&"pliable", &"severe"]
	actor.resources[&"silver"] = 0
	world.set_player(actor)
	var foreman := PersonEntity.new()
	foreman.id = &"enlil_kisu"
	foreman.display_name = "Enlil-kisu"
	world.people[foreman.id] = foreman
	world.institutions[&"eanna_household"] = {
		"name": "Eanna Temple",
		"place_id": &"uruk",
		"members": [],
		"stockpiles": {&"barley": 100, &"labor": 20},
		"resource_pressure": 7,
		"local_opinion": 0
	}
	world.epics[&"test_epic"] = {
		"active": true,
		"completed": false,
		"progress": 0,
		"progress_resource": &"test_epic_progress",
		"target": 100,
		"sponsor_institution": &"eanna_household",
		"review_pending": true,
		"review_stage": 1,
		"review_reason": "stage_reached",
		"review_cycle": 0,
		"stage": "survey",
		"history_notes": []
	}

	var epic_opportunity := {
		"id": &"epic:test_epic:s1",
		"kind": &"project_review",
		"source_id": &"test_epic",
		"sponsor_institution": &"eanna_household",
		"title": "Test Epic Review",
		"summary": "Test milestone",
		"source_data": {
			"progress_resource": &"test_epic_progress",
			"progress": 0,
			"target": 100,
			"review_stage": 1,
			"review_reason": "stage_reached",
			"sponsor_institution": &"eanna_household"
		}
	}
	_check(Pipeline.begin(world, epic_opportunity, actor), "Epic review begins as an active assignment")
	var epic_id := StringName(epic_opportunity.id)
	_check(bool(Pipeline.perform_action(world, actor, epic_id, &"examine_records").get("success", false)), "Epic review accepts first inquiry")
	_check(bool(Pipeline.perform_action(world, actor, epic_id, &"reconcile_accounts").get("success", false)), "Epic review accepts second inquiry")

	world.set_flag(&"thirsty_diggers", -1)
	var save_result := SaveCodec.decode_save(SaveCodec.encode_world(world))
	var restored: WorldState = save_result.get("world") as WorldState
	_check(bool(save_result.get("success", false)) and restored != null, "Circuit world round-trips through the versioned save codec")
	if restored != null:
		_check(String(restored.assignments.get(epic_id, {}).get("status", "")) == "active", "Save/load preserves an active Epic review assignment")
		_check(bool(restored.epics.get(&"test_epic", {}).get("review_pending", false)), "Save/load preserves pending Epic review state")
		_check(restored.has_flag(&"thirsty_diggers", restored.current_period_index()), "Save/load preserves Challenge-triggering world flags")

	var emergency := Pipeline.resolve(world, actor, epic_id, &"epic_emergency")
	_check(bool(emergency.get("success", false)), "Emergency Epic verdict resolves")
	_check(world.get_resource(&"barley", "institution", "", &"eanna_household") == 80 and world.get_resource(&"labor", "institution", "", &"eanna_household") == 18, "Emergency Epic verdict spends exactly 20 barley and 2 labor")
	_check(world.get_resource(&"test_epic_progress") == 15, "Emergency Epic verdict advances progress by 15")
	_check(not bool(world.epics.get(&"test_epic", {}).get("stalled", true)) and not bool(world.epics.get(&"test_epic", {}).get("review_pending", true)), "Emergency verdict clears stall and acknowledges the review")

	# A second review exercises the honest audit verdict without spending sponsor stock.
	var epic_state: Dictionary = world.epics[&"test_epic"]
	epic_state["review_pending"] = true
	epic_state["review_stage"] = 1
	epic_state["review_reason"] = "stage_reached"
	world.epics[&"test_epic"] = epic_state
	var audit_opportunity := epic_opportunity.duplicate(true)
	audit_opportunity["id"] = &"epic:test_epic:audit"
	audit_opportunity["source_data"]["progress"] = 15
	_check(Pipeline.begin(world, audit_opportunity, actor), "Second Epic review begins")
	var audit_id := StringName(audit_opportunity.id)
	Pipeline.perform_action(world, actor, audit_id, &"examine_records")
	Pipeline.perform_action(world, actor, audit_id, &"reconcile_accounts")
	var audit_result := Pipeline.resolve(world, actor, audit_id, &"epic_audit")
	_check(bool(audit_result.get("success", false)), "Epic audit verdict resolves")
	_check(actor.get_opinion(&"enlil_kisu") == -3 and int(actor.flags.get(&"audit_exposure", 0)) == 0, "Epic audit applies foreman opinion and clears one exposure")
	_check(int(actor.skills.xp.get(&"law", 0)) >= 15 and bool(world.epics.get(&"test_epic", {}).get("stalled", false)), "Epic audit awards law XP and halts the project")

	# The pliable certification branch produces its intended consequence chain.
	epic_state = world.epics[&"test_epic"]
	epic_state["review_pending"] = true
	epic_state["review_stage"] = 1
	epic_state["review_reason"] = "stage_reached"
	world.epics[&"test_epic"] = epic_state
	var certify_opportunity := epic_opportunity.duplicate(true)
	certify_opportunity["id"] = &"epic:test_epic:certify"
	certify_opportunity["source_data"]["progress"] = 15
	_check(Pipeline.begin(world, certify_opportunity, actor), "Third Epic review begins")
	var certify_id := StringName(certify_opportunity.id)
	Pipeline.perform_action(world, actor, certify_id, &"examine_records")
	Pipeline.perform_action(world, actor, certify_id, &"reconcile_accounts")
	var silver_before_certify := int(actor.resources.get(&"silver", 0))
	var certify_result := Pipeline.resolve(world, actor, certify_id, &"epic_certify")
	_check(bool(certify_result.get("success", false)), "Uninspected Epic certification resolves")
	_check(actor.resources[&"silver"] == silver_before_certify + 2 and actor.traits.has(&"pliable") and int(actor.flags.get(&"audit_exposure", 0)) == 1, "Certification grants two silver, pliable trait, and one exposure")
	_check(world.has_flag(&"entangled_brewery_accounts", world.current_period_index()), "Certification sets the ledger inquest trigger flag")

	# Pressure verdicts are pipeline-owned and retain stockpile mutations.
	var pressure_opportunity := {
		"id": &"pressure:drawdown",
		"kind": &"pressure",
		"source_id": &"eanna_household",
		"employer_id": &"",
		"title": "Temple Pressure",
		"summary": "Pressure",
		"source_data": {"institution_id": &"eanna_household", "place_id": &"uruk", "pressure": 7}
	}
	_check(Pipeline.begin(world, pressure_opportunity, actor), "Pressure assignment begins")
	var pressure_id := StringName(pressure_opportunity.id)
	Pipeline.perform_action(world, actor, pressure_id, &"examine_records")
	Pipeline.perform_action(world, actor, pressure_id, &"reconcile_accounts")
	var drawdown := Pipeline.resolve(world, actor, pressure_id, &"pressure_drawdown")
	_check(bool(drawdown.get("success", false)), "Pressure drawdown verdict resolves")
	_check(world.get_resource(&"barley", "institution", "", &"eanna_household") == 65 and world.get_resource(&"labor", "institution", "", &"eanna_household") == 3, "Pressure drawdown spends 15 barley and 15 labor without stale stock overwrite")
	_check(int(world.institutions[&"eanna_household"].get("resource_pressure", -1)) == 0 and int(world.institutions[&"eanna_household"].get("local_opinion", 0)) == 2, "Drawdown clears pressure and improves local opinion")

	var falsify_opportunity := pressure_opportunity.duplicate(true)
	falsify_opportunity["id"] = &"pressure:falsify"
	falsify_opportunity["source_data"]["pressure"] = 7
	world.institutions[&"eanna_household"]["resource_pressure"] = 7
	_check(Pipeline.begin(world, falsify_opportunity, actor), "Falsification pressure assignment begins")
	var falsify_id := StringName(falsify_opportunity.id)
	Pipeline.perform_action(world, actor, falsify_id, &"examine_records")
	Pipeline.perform_action(world, actor, falsify_id, &"reconcile_accounts")
	var silver_before_falsify := int(actor.resources.get(&"silver", 0))
	var falsify := Pipeline.resolve(world, actor, falsify_id, &"pressure_falsify")
	_check(bool(falsify.get("success", false)), "Falsification verdict resolves")
	_check(actor.resources[&"silver"] == silver_before_falsify + 3 and int(actor.flags.get(&"audit_exposure", 0)) == 3, "Falsification grants three silver and two audit exposure")
	_check(world.has_flag(&"phantom_barley_measure", world.current_period_index()), "Falsification sets phantom barley trigger")
	var runner := EventRunnerScript.new()
	var context := EventContext.new()
	context.world = world
	context.actor = actor
	context.year = world.year
	context.era = EraDef.new()
	context.era.id = &"uruk_storehouse"
	context.era.era_tags = [&"uruk"]
	_check(runner.is_eligible(LedgerInquest, context), "Pliable scribe plus phantom barley flag makes Ledger Inquest eligible")

	var ration_opportunity := pressure_opportunity.duplicate(true)
	ration_opportunity["id"] = &"pressure:ration"
	world.institutions[&"eanna_household"]["resource_pressure"] = 7
	_check(Pipeline.begin(world, ration_opportunity, actor), "Strict rationing pressure assignment begins")
	var ration_id := StringName(ration_opportunity.id)
	Pipeline.perform_action(world, actor, ration_id, &"examine_records")
	Pipeline.perform_action(world, actor, ration_id, &"reconcile_accounts")
	var ration := Pipeline.resolve(world, actor, ration_id, &"pressure_ration")
	_check(bool(ration.get("success", false)), "Strict rationing verdict resolves")
	_check(world.has_flag(&"thirsty_diggers", world.current_period_index()) and int(world.institutions[&"eanna_household"].get("local_opinion", 0)) == -1, "Rationing leaves pressure, sets thirsty diggers, and lowers local opinion")
	_check(runner.is_eligible(SiltBreach, context), "Severe scribe plus thirsty diggers flag makes Silt Breach eligible")

	var silver_context := EventContext.new()
	silver_context.world = world
	silver_context.actor = actor
	silver_context.year = world.year
	var silver_condition: EventCondition
	for condition in Quayside.conditions:
		if condition.condition_type == &"resource_compare" and StringName(condition.parameters.get("resource", "")) == &"silver":
			silver_condition = condition
	_check(silver_condition != null, "Quayside challenge includes its personal silver condition")
	if silver_condition != null:
		actor.resources[&"silver"] = 3
		_check(not runner.conditions.evaluate(silver_condition, silver_context), "Three silver cannot pass the four-shekel condition")
		actor.resources[&"silver"] = 4
		_check(runner.conditions.evaluate(silver_condition, silver_context), "Four silver passes the Quayside affordability condition")

	if _failures.is_empty():
		print("PASS: %d Epic/Challenge circuit checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d Epic/Challenge circuit checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			printerr(" - " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)
