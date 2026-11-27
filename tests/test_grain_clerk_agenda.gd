extends SceneTree

var checks := 0
var failures: Array[String] = []

const UrukSeederScript = preload("res://systems/uruk_seeder.gd")
const WorldSimulatorScript = preload("res://systems/world_simulator.gd")
const AssignmentPipelineScript = preload("res://systems/assignment_pipeline.gd")
const RegistryScript = preload("res://systems/definition_registry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := RegistryScript.new()
	registry.load_defaults()
	var world := WorldState.new()
	UrukSeederScript.seed_campaign(world, 32003200, true, registry)
	var initial_institution: Dictionary = world.institutions[&"eanna_household"]
	var initial_stock: Dictionary = initial_institution.get("stockpiles", {})
	initial_stock[&"silver"] = 2 # Make both emergency and skimming branches eligible; selector priority must win.
	initial_stock[&"barley"] = 500
	initial_institution["stockpiles"] = initial_stock
	world.institutions[&"eanna_household"] = initial_institution
	var clerk := world.get_person(&"ur_nanna")
	_check(clerk != null and clerk.office_id == &"grain_clerk", "Ur-Nanna is the one seeded grain clerk")
	_check(int(clerk.vulnerabilities.get(&"personal_fear", 0)) > 5, "Ur-Nanna's seeded fear is above the emergency threshold")
	_check(world.has_active_hazard(&"north_bay", &"roof_leak"), "The canonical North-Bay roof leak is active")

	var simulator := WorldSimulatorScript.new(registry)
	simulator.advance_period(world)
	var institution: Dictionary = world.institutions.get(&"eanna_household", {})
	var agenda: Dictionary = institution.get("last_grain_clerk_agenda", {})
	_check(StringName(agenda.get("intent_id", "")) == &"intent_hide_spoilage", "The Selector chooses Emergency Cover-Up before lower-priority intents")
	var records: Dictionary = institution.get("stock_records", {})
	_check(bool(records.get("concealed_spoilage", false)) and String(records.get("barley_quality_declaration", "")) == "prime_seed_corn", "SoE resolution records the falsified prime-seed-corn declaration")
	var queue: Array = institution.get("npc_docket_queue", [])
	_check(queue.size() == 1 and int(queue[0].get("due_period", -1)) == world.current_period_index() + 1, "The secret action queues its evidence for the following period")
	var generic_form_found := false
	for form in world.pending_forms:
		if StringName(form.get("form_type", "")) == &"held_barley":
			generic_form_found = true
			_check(not form.has("npc_evidence"), "The contradictory docket is not exposed in the same period as the secret act")
	_check(generic_form_found, "The ordinary roof inspection form remains generated from the active hazard")

	simulator.advance_period(world)
	institution = world.institutions.get(&"eanna_household", {})
	var delivered_queue: Array = institution.get("npc_docket_queue", [])
	_check(delivered_queue.size() == 1 and int(delivered_queue[0].get("due_period", -1)) == world.current_period_index() + 1, "The previous docket is delivered while this period's new cover-up queues evidence for next period")
	var evidence_form: Dictionary = {}
	for form in world.pending_forms:
		if form.has("npc_evidence"):
			evidence_form = form
			break
	_check(not evidence_form.is_empty(), "The autonomous cover-up produces a player-facing pending docket")
	var opportunities := AssignmentPipelineScript.generate_opportunities(world, world.get_player(), &"path_civil")
	var evidence_opportunity: Dictionary = {}
	for opportunity in opportunities:
		var opportunity_source: Dictionary = opportunity.get("source_data", {})
		if opportunity_source.has("npc_evidence"):
			evidence_opportunity = opportunity
			break
	_check(not evidence_opportunity.is_empty(), "The contradictory docket enters the existing assignment board")
	if not evidence_opportunity.is_empty():
		_check(String(evidence_opportunity.get("title", "")).contains("Contradictory"), "The desk labels the NPC-generated record conflict")
		_check(String(evidence_opportunity.get("summary", "")).contains("prime seed-corn") and String(evidence_opportunity.get("summary", "")).contains("damp"), "The opportunity preview exposes the conflict without inventing a new UI")
		var player := world.get_player()
		_check(AssignmentPipelineScript.begin(world, evidence_opportunity, player), "The player can open the autonomous docket through the normal assignment lifecycle")
		var assignment_id := StringName(evidence_opportunity.get("id", ""))
		var consult_result := AssignmentPipelineScript.perform_action(world, player, assignment_id, &"consult_official")
		var consult_facts := String(consult_result.get("evidence", {}).get("facts", ""))
		_check(bool(consult_result.get("success", false)) and consult_facts.contains("STANCE:") and not consult_facts.get_slice("STANCE:", 1).strip_edges().is_empty(), "Consult Official returns a non-empty in-character stance quote")
		var evidence_result := AssignmentPipelineScript.perform_action(world, player, assignment_id, &"examine_records")
		var evidence: Dictionary = evidence_result.get("evidence", {})
		var facts := String(evidence.get("facts", ""))
		_check(bool(evidence_result.get("success", false)) and facts.contains("DISPATCH DOCKET") and facts.contains("THRESHOLD TALLY") and facts.contains("DISCREPANCY"), "Investigating the docket reveals both conflicting records and their discrepancy")
		var opinion_before_referral := clerk.get_opinion(player.id)
		var referral := AssignmentPipelineScript.resolve(world, player, assignment_id, &"refer")
		var corrected_records: Dictionary = world.institutions.get(&"eanna_household", {}).get("stock_records", {})
		_check(bool(evidence_result.get("success", false)) and bool(referral.get("success", false)), "Two inquiries permit a formal cover-up referral")
		_check(not bool(corrected_records.get("concealed_spoilage", true)) and not corrected_records.has("barley_quality_declaration"), "Referring Ur-Nanna clears the concealed spoilage declaration")
		_check(clerk.get_opinion(player.id) == opinion_before_referral - 3 and world.get_person(&"shuruppak_ilu").get_opinion(player.id) >= 2, "Referral costs Ur-Nanna three opinion and earns archive standing")
	_check(int(institution.get("agenda_evaluation_count", 0)) == 2, "Ur-Nanna's tree is evaluated exactly once on each of two period advances")

	# Rubber-stamping the same kind of concealed docket pays more and creates audit exposure.
	var certify_world := WorldState.new()
	UrukSeederScript.seed_campaign(certify_world, 32003299, true, registry)
	var certify_actor := certify_world.get_player()
	var certify_institution: Dictionary = certify_world.institutions[&"eanna_household"]
	var certify_records: Dictionary = certify_institution.get("stock_records", {})
	certify_records[&"concealed_spoilage"] = true
	certify_records[&"barley_quality_declaration"] = "prime_seed_corn"
	certify_institution["stock_records"] = certify_records
	certify_world.institutions[&"eanna_household"] = certify_institution
	certify_world.enqueue_form({"id": &"test_coverup_certification", "form_type": &"held_barley", "subject_id": &"north_bay", "institution_id": &"eanna_household", "urgency": 4, "npc_evidence": {"dispatch_record": "Prime seed-corn.", "threshold_tally": "Damp and mold-marked.", "discrepancy": "Quality conflict."}})
	var certify_opportunity: Dictionary = {}
	for candidate in AssignmentPipelineScript.generate_opportunities(certify_world, certify_actor):
		if StringName(candidate.get("kind", "")) == &"form" and candidate.get("source_data", {}).has("npc_evidence"):
			certify_opportunity = candidate
			break
	_check(not certify_opportunity.is_empty(), "Concealed spoilage creates a certifiable contradictory docket")
	var certify_id := StringName(certify_opportunity.get("id", ""))
	var certify_silver_before := int(certify_actor.resources.get(&"silver", 0))
	var certify_opinion_before := certify_world.get_person(&"ur_nanna").get_opinion(certify_actor.id)
	_check(AssignmentPipelineScript.begin(certify_world, certify_opportunity, certify_actor), "Certification fixture begins")
	AssignmentPipelineScript.perform_action(certify_world, certify_actor, certify_id, &"examine_records")
	AssignmentPipelineScript.perform_action(certify_world, certify_actor, certify_id, &"reconcile_accounts")
	var certification := AssignmentPipelineScript.resolve(certify_world, certify_actor, certify_id, &"certify")
	_check(bool(certification.get("success", false)) and int(certify_actor.resources.get(&"silver", 0)) - certify_silver_before == 4, "Certifying the cover-up pays the four-silver gratuity")
	_check(int(certify_actor.flags.get(&"audit_exposure", 0)) == 1 and certify_world.get_person(&"ur_nanna").get_opinion(certify_actor.id) == certify_opinion_before + 2, "Certification pleases Ur-Nanna and records audit exposure")
	_check(bool(certify_world.institutions.get(&"eanna_household", {}).get("stock_records", {}).get("concealed_spoilage", false)), "Certification leaves the concealed spoilage unresolved")

	# Sub-places under Uruk inherit the Eanna household ownership and employer.
	var worksite_world := WorldState.new()
	UrukSeederScript.seed_campaign(worksite_world, 32003300, true, registry)
	worksite_world.enqueue_form({"id": &"ditch_tally_owner_test", "form_type": &"pension_roll", "subject_id": &"ditch_labor_tally", "urgency": 2})
	var worksite_opportunity: Dictionary = {}
	for candidate in AssignmentPipelineScript.generate_opportunities(worksite_world, worksite_world.get_player()):
		if StringName(candidate.get("source_id", "")) == &"ditch_tally_owner_test":
			worksite_opportunity = candidate
			break
	_check(StringName(worksite_opportunity.get("source_data", {}).get("institution_id", "")) == &"eanna_household" and StringName(worksite_opportunity.get("employer_id", "")) != &"", "Ditch labor tally resolves a valid Eanna institution and named employer")

	var skim_world := WorldState.new()
	UrukSeederScript.seed_campaign(skim_world, 32003201, true, registry)
	skim_world.repair_hazard(&"north_bay", &"roof_leak")
	var skim_institution: Dictionary = skim_world.institutions[&"eanna_household"]
	var skim_stock: Dictionary = skim_institution.get("stockpiles", {})
	skim_stock[&"silver"] = 2
	skim_stock[&"barley"] = 450
	skim_institution["stockpiles"] = skim_stock
	skim_world.institutions[&"eanna_household"] = skim_institution
	WorldSimulatorScript.new(registry).advance_period(skim_world)
	skim_institution = skim_world.institutions[&"eanna_household"]
	_check(StringName(skim_institution.get("last_grain_clerk_agenda", {}).get("intent_id", "")) == &"intent_pocket_measures", "With the leak absent, surplus and household debt select the two-measure skimming intent")
	_check(int(skim_institution.get("stock_records", {}).get("intake_tally_adjustment", 0)) == -2, "The skimming intent falsifies the intake record by two measures")

	var routine_world := WorldState.new()
	UrukSeederScript.seed_campaign(routine_world, 32003202, true, registry)
	routine_world.repair_hazard(&"north_bay", &"roof_leak")
	var routine_institution: Dictionary = routine_world.institutions[&"eanna_household"]
	var routine_stock: Dictionary = routine_institution.get("stockpiles", {})
	routine_stock[&"barley"] = 100
	routine_stock[&"silver"] = 10
	routine_institution["stockpiles"] = routine_stock
	routine_world.institutions[&"eanna_household"] = routine_institution
	WorldSimulatorScript.new(registry).advance_period(routine_world)
	routine_institution = routine_world.institutions[&"eanna_household"]
	_check(StringName(routine_institution.get("last_grain_clerk_agenda", {}).get("intent_id", "")) == &"intent_log_deliveries", "Routine Custody is the default when neither emergency nor skimming conditions pass")

	print("Grain clerk agenda: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
