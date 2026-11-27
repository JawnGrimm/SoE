class_name GrainClerkAgendaResolver
extends RefCounted
## Resolves Ur-Nanna's intent against authoritative SoE state.
## LimboAI selects intent; this class validates and applies its consequences.

const INSTITUTION_ID: StringName = &"eanna_household"
const CLERK_ID: StringName = &"ur_nanna"

func resolve_intent(world: WorldState, clerk: PersonEntity, intent_id: StringName) -> Dictionary:
	if world == null or clerk == null or clerk.id != CLERK_ID or clerk.office_id != &"grain_clerk":
		return {"success": false, "reason": "The grain-clerk intent has no valid office-holder."}
	match intent_id:
		&"intent_hide_spoilage":
			return _hide_spoilage(world, clerk)
		&"intent_pocket_measures":
			return _pocket_measures(world, clerk)
		&"intent_log_deliveries":
			return _log_deliveries(world, clerk)
		_:
			push_warning("GrainClerkAgendaResolver: unknown intent '%s'" % intent_id)
			return {"success": false, "reason": "Unknown grain-clerk intent."}

func _hide_spoilage(world: WorldState, clerk: PersonEntity) -> Dictionary:
	if not world.has_active_hazard(&"north_bay", &"roof_leak"):
		return {"success": false, "reason": "The North-Bay roof leak is no longer active."}
	if int(clerk.vulnerabilities.get(&"personal_fear", 0)) <= 5:
		return {"success": false, "reason": "Ur-Nanna's fear is not high enough to justify concealment."}
	var institution: Dictionary = world.institutions.get(INSTITUTION_ID, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	var physical_barley := world.get_resource(&"barley", "institution", "", INSTITUTION_ID)
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	records["barley_quality_declaration"] = "prime_seed_corn"
	records["concealed_spoilage"] = true
	records["declared_at_period"] = world.current_period_index()
	records["physical_barley_at_declaration"] = physical_barley
	institution["stock_records"] = records
	_queue_docket(institution, world, &"intent_hide_spoilage", {
		"dispatch_record": "Dispatch docket: barley declared as prime seed-corn.",
		"threshold_tally": "North-Bay threshold tally: damp barley; mold visible along the lower measures.",
		"discrepancy": "The dispatch certifies prime seed-corn while the independent threshold tally records damp, mold-marked grain.",
	})
	_record_intent(institution, world, &"intent_hide_spoilage")
	world.institutions[INSTITUTION_ID] = institution
	clerk.memory.append({
		"memory_id": &"grain_clerk_cover_up",
		"text": "I entered the North-Bay barley as prime seed-corn. The roof leak remains active.",
		"year": world.year,
		"involved": [&"north_bay", &"roof_leak"]
	})
	return {"success": true, "intent_id": intent_id, "period": world.current_period_index()}

func _pocket_measures(world: WorldState, clerk: PersonEntity) -> Dictionary:
	var barley := world.get_resource(&"barley", "institution", "", INSTITUTION_ID)
	var household_silver := world.get_resource(&"silver", "institution", "", INSTITUTION_ID)
	if barley <= 400 or household_silver >= 5:
		return {"success": false, "reason": "The surplus and household-debt conditions are no longer both true."}
	var institution: Dictionary = world.institutions.get(INSTITUTION_ID, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	records["intake_tally_adjustment"] = -2
	records["intake_tally_falsified"] = true
	records["intake_tally_falsified_period"] = world.current_period_index()
	institution["stock_records"] = records
	_queue_docket(institution, world, &"intent_pocket_measures", {
		"dispatch_record": "Intake docket: the full delivered measure is certified.",
		"threshold_tally": "Independent receiving tally: two measures are absent from the clerk's entered total.",
		"discrepancy": "The intake record is short by two measures despite the dispatch certification.",
	})
	_record_intent(institution, world, &"intent_pocket_measures")
	world.institutions[INSTITUTION_ID] = institution
	clerk.memory.append({
		"memory_id": &"grain_clerk_skimming",
		"text": "I reduced the entered intake tally by two measures.",
		"year": world.year,
		"involved": [&"south_court_storehouse"]
	})
	return {"success": true, "intent_id": intent_id, "period": world.current_period_index()}

func _log_deliveries(world: WorldState, clerk: PersonEntity) -> Dictionary:
	var institution: Dictionary = world.institutions.get(INSTITUTION_ID, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	_record_intent(institution, world, &"intent_log_deliveries")
	world.institutions[INSTITUTION_ID] = institution
	return {"success": true, "intent_id": &"intent_log_deliveries", "period": world.current_period_index()}

func _queue_docket(institution: Dictionary, world: WorldState, intent_id: StringName, evidence: Dictionary) -> void:
	var queue: Array = institution.get("npc_docket_queue", []).duplicate(true)
	queue.append({
		"due_period": world.current_period_index() + 1,
		"form_type": &"held_barley",
		"subject_id": &"north_bay",
		"urgency": 3,
		"intent_id": intent_id,
		"npc_evidence": evidence.duplicate(true),
	})
	institution["npc_docket_queue"] = queue

func _record_intent(institution: Dictionary, world: WorldState, intent_id: StringName) -> void:
	institution["last_grain_clerk_agenda"] = {
		"intent_id": intent_id,
		"period": world.current_period_index(),
	}
	institution["agenda_history_count"] = int(institution.get("agenda_history_count", 0)) + 1
