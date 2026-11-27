class_name OfficeAgendaResolver
extends RefCounted
## Shared typed conditions and mutations. BT resources choose decision flow.

static func condition_passes(actor: PersonEntity, institution: Dictionary, world: WorldState, institution_id: StringName, condition_id: StringName) -> bool:
	var now := world.current_period_index()
	var stock: Dictionary = institution.get("stockpiles", {})
	var thresholds: Dictionary = institution.get("pressure_thresholds", {})
	var player := world.get_player()
	match condition_id:
		&"grain_roof_leak_active": return not _roof_hazard(world, institution_id).is_empty()
		&"grain_actor_fear_above_five": return int(actor.vulnerabilities.get(&"personal_fear", 0)) > 5
		&"grain_barley_above_400": return int(stock.get(&"barley", 0)) > 400
		&"grain_silver_below_five": return int(stock.get(&"silver", 0)) < 5
		&"grain_barley_below_warning": return int(stock.get(&"barley", 0)) < int(thresholds.get(&"barley_warn", 105))
		&"grain_shortage_docket_needed":
			var place_id := StringName(institution.get("place_id", institution_id))
			return not bool(institution.get("stock_records", {}).get("shortage_docket_issued", false)) and not world.has_pending_form(&"contradictory_grain_docket", place_id)
		&"canal_pressure_present": return int(institution.get("resource_pressure", 0)) > 0
		&"canal_labor_below_warning": return int(stock.get(&"labor", 0)) < int(thresholds.get(&"labor_warn", 7))
		&"canal_silt_hazard_active": return _silt_hazard(world, StringName(institution.get("place_id", "")))
		&"archive_audit_period_due": return now % 6 == 0 and (not institution.has("last_archive_audit_period") or now - int(institution.get("last_archive_audit_period", now)) >= 6)
		&"archive_audit_trigger_present":
			return player != null and (int(player.flags.get(&"audit_exposure", 0)) > 0 or &"pliable" in player.traits or world.has_flag(&"phantom_barley_measure", now))
		&"foreman_reaction_cooldown_ready": return not institution.has("last_foreman_reaction_period") or now - int(institution.get("last_foreman_reaction_period", now)) >= 3
		&"foreman_thirsty_diggers":
			var expiry := int(world.world_flags.get(&"thirsty_diggers", -100))
			return world.has_flag(&"thirsty_diggers", now) or expiry >= now - 1
		&"foreman_labor_below_warning": return int(stock.get(&"labor", world.get_resource(&"labor"))) < int(thresholds.get(&"labor_warn", 8))
		_:
			push_warning("OfficeAgendaResolver: unknown condition '%s'; fail closed" % condition_id)
			return false

static func execute_action(actor: PersonEntity, institution: Dictionary, world: WorldState, institution_id: StringName, action_id: StringName) -> bool:
	match action_id:
		&"grain_hide_spoilage": return _hide_spoilage(actor, world, institution_id)
		&"grain_pocket_measures": return _pocket_measures(actor, world, institution_id)
		&"grain_log_deliveries":
			_record_grain(world, institution, institution_id, actor, &"intent_log_deliveries")
			return true
		&"grain_issue_shortage_docket": return _shortage_docket(actor, world, institution_id)
		&"canal_request_requisition": return _requisition(actor, world, institution_id)
		&"archive_issue_reprimand": return _archive_reprimand(actor, institution, world, institution_id)
		&"foreman_disrupt_crew": return _foreman_disruption(actor, institution, world, institution_id)
		_:
			push_warning("OfficeAgendaResolver: unknown action '%s'; fail closed" % action_id)
			return false

static func _hide_spoilage(actor: PersonEntity, world: WorldState, institution_id: StringName) -> bool:
	var hazard := _roof_hazard(world, institution_id)
	if hazard.is_empty() or int(actor.vulnerabilities.get(&"personal_fear", 0)) <= 5: return false
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty(): return false
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	if bool(records.get("concealed_spoilage", false)): return false
	records["barley_quality_declaration"] = "prime_seed_corn"
	records["concealed_spoilage"] = true
	records["declared_at_period"] = world.current_period_index()
	records["physical_barley_at_declaration"] = int(institution.get("stockpiles", {}).get(&"barley", 0))
	institution["stock_records"] = records
	_queue_grain_docket(institution, world, actor, institution_id, &"intent_hide_spoilage", StringName(hazard.get("place_id", "")), {
		"dispatch_record": "Dispatch docket: barley declared as prime seed-corn.",
		"threshold_tally": "North-Bay threshold tally: damp barley; mold visible along the lower measures.",
		"discrepancy": "The dispatch certifies prime seed-corn while the independent threshold tally records damp, mold-marked grain."
	})
	_record_grain(world, institution, institution_id, actor, &"intent_hide_spoilage")
	actor.memory.append({"memory_id": &"grain_clerk_cover_up", "text": "I entered the North-Bay barley as prime seed-corn. The roof leak remains active.", "year": world.year, "involved": [StringName(hazard.get("place_id", "")), &"roof_leak"]})
	world.institutions[institution_id] = institution
	return true

static func _pocket_measures(actor: PersonEntity, world: WorldState, institution_id: StringName) -> bool:
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty(): return false
	var stock: Dictionary = institution.get("stockpiles", {})
	if int(stock.get(&"barley", 0)) <= 400 or int(stock.get(&"silver", 0)) >= 5: return false
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	if bool(records.get("intake_tally_falsified", false)): return false
	records["intake_tally_adjustment"] = -2
	records["intake_tally_falsified"] = true
	records["intake_tally_falsified_period"] = world.current_period_index()
	institution["stock_records"] = records
	var subject := &"north_bay" if institution_id == &"eanna_household" else StringName(institution.get("place_id", institution_id))
	_queue_grain_docket(institution, world, actor, institution_id, &"intent_pocket_measures", subject, {
		"dispatch_record": "Intake docket: the full delivered measure is certified.",
		"threshold_tally": "Independent receiving tally: two measures are absent from the clerk's entered total.",
		"discrepancy": "The intake record is short by two measures despite the dispatch certification."
	})
	_record_grain(world, institution, institution_id, actor, &"intent_pocket_measures")
	actor.memory.append({"memory_id": &"grain_clerk_skimming", "text": "I reduced the entered intake tally by two measures.", "year": world.year, "involved": [StringName(institution.get("place_id", institution_id))]})
	world.institutions[institution_id] = institution
	return true

static func _shortage_docket(actor: PersonEntity, world: WorldState, institution_id: StringName) -> bool:
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty(): return false
	var stock: Dictionary = institution.get("stockpiles", {})
	var thresholds: Dictionary = institution.get("pressure_thresholds", {})
	var barley := int(stock.get(&"barley", 0))
	var place_id := StringName(institution.get("place_id", institution_id))
	var records: Dictionary = institution.get("stock_records", {}).duplicate(true)
	if barley >= int(thresholds.get(&"barley_warn", 105)) or bool(records.get("shortage_docket_issued", false)) or world.has_pending_form(&"contradictory_grain_docket", place_id): return false
	records["shortage_docket_issued"] = true
	records["shortage_docket_period"] = world.current_period_index()
	institution["stock_records"] = records
	world.enqueue_form({"form_type": &"contradictory_grain_docket", "subject_id": place_id, "institution_id": institution_id, "urgency": 4, "year": world.year, "generated_by": actor.id, "generation_reason": &"local_granary_shortage", "generated_period": world.current_period_index(), "created_period": world.current_period_index(), "evidence": {"physical_barley": barley, "declared_status": "delivery_balance_pending"}})
	_record_grain(world, institution, institution_id, actor, &"grain_shortage_docket")
	_delta(world, "grain", "%s recorded a local barley discrepancy at %s (%d barley)" % [actor.display_name, String(institution.get("name", institution_id)), barley])
	world.institutions[institution_id] = institution
	return true

static func _requisition(actor: PersonEntity, world: WorldState, institution_id: StringName) -> bool:
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var place_id := StringName(institution.get("place_id", ""))
	var stock: Dictionary = institution.get("stockpiles", {})
	var pressure := int(institution.get("resource_pressure", 0))
	var labor := int(stock.get(&"labor", 0))
	var labor_warn := int(institution.get("pressure_thresholds", {}).get(&"labor_warn", 7))
	var silt := _silt_hazard(world, place_id)
	if pressure <= 0 and labor >= labor_warn and not silt: return false
	var now := world.current_period_index()
	var existing_index := _pending_form_index(world, &"bailiff_requisition", place_id)
	if existing_index >= 0:
		var existing: Dictionary = world.pending_forms[existing_index]
		var created := int(existing.get("generated_period", existing.get("created_period", now)))
		if now - created > 4:
			existing["urgency"] = maxi(8, int(existing.get("urgency", 2)))
			existing["priority"] = maxi(8, int(existing.get("priority", 0)))
			existing["agenda_escalated"] = true
			existing["generated_by"] = actor.id
			existing["dispatch_from"] = place_id
			world.pending_forms[existing_index] = existing
		return true
	world.enqueue_form({"form_type": &"bailiff_requisition", "subject_id": place_id, "institution_id": institution_id, "target_institution_id": _regional_granary(world, place_id, institution_id), "urgency": 3, "priority": 7, "year": world.year, "generated_by": actor.id, "generation_reason": &"canal_pressure_requisition", "generated_period": now, "created_period": now, "resource_pressure": pressure, "local_labor": labor, "canal_silt_hazard": silt})
	var updated: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	updated["last_bailiff_requisition_period"] = now
	world.institutions[institution_id] = updated
	_delta(world, "requisition", "%s petitioned for canal labor and provisions at %s" % [actor.display_name, String(institution.get("name", institution_id))])
	return true

static func _archive_reprimand(actor: PersonEntity, institution: Dictionary, world: WorldState, institution_id: StringName) -> bool:
	var player := world.get_player()
	if player == null: return false
	var now := world.current_period_index()
	var exposure := int(player.flags.get(&"audit_exposure", 0))
	var trigger := exposure > 0 or &"pliable" in player.traits or world.has_flag(&"phantom_barley_measure", now)
	if now % 6 != 0 or now - int(institution.get("last_archive_audit_period", -100)) < 6 or not trigger: return false
	var updated: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	updated["last_archive_audit_period"] = now
	if exposure > 0: player.flags[&"audit_exposure"] = exposure - 1
	var silver := int(player.resources.get(&"silver", 0))
	if silver >= 2:
		player.resources[&"silver"] = silver - 2
	else:
		player.flags[&"audit_debt"] = int(player.flags.get(&"audit_debt", 0)) + 2 - silver
		player.resources[&"silver"] = 0
	actor.change_opinion(player.id, -2, "A concealed account was found in the archive audit.", world.year)
	var disposition := "fine" if silver >= 2 else "debt"
	_delta(world, "audit", "Archive reprimand: -2 silver %s to %s" % [disposition, actor.display_name])
	world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "ARCHIVE REPRIMAND", "summary": "%s found a concealed account. Two silver were fined or entered as debt." % actor.display_name, "official_id": actor.id})
	world.institutions[institution_id] = updated
	return true

static func _foreman_disruption(actor: PersonEntity, institution: Dictionary, world: WorldState, institution_id: StringName) -> bool:
	var stock: Dictionary = institution.get("stockpiles", {})
	var thresholds: Dictionary = institution.get("pressure_thresholds", {})
	var labor := int(stock.get(&"labor", world.get_resource(&"labor")))
	var labor_warn := int(thresholds.get(&"labor_warn", 8))
	var now := world.current_period_index()
	var expiry := int(world.world_flags.get(&"thirsty_diggers", -100))
	var thirsty := world.has_flag(&"thirsty_diggers", now) or expiry >= now - 1
	if (not thirsty and labor >= labor_warn) or now - int(institution.get("last_foreman_reaction_period", -100)) < 3: return false
	var player := world.get_player()
	if player != null: actor.change_opinion(player.id, -1, "The canal crew lacks provisions or workable labor.", world.year)
	world.set_flag(&"canal_crew_slowdown", now + 2)
	var epic_id := world.get_active_epic_id()
	if epic_id != &"" and world.epics.has(epic_id):
		var state: Dictionary = world.epics[epic_id]
		state["crew_disruption"] = true
		state["crew_disruption_period"] = now
		world.epics[epic_id] = state
	_delta(world, "crew", "%s reports crew unrest; canal work faces disruption" % actor.display_name)
	var updated: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	updated["last_foreman_reaction_period"] = now
	world.institutions[institution_id] = updated
	return true

static func _record_grain(world: WorldState, institution: Dictionary, institution_id: StringName, actor: PersonEntity, intent_id: StringName) -> void:
	institution["last_grain_clerk_agenda"] = {"intent_id": intent_id, "official_id": actor.id, "period": world.current_period_index()}
	institution["agenda_history_count"] = int(institution.get("agenda_history_count", 0)) + 1
	world.institutions[institution_id] = institution

static func _queue_grain_docket(institution: Dictionary, world: WorldState, actor: PersonEntity, institution_id: StringName, intent_id: StringName, subject_id: StringName, evidence: Dictionary) -> void:
	var queue: Array = institution.get("npc_docket_queue", []).duplicate(true)
	queue.append({"due_period": world.current_period_index() + 1, "form_type": &"held_barley", "subject_id": subject_id, "urgency": 3, "intent_id": intent_id, "clerk_id": actor.id, "institution_id": institution_id, "npc_evidence": evidence.duplicate(true)})
	institution["npc_docket_queue"] = queue

static func _roof_hazard(world: WorldState, institution_id: StringName) -> Dictionary:
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var place_id := StringName(institution.get("place_id", ""))
	for hazard in world.hazards:
		if not bool(hazard.get("active", false)) or StringName(hazard.get("id", "")) != &"roof_leak": continue
		if StringName(hazard.get("institution_id", "")) == institution_id or StringName(hazard.get("place_id", "")) == place_id: return hazard
	return {}

static func _silt_hazard(world: WorldState, place_id: StringName) -> bool:
	for hazard in world.hazards:
		if not bool(hazard.get("active", false)) or not String(hazard.get("id", "")).to_lower().contains("silt"): continue
		var hazard_place := StringName(hazard.get("place_id", ""))
		if hazard_place == place_id or _is_parent(world, hazard_place, place_id) or _is_parent(world, place_id, hazard_place): return true
	return false

static func _regional_granary(world: WorldState, place_id: StringName, fallback: StringName) -> StringName:
	for key in world.institutions.keys():
		var institution: Dictionary = world.institutions[key]
		if String(institution.get("institution_type", institution.get("kind", ""))).contains("granary"):
			var candidate_place := StringName(institution.get("place_id", ""))
			if candidate_place == place_id or _is_parent(world, candidate_place, place_id) or _is_parent(world, place_id, candidate_place): return StringName(key)
	return fallback

static func _is_parent(world: WorldState, child_id: StringName, parent_id: StringName) -> bool:
	return StringName(world.places.get(child_id, {}).get("parent", "")) == parent_id

static func _pending_form_index(world: WorldState, form_type: StringName, subject_id: StringName) -> int:
	for i in range(world.pending_forms.size()):
		var form: Dictionary = world.pending_forms[i]
		if StringName(form.get("form_type", "")) == form_type and StringName(form.get("subject_id", "")) == subject_id: return i
	return -1

static func _delta(world: WorldState, category: String, text: String) -> void:
	world.last_period_deltas.append({"category": category, "text": text})
	while world.last_period_deltas.size() > 12: world.last_period_deltas.pop_front()
