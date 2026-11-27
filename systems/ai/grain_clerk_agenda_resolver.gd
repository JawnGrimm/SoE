class_name GrainClerkAgendaResolver
extends RefCounted
## Resolves a seated grain clerk's intent against authoritative SoE state.
## LimboAI selects intent; this class validates and applies its consequences.

func resolve_intent(world: WorldState, clerk: PersonEntity, intent_id: StringName, institution_id: StringName = &"eanna_household") -> Dictionary:
	if world == null or clerk == null or not (clerk.office_id in [&"grain_clerk", &"granary_clerk", &"umma_granary_clerk"]):
		return {"success": false, "reason": "The grain-clerk intent has no valid office-holder."}
	match intent_id:
		&"intent_hide_spoilage":
			return _hide_spoilage(world, clerk, institution_id)
		&"intent_pocket_measures":
			return _pocket_measures(world, clerk, institution_id)
		&"intent_log_deliveries":
			return _log_deliveries(world, clerk, institution_id)
		_:
			push_warning("GrainClerkAgendaResolver: unknown intent '%s'" % intent_id)
			return {"success": false, "reason": "Unknown grain-clerk intent."}

func _hide_spoilage(world: WorldState, clerk: PersonEntity, institution_id: StringName) -> Dictionary:
	var place_id := StringName(world.institutions.get(institution_id, {}).get("place_id", ""))
	var has_roof_leak := false
	for hazard in world.hazards:
		if bool(hazard.get("active", false)) and (StringName(hazard.get("place_id", "")) == place_id or (institution_id == &"eanna_household" and StringName(hazard.get("place_id", "")) == &"north_bay")) and StringName(hazard.get("id", "")) == &"roof_leak":
			has_roof_leak = true
			break
	if not has_roof_leak:
		return {"success": false, "reason": "The local roof leak is no longer active."}
	if int(clerk.vulnerabilities.get(&"personal_fear", 0)) <= 5:
		return {"success": false, "reason": "Ur-Nanna's fear is not high enough to justify concealment."}
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	if bool(records.get("concealed_spoilage", false)):
		return {"success": false, "reason": "The false quality declaration is already on the record."}
	var physical_barley := world.get_resource(&"barley", "institution", "", institution_id)
	records["barley_quality_declaration"] = "prime_seed_corn"
	records["concealed_spoilage"] = true
	records["declared_at_period"] = world.current_period_index()
	records["physical_barley_at_declaration"] = physical_barley
	institution["stock_records"] = records
	_queue_docket(institution, world, &"intent_hide_spoilage", clerk.id, institution_id, {
		"dispatch_record": "Dispatch docket: barley declared as prime seed-corn.",
		"threshold_tally": "North-Bay threshold tally: damp barley; mold visible along the lower measures.",
		"discrepancy": "The dispatch certifies prime seed-corn while the independent threshold tally records damp, mold-marked grain.",
	})
	_record_intent(institution, world, &"intent_hide_spoilage")
	world.institutions[institution_id] = institution
	clerk.memory.append({
		"memory_id": &"grain_clerk_cover_up",
		"text": "I entered the North-Bay barley as prime seed-corn. The roof leak remains active.",
		"year": world.year,
		"involved": [place_id, &"roof_leak"]
	})
	return {"success": true, "intent_id": &"intent_hide_spoilage", "period": world.current_period_index()}

func _pocket_measures(world: WorldState, clerk: PersonEntity, institution_id: StringName) -> Dictionary:
	var barley := world.get_resource(&"barley", "institution", "", institution_id)
	var household_silver := world.get_resource(&"silver", "institution", "", institution_id)
	if barley <= 400 or household_silver >= 5:
		return {"success": false, "reason": "The surplus and household-debt conditions are no longer both true."}
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	if bool(records.get("intake_tally_falsified", false)):
		return {"success": false, "reason": "The two-measure intake discrepancy is already on the record."}
	records["intake_tally_adjustment"] = -2
	records["intake_tally_falsified"] = true
	records["intake_tally_falsified_period"] = world.current_period_index()
	institution["stock_records"] = records
	_queue_docket(institution, world, &"intent_pocket_measures", clerk.id, institution_id, {
		"dispatch_record": "Intake docket: the full delivered measure is certified.",
		"threshold_tally": "Independent receiving tally: two measures are absent from the clerk's entered total.",
		"discrepancy": "The intake record is short by two measures despite the dispatch certification.",
	})
	_record_intent(institution, world, &"intent_pocket_measures")
	world.institutions[institution_id] = institution
	clerk.memory.append({
		"memory_id": &"grain_clerk_skimming",
		"text": "I reduced the entered intake tally by two measures.",
		"year": world.year,
		"involved": [&"south_court_storehouse"]
	})
	return {"success": true, "intent_id": &"intent_pocket_measures", "period": world.current_period_index()}

func _log_deliveries(world: WorldState, _clerk: PersonEntity, institution_id: StringName) -> Dictionary:
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty():
		return {"success": false, "reason": "The Eanna institutional household is unavailable."}
	_record_intent(institution, world, &"intent_log_deliveries")
	world.institutions[institution_id] = institution
	return {"success": true, "intent_id": &"intent_log_deliveries", "period": world.current_period_index()}

func _queue_docket(institution: Dictionary, world: WorldState, intent_id: StringName, clerk_id: StringName, institution_id: StringName, evidence: Dictionary) -> void:
	var queue: Array = institution.get("npc_docket_queue", []).duplicate(true)
	queue.append({
		"due_period": world.current_period_index() + 1,
		"form_type": &"held_barley",
		"subject_id": &"north_bay" if institution_id == &"eanna_household" else StringName(institution.get("place_id", "north_bay")),
		"urgency": 3,
		"intent_id": intent_id,
		"clerk_id": clerk_id,
		"institution_id": institution_id,
		"npc_evidence": evidence.duplicate(true),
	})
	institution["npc_docket_queue"] = queue

func _record_intent(institution: Dictionary, world: WorldState, intent_id: StringName) -> void:
	institution["last_grain_clerk_agenda"] = {
		"intent_id": intent_id,
		"period": world.current_period_index(),
	}
	institution["agenda_history_count"] = int(institution.get("agenda_history_count", 0)) + 1
