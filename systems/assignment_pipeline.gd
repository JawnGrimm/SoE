class_name AssignmentPipeline
extends RefCounted
## Converts persistent world conditions into professional opportunities.
## It never invents economic quantities: all facts are read from WorldState.

const BOARD_SIZE := 3
const INVESTIGATION_ACTIONS := [
	{"id": &"examine_records", "label": "Examine the written record", "skill": &"literacy", "xp": 8},
	{"id": &"reconcile_accounts", "label": "Reconcile the figures", "skill": &"arithmetic", "xp": 8},
	{"id": &"consult_official", "label": "Consult the responsible official", "skill": &"rhetoric", "xp": 8},
	{"id": &"inspect_source", "label": "Inspect the goods, stores, or site", "skill": &"stewardship", "xp": 8}
]


const REMOTE_DISPATCH_ACTIONS := [
	{"id": &"inspect_seal", "label": "Examine the shipment seal", "skill": &"literacy", "xp": 8},
	{"id": &"compare_manifest", "label": "Compare manifest and received cargo", "skill": &"arithmetic", "xp": 8},
	{"id": &"question_carrier", "label": "Question the carrier", "skill": &"rhetoric", "xp": 8},
	{"id": &"inspect_cargo", "label": "Inspect the cargo at landing", "skill": &"stewardship", "xp": 8}
]
const ORIGIN_REPLY_ACTIONS := [
	{"id": &"examine_origin_copy", "label": "Read the origin-side copy", "skill": &"literacy", "xp": 8},
	{"id": &"compare_origin_copy", "label": "Compare origin and arrival accounts", "skill": &"arithmetic", "xp": 8},
	{"id": &"question_carrier", "label": "Question the carrier again", "skill": &"rhetoric", "xp": 8},
	{"id": &"inspect_seal", "label": "Recheck the seal against the copy", "skill": &"intrigue", "xp": 8}
]


const REGIONAL_WORK_ACTIONS := [
	{"id": &"review_trade_manifest", "label": "Review the trade manifest", "skill": &"literacy", "xp": 8},
	{"id": &"compare_trade_balance", "label": "Compare the trade balance", "skill": &"arithmetic", "xp": 8},
	{"id": &"consult_local_factor", "label": "Consult the local trade factor", "skill": &"rhetoric", "xp": 8},
	{"id": &"inspect_trade_goods", "label": "Inspect the goods and seals", "skill": &"stewardship", "xp": 8}
]

static func get_actions(record: Dictionary) -> Array:
	var data: Dictionary = record.get("source_data", {})
	if StringName(record.get("kind", "")) == &"regional_work":
		return REGIONAL_WORK_ACTIONS
	var form_type := StringName(data.get("form_type", ""))
	if StringName(record.get("kind", "")) == &"form" and form_type == &"remote_dispatch":
		return REMOTE_DISPATCH_ACTIONS
	if StringName(record.get("kind", "")) == &"form" and form_type == &"remote_origin_reply":
		return ORIGIN_REPLY_ACTIONS
	return INVESTIGATION_ACTIONS

static func generate_opportunities(world: WorldState, actor: PersonEntity, selected_path: StringName = &"") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if world == null or actor == null:
		return candidates

	for form in world.pending_forms:
		if bool(form.get("tutorial_only", false)):
			continue
		var form_id := StringName(form.get("id", ""))
		if form_id == &"":
			continue
		var form_type := StringName(form.get("form_type", ""))
		if int(form.get("due_period", world.current_period_index())) > world.current_period_index():
			continue
		if form_type != &"remote_origin_reply" and not _is_local_to_actor(world, actor, StringName(form.get("subject_id", ""))):
			continue
		var subject_id := StringName(form.get("subject_id", ""))
		var subject_name := _place_name(world, subject_id)
		var urgency := int(form.get("urgency", 1))
		var overdue := String(form.get("status", "pending")) == "overdue"
		candidates.append({
			"id": StringName("work_form_%s_%d" % [form_id, world.current_period_index()]),
			"kind": &"form",
			"source_id": form_id,
			"title": _form_title(form_type),
			"summary": _form_summary(world, form),
			"priority": urgency + (3 if overdue else 0) + _career_bonus(selected_path, form_type),
			"employer_id": StringName(form.get("sender_id", form.get("employer_id", _form_employer(world, form_type)))),
			"source_data": form.duplicate(true),
			"path_id": selected_path
		})

	for hazard in world.hazards:
		if not bool(hazard.get("active", false)):
			continue
		var hazard_id := StringName(hazard.get("id", ""))
		var place_id := StringName(hazard.get("place_id", ""))
		if not _is_local_to_actor(world, actor, place_id):
			continue
		candidates.append({
			"id": StringName("work_hazard_%s_%d" % [hazard_id, world.current_period_index()]),
			"kind": &"hazard",
			"source_id": hazard_id,
			"title": "Inspect %s" % _place_name(world, place_id),
			"summary": "An active %s continues to damage institutional stores." % String(hazard_id).replace("_", " "),
			"priority": 4 + int(hazard.get("rate", 0)) + _career_bonus(selected_path, &"hazard"),
			"employer_id": &"ur_nanna" if world.get_person(&"ur_nanna") != null else &"",
			"source_data": hazard.duplicate(true),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var pressure := int(institution.get("resource_pressure", 0))
		if not _is_local_to_actor(world, actor, StringName(institution.get("place_id", ""))):
			continue
		if pressure < 1:
			continue
		candidates.append({
			"id": StringName("work_pressure_%s_%d" % [institution_id, world.current_period_index()]),
			"kind": &"pressure",
			"source_id": StringName(institution_id),
			"title": "%s / Resource Pressure" % String(institution.get("name", institution_id)),
			"summary": "The institution reports a pressure index of %d. Its current stockpiles need review." % pressure,
			"priority": 2 + pressure + _career_bonus(selected_path, &"pressure"),
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": {"institution_id": StringName(institution_id), "pressure": pressure},
			"path_id": selected_path
		})

	# Routine reconciliation is real work against each institution's actual
	# membership, activity, and resource records—not a fabricated dispute.
	for epic_id in world.epics.keys():
		var epic: Dictionary = world.epics[epic_id]
		if not bool(epic.get("active", false)) or bool(epic.get("completed", false)):
			continue
		var progress := world.get_resource(StringName(epic.get("progress_resource", "")))
		var target := int(epic.get("target", 100))
		var sponsor_id := StringName(epic.get("sponsor_institution", ""))
		var sponsor_place := StringName(world.institutions.get(sponsor_id, {}).get("place_id", &"uruk"))
		if not _is_local_to_actor(world, actor, sponsor_place):
			continue
		if target <= 0 or progress >= target:
			continue
		candidates.append({
			"id": StringName("work_project_%s_%d" % [epic_id, world.current_period_index()]),
			"kind": &"project_review",
			"source_id": StringName(epic_id),
			"title": "%s / Progress Review" % String(epic.get("title", epic_id)),
			"summary": "The active public work stands at %d of %d. Its current labor and provisioning position requires review." % [progress, target],
			"priority": 2 + _career_bonus(selected_path, &"project"),
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": epic.duplicate(true),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		if not _is_local_to_actor(world, actor, StringName(institution.get("place_id", ""))):
			continue
		var routine_id := StringName("work_ledger_%s_%d" % [institution_id, world.current_period_index()])
		candidates.append({
			"id": routine_id,
			"kind": &"ledger",
			"source_id": StringName(institution_id),
			"title": "%s / Periodic Account" % String(institution.get("name", institution_id)),
			"summary": "Reconcile the institution's current membership, activity, and resource records.",
			"priority": (2 if StringName(institution_id) == &"eanna_household" else 1) + _career_bonus(selected_path, &"ledger"),
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": {"institution_id": StringName(institution_id), "member_count": institution.get("members", []).size(), "activity_count": int(institution.get("activity_count", 0))},
			"path_id": selected_path
		})


	# Regional work comes from actual place exports/imports, local stockpiles,
	# and active route connections. The same generator works at every trade post.
	var actor_place_id := actor.current_location_id if actor.current_location_id != &"" else &"uruk"
	var local_institution_id := _regional_institution_for_place(world, actor_place_id)
	var local_institution: Dictionary = world.institutions.get(local_institution_id, {})
	var local_stock: Dictionary = local_institution.get("stockpiles", {})
	var local_place: Dictionary = world.places.get(actor_place_id, {})
	var local_factor_id := StringName(local_place.get("regional_agent_id", &"geme_inana"))
	if actor_place_id == &"uruk":
		local_factor_id = &"geme_inana"
	if not local_institution.is_empty() and not local_place.is_empty():
		var exports: Array = local_place.get("exports", [])
		for commodity_variant in exports:
			var export_commodity := StringName(commodity_variant)
			var export_quantity := mini(12, int(local_stock.get(export_commodity, 0)))
			if export_quantity < 3:
				continue
			var export_destination := _find_importing_destination(world, actor_place_id, export_commodity)
			if export_destination == &"":
				continue
			var export_destination_institution := _regional_institution_for_place(world, export_destination)
			if export_destination_institution == &"":
				continue
			candidates.append(_regional_work_candidate(world, selected_path, actor_place_id, local_institution_id, local_factor_id, &"dispatch_export", export_commodity, export_quantity, actor_place_id, export_destination, local_institution_id, export_destination_institution, &""))
			break
		var imports: Array = local_place.get("imports", [])
		var import_candidates := 0
		for commodity_variant in imports:
			var import_commodity := StringName(commodity_variant)
			var source_info := _find_exporting_source(world, actor_place_id, import_commodity)
			if source_info.is_empty():
				continue
			var source_place_id := StringName(source_info.get("place_id", ""))
			var source_institution_id := StringName(source_info.get("institution_id", ""))
			var source_stock: Dictionary = world.institutions.get(source_institution_id, {}).get("stockpiles", {})
			var import_quantity := mini(8, int(source_stock.get(import_commodity, 0)))
			if import_quantity < 3:
				continue
			candidates.append(_regional_work_candidate(world, selected_path, actor_place_id, local_institution_id, local_factor_id, &"request_import", import_commodity, import_quantity, source_place_id, actor_place_id, source_institution_id, local_institution_id, &""))
			import_candidates += 1
			if import_candidates >= 3:
				break
		var provision_route_id := _highest_risk_route(world, actor_place_id)
		var beer_quantity := mini(4, int(local_stock.get(&"beer", 0)))
		if provision_route_id != &"" and beer_quantity >= 2:
			candidates.append(_regional_work_candidate(world, selected_path, actor_place_id, local_institution_id, local_factor_id, &"route_provisions", &"beer", beer_quantity, actor_place_id, StringName(world.routes[provision_route_id].get("to_place_id", "")), local_institution_id, &"", provision_route_id))

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var result: Array[Dictionary] = []
	var used_kinds: Dictionary = {}
	for candidate in candidates:
		var kind := StringName(candidate.get("kind", ""))
		# Prefer three different kinds of work when the world offers them.
		if used_kinds.has(kind) and result.size() < BOARD_SIZE:
			continue
		result.append(candidate.duplicate(true))
		used_kinds[kind] = true
		if result.size() >= BOARD_SIZE:
			break
	if result.size() < BOARD_SIZE:
		for candidate in candidates:
			if candidate not in result:
				result.append(candidate.duplicate(true))
				if result.size() >= BOARD_SIZE:
					break
	return result

static func begin(world: WorldState, opportunity: Dictionary, actor: PersonEntity) -> bool:
	if world == null or actor == null or opportunity.is_empty():
		return false
	var assignment_id := StringName(opportunity.get("id", ""))
	if assignment_id == &"" or world.assignments.has(assignment_id):
		return false
	var record := opportunity.duplicate(true)
	record["status"] = "active"
	record["actor_id"] = actor.id
	record["started_period"] = world.current_period_index()
	record["actions"] = {}
	record["evidence"] = {}
	record["assessment"] = ""
	world.assignments[assignment_id] = record
	return true

static func get_record(world: WorldState, assignment_id: StringName) -> Dictionary:
	if world == null or not world.assignments.has(assignment_id):
		return {}
	return (world.assignments[assignment_id] as Dictionary).duplicate(true)

static func perform_action(world: WorldState, actor: PersonEntity, assignment_id: StringName, action_id: StringName) -> Dictionary:
	if world == null or actor == null or not world.assignments.has(assignment_id):
		return {"success": false, "message": "This engagement is no longer on the record."}
	var record: Dictionary = world.assignments[assignment_id]
	if String(record.get("status", "")) != "active":
		return {"success": false, "message": "This engagement is not active."}
	if StringName(record.get("actor_id", "")) != actor.id:
		return {"success": false, "message": "This engagement belongs to another scribe."}
	var actions: Dictionary = record.get("actions", {})
	if actions.has(action_id):
		return {"success": false, "message": "That action has already been recorded."}
	var action: Dictionary = {}
	for candidate in get_actions(record):
		if StringName(candidate.id) == action_id:
			action = candidate
			break
	if action.is_empty():
		return {"success": false, "message": "Unknown investigation action."}

	var skill_id: StringName = action.skill
	var level := actor.skills.get_level(skill_id)
	var evidence := _build_evidence(world, actor, record, action_id, level)
	actions[action_id] = true
	var evidence_map: Dictionary = record.get("evidence", {})
	evidence_map[action_id] = evidence
	record["actions"] = actions
	record["evidence"] = evidence_map
	world.assignments[assignment_id] = record
	actor.skills.add_xp(skill_id, int(action.xp))
	actor.memory.append({
		"memory_id": &"assignment_investigation",
		"text": "%s — %s" % [String(record.get("title", "Assignment")), String(evidence.get("summary", "Investigation recorded."))],
		"year": world.year,
		"involved": [String(record.get("source_id", ""))]
	})
	return {"success": true, "message": String(evidence.get("summary", "Evidence recorded.")), "evidence": evidence}

static func resolve(world: WorldState, actor: PersonEntity, assignment_id: StringName, verdict: StringName) -> Dictionary:
	if world == null or actor == null or not world.assignments.has(assignment_id):
		return {"success": false, "message": "This engagement cannot be found."}
	var record: Dictionary = world.assignments[assignment_id]
	if String(record.get("status", "")) != "active":
		return {"success": false, "message": "This engagement is not active."}
	if StringName(record.get("actor_id", "")) != actor.id:
		return {"success": false, "message": "This engagement belongs to another scribe."}
	var actions: Dictionary = record.get("actions", {})
	if actions.size() < 2:
		return {"success": false, "message": "At least two investigative actions must be recorded before assessment."}

	var kind := StringName(record.get("kind", ""))
	var source_id := StringName(record.get("source_id", ""))
	var result_text := ""
	var work_details := ""
	var accurate := true
	match kind:
		&"form":
			var form_data: Dictionary = record.get("source_data", {})
			var form_type := StringName(form_data.get("form_type", ""))
			var regional_form := form_type in [&"remote_dispatch", &"remote_origin_reply"]
			var disposition := "certified"
			if regional_form:
				var regional_result := RegionalWorldSystem.resolve_remote_dispatch(world, form_data, verdict)
				if not bool(regional_result.get("success", false)):
					return regional_result
				result_text = String(regional_result.get("message", "Regional dispatch assessed."))
				work_details = "Shipment: %s. Origin: %s. Destination: %s. Declared: %d. Received: %d." % [String(form_data.get("shipment_id", "")), _place_name(world, StringName(form_data.get("origin_id", ""))), _place_name(world, StringName(form_data.get("destination_id", ""))), int(form_data.get("declared_quantity", 0)), int(form_data.get("received_quantity", 0))]
				accurate = verdict == &"certify"
			else:
				if verdict == &"refer":
					disposition = "referred"
					accurate = false
				elif verdict == &"defer":
					disposition = "deferred"
					accurate = false
			var resolved := world.resolve_form({
					"form_id": String(source_id),
					"assessment": String(verdict) if regional_form else disposition,
					"disposition": String(verdict) if regional_form else disposition,
					"notes": "Assessment by %s after %d work actions." % [actor.display_name, actions.size()]
				}, world.year)
			if not resolved:
				return {"success": false, "message": "The source form has already changed or been resolved."}
			if not regional_form:
				result_text = "The %s is entered as %s. The underlying matter remains subject to future world conditions." % [_form_title(form_type), disposition]

		&"regional_work":
			var work_data: Dictionary = record.get("source_data", {})
			var work_type := StringName(work_data.get("work_type", ""))
			var commodity_id := StringName(work_data.get("commodity_id", ""))
			var quantity := int(work_data.get("quantity", 0))
			var source_institution_id := StringName(work_data.get("source_institution_id", work_data.get("institution_id", "")))
			if work_type in [&"dispatch_export", &"request_import"]:
				var shipment_verdict := verdict in [&"dispatch", &"authorize"]
				if not shipment_verdict:
					accurate = false
					result_text = "The proposed movement is held. No goods leave either institution; the opportunity remains available to the world."
				else:
					if not world.modify_resource(commodity_id, -quantity, "institution", "", source_institution_id):
						return {"success": false, "message": "The source institution no longer has the proposed quantity."}
					var origin_id := StringName(work_data.get("origin_id", ""))
					var destination_id := StringName(work_data.get("destination_id", ""))
					var sender_id := &"enki_ili" if origin_id == &"habuba_kabira" else &"geme_inana"
					var launched := RegionalWorldSystem.launch_shipment(world, {
						"origin_id": origin_id, "destination_id": destination_id,
						"commodity_id": commodity_id, "quantity": quantity,
						"seal_id": "%s_trade_seal_%d" % [String(origin_id), world.current_period_index()],
					"sender_id": sender_id,
					"destination_institution_id": StringName(work_data.get("destination_institution_id", ""))
				})
					if not bool(launched.get("success", false)):
						world.modify_resource(commodity_id, quantity, "institution", "", source_institution_id)
					return {"success": false, "message": String(launched.get("error", "The shipment could not be launched."))}
					result_text = "A sealed shipment of %d %s departs %s for %s. The world will carry it along the route; the destination must still account for what arrives." % [quantity, String(commodity_id).replace("_", " "), _place_name(world, origin_id), _place_name(world, destination_id)]
				work_details = "Shipment %s launched. Quantity %d. Route periods %d." % [String(launched.get("shipment_id", "")), quantity, int(launched.get("travel_periods", 0))]
			elif work_type == &"route_provisions":
				if verdict != &"issue":
					accurate = false
					result_text = "The beer remains in reserve. The route receives no new provision this period."
				else:
					var route_id := StringName(work_data.get("route_id", ""))
					if not world.modify_resource(&"beer", -quantity, "institution", "", source_institution_id):
						return {"success": false, "message": "The institution cannot spare the proposed beer allocation."}
					if not RegionalWorldSystem.provision_route(world, route_id, 8, 3):
						world.modify_resource(&"beer", quantity, "institution", "", source_institution_id)
					return {"success": false, "message": "The route cannot accept provisions at this time."}
					result_text = "%d beer are committed to the route. Exposure is reduced for the next three periods." % quantity
					work_details = "Route %s provisioned through period %d." % [String(route_id), int(world.routes[route_id].get("risk_modifier_until", 0))]
			else:
				return {"success": false, "message": "Unsupported regional work type."}
		&"hazard":
			var hazard: Dictionary = record.get("source_data", {})
			var place_id := StringName(hazard.get("place_id", ""))
			if verdict == &"repair":
				var labor_cost := 3
				if not world.has_active_hazard(place_id, source_id):
					return {"success": false, "message": "The hazard has already been repaired by someone else."}
				if world.get_resource(&"labor", "institution", "", &"eanna_household") < labor_cost:
					return {"success": false, "message": "The institution cannot spare the required labor. The hazard remains active."}
				if not world.modify_resource(&"labor", -labor_cost, "institution", "", &"eanna_household"):
					return {"success": false, "message": "The labor allocation was rejected."}
				world.repair_hazard(place_id, source_id)
				result_text = "Three labor are committed. The %s is taken out of service and its continuing loss stops." % String(source_id).replace("_", " ")
			else:
				accurate = false
				result_text = "The condition is recorded without repair. Its losses continue into the next period."
		&"project_review":
			var project: Dictionary = record.get("source_data", {})
			var progress_resource := StringName(project.get("progress_resource", ""))
			var progress := world.get_resource(progress_resource)
			var target := int(project.get("target", 100))
			var project_state: Dictionary = world.epics.get(source_id, {})
			var notes: Array = project_state.get("history_notes", [])
			work_details = "Progress %d / %d. Current stage: %s. Recorded simulation entries: %d." % [progress, target, String(project_state.get("stage", "unrecorded")), notes.size()]
			result_text = "The project's actual progress, stage, and recorded interruptions are entered in the archive. The crews continue their work independently."
		&"pressure":
			var institution_id := StringName(record.get("source_data", {}).get("institution_id", source_id))
			var institution: Dictionary = world.institutions.get(institution_id, {})
			if institution.is_empty():
				return {"success": false, "message": "The institution no longer exists."}
			var resources: Dictionary = institution.get("stockpiles", {})
			var lines := PackedStringArray()
			for resource_id in resources.keys():
				lines.append("%s: %d" % [String(resource_id).replace("_", " ").capitalize(), int(resources[resource_id])])
			work_details = "Pressure index %d. %s" % [int(institution.get("resource_pressure", 0)), "; ".join(lines)]
			result_text = "The institution's current stockpile position is entered in the archive. The underlying pressure remains the institution's responsibility."
		&"ledger":
			var ledger_institution_id := StringName(record.get("source_data", {}).get("institution_id", &"eanna_household"))
			var ledger: Dictionary = world.institutions.get(ledger_institution_id, {})
			if ledger.is_empty():
				return {"success": false, "message": "The institution's ledger is no longer available."}
			var ledger_resources: Dictionary = ledger.get("stockpiles", {})
			var ledger_lines := PackedStringArray()
			for resource_id in ledger_resources.keys():
				ledger_lines.append("%s: %d" % [String(resource_id).replace("_", " ").capitalize(), int(ledger_resources[resource_id])])
			work_details = "Members: %d. Activity records: %d. Stockpiles: %s" % [int(record.get("source_data", {}).get("member_count", ledger.get("members", []).size())), int(record.get("source_data", {}).get("activity_count", ledger.get("activity_count", 0))), "; ".join(ledger_lines)]
			result_text = "The institution's actual membership, activity, and resource records are copied into the archive. No goods are created or moved by the act of recording them."
		_:
			return {"success": false, "message": "Unsupported world situation."}

	var employer_id := StringName(record.get("employer_id", ""))
	var employer := world.get_person(employer_id)
	var opinion_delta := 1 if accurate else -1
	if employer != null:
		employer.change_opinion(actor.id, opinion_delta, "Assignment assessment: %s" % String(record.get("title", "")), world.year)
	actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) + (2 if accurate else 1)
	actor.skills.add_xp(&"law" if accurate else &"arithmetic", 12 if accurate else 6)
	record["status"] = "completed"
	record["assessment"] = verdict
	record["completed_period"] = world.current_period_index()
	record["result"] = result_text
	record["accurate"] = accurate
	world.assignments[assignment_id] = record
	var source_data: Dictionary = record.get("source_data", {})
	var institution_id := StringName(source_data.get("institution_id", ""))
	var location_id := StringName(source_data.get("place_id", source_data.get("subject_id", "")))
	if location_id == &"" and institution_id != &"":
		location_id = StringName(world.institutions.get(institution_id, {}).get("place_id", ""))
	if institution_id == &"":
		institution_id = _institution_for_location(world, location_id)
	var commodity_id := StringName(source_data.get("resource", source_data.get("commodity_id", "")))
	var npc_ids: Array[StringName] = []
	if employer_id != &"":
		npc_ids.append(employer_id)
	world.cedar_desk_log.append({
		"year": world.year,
		"period": world.period,
		"assignment_id": String(assignment_id),
		"title": String(record.get("title", "Assignment")),
		"employer_id": String(employer_id),
		"responsible_character_id": String(actor.id),
		"npc_ids": npc_ids,
		"institution_id": String(institution_id),
		"location_id": String(location_id),
		"commodity_id": String(commodity_id),
		"document_type": String(source_data.get("form_type", kind)),
		"category": String(kind),
		"activity": "assignment_assessment",
		"decision": String(verdict),
		"outcome": result_text,
		"details": work_details,
		"relationship_delta": opinion_delta,
		"silver_awarded": 2 if accurate else 1,
		"skill_awarded": "law" if accurate else "arithmetic",
		"skill_xp": 12 if accurate else 6,
		"path_id": String(record.get("path_id", ""))
	})
	actor.memory.append({
		"memory_id": &"assignment_assessment",
		"text": "%s — %s" % [String(record.get("title", "Assignment")), result_text],
		"year": world.year,
		"involved": [String(source_id)]
	})
	world.record_case_settlement(actor, int(actor.resources.get(&"silver", 0)) - (2 if accurate else 1), actor.traits.duplicate())
	return {"success": true, "message": result_text, "accurate": accurate}

static func _build_evidence(world: WorldState, actor: PersonEntity, record: Dictionary, action_id: StringName, skill_level: int) -> Dictionary:
	var kind := StringName(record.get("kind", ""))
	var data: Dictionary = record.get("source_data", {})
	var summary := ""
	var facts := ""
	match action_id:

		&"review_trade_manifest":
			var source_institution_id := StringName(data.get("source_institution_id", data.get("institution_id", "")))
			var source_institution: Dictionary = world.institutions.get(source_institution_id, {})
			var source_stock: Dictionary = source_institution.get("stockpiles", {})
			var route_ids := RegionalWorldSystem.find_route_path(world, StringName(data.get("origin_id", "")), StringName(data.get("destination_id", "")))
			summary = "The trade manifest is reviewed against the named institution and connected route."
			facts = "WORK: %s\nCOMMODITY: %s\nQUANTITY PROPOSED: %d\nSOURCE STOCK: %d\nROUTE TIME: %d PERIODS" % [String(data.get("work_type", "")).replace("_", " ").capitalize(), String(data.get("commodity_id", "")).replace("_", " "), int(data.get("quantity", 0)), int(source_stock.get(StringName(data.get("commodity_id", "")), 0)), RegionalWorldSystem.route_path_periods(world, route_ids)]
		&"compare_trade_balance":
			var balance_institution_id := StringName(data.get("source_institution_id", data.get("institution_id", "")))
			var balance_institution: Dictionary = world.institutions.get(balance_institution_id, {})
			var balance_stock: Dictionary = balance_institution.get("stockpiles", {})
			var balance_available := int(balance_stock.get(StringName(data.get("commodity_id", "")), 0))
			var proposed := int(data.get("quantity", 0))
			summary = "The proposed movement is compared with the source institution's actual reserve."
			facts = "AVAILABLE: %d\nPROPOSED: %d\n%s" % [balance_available, proposed, ("REMAINING AFTER MOVEMENT: %d" % (balance_available - proposed)) if skill_level >= 2 else ("RESERVE: %s" % ("sufficient" if balance_available >= proposed else "insufficient"))]
		&"consult_local_factor":
			var factor := world.get_person(StringName(record.get("employer_id", "")))
			var factor_opinion := factor.get_opinion(actor.id) if factor != null else 0
			summary = "The local factor explains the commercial purpose and accepts responsibility for the request."
			facts = "FACTOR: %s\nPLACE: %s\nOPINION OF SCRIBE: %+d\nTESTIMONY: NOT A CARGO RECEIPT" % [factor.display_name if factor != null else "Local factor", _place_name(world, StringName(data.get("place_id", ""))), factor_opinion]
		&"inspect_trade_goods":
			var goods_institution_id := StringName(data.get("source_institution_id", data.get("institution_id", "")))
			var goods_institution: Dictionary = world.institutions.get(goods_institution_id, {})
			var goods_stock: Dictionary = goods_institution.get("stockpiles", {})
			var commodity := StringName(data.get("commodity_id", ""))
			summary = "The goods are checked against the source institution's current reserve."
			facts = "INSTITUTION: %s\nCOMMODITY: %s\nON HAND: %d\nPROPOSED: %d" % [String(goods_institution.get("name", goods_institution_id)), String(commodity).replace("_", " "), int(goods_stock.get(commodity, 0)), int(data.get("quantity", 0))]
		&"inspect_seal":
			var seal_id := String(data.get("seal_id", "unmarked"))
			var seal_valid := bool(data.get("seal_valid", true))
			var sender := world.get_person(StringName(data.get("sender_id", "")))
			summary = "The seal is examined as an identity mark, not proof that the cargo remained untouched."
			facts = "SEAL MARK: %s\nSENDER: %s\nSEAL REGISTER: %s" % [seal_id, sender.display_name if sender != null else String(data.get("sender_id", "unknown")), ("MATCH" if seal_valid else "MISMATCH") if skill_level >= 2 else "MARK VISIBLE; REGISTER NOT VERIFIED"]
		&"compare_manifest":
			var declared := int(data.get("declared_quantity", 0))
			var received := int(data.get("received_quantity", 0))
			summary = "The manifest is compared with the quantity physically received."
			facts = "COMMODITY: %s\nDECLARED: %d\nRECEIVED: %d\n%s" % [String(data.get("commodity_id", "cargo")).replace("_", " "), declared, received, ("VARIANCE: %d" % (declared - received)) if skill_level >= 2 else ("QUANTITY VARIANCE: %s" % ("present" if declared != received else "not indicated"))]
		&"question_carrier":
			var carrier := world.get_person(StringName(data.get("sender_id", "")))
			summary = "The carrier's account is recorded as testimony; it does not independently establish the cargo's fate."
			facts = "CARRIER: %s\nACCOUNT: Cargo was dispatched under the recorded seal and quantity.\nTESTIMONY: NOT INDEPENDENT VERIFICATION" % (carrier.display_name if carrier != null else String(data.get("sender_id", "unidentified carrier")))
		&"inspect_cargo":
			var received_quantity := int(data.get("received_quantity", 0))
			var lost_quantity := int(data.get("loss_quantity", 0))
			summary = "The landed cargo is inspected. Route loss is recorded separately from responsibility."
			facts = "RECEIVED: %d %s\nRECORDED ROUTE LOSS: %d\nCARGO CONDITION: %s" % [received_quantity, String(data.get("commodity_id", "cargo")).replace("_", " "), lost_quantity, "bundles missing in transit" if lost_quantity > 0 else "no quantity loss recorded"]
		&"examine_origin_copy":
			var origin_quantity := int(data.get("origin_account_quantity", data.get("declared_quantity", 0)))
			summary = "The origin-side sealed copy confirms what was entered before the shipment left."
			facts = "ORIGIN ACCOUNT: %d %s\nSEAL: %s\nSENDER: %s" % [origin_quantity, String(data.get("commodity_id", "cargo")).replace("_", " "), String(data.get("seal_id", "unmarked")), String(data.get("sender_id", "unknown"))]
		&"compare_origin_copy":
			var origin_recorded := int(data.get("origin_account_quantity", data.get("declared_quantity", 0)))
			var arrival_recorded := int(data.get("received_quantity", 0))
			summary = "The origin copy and destination receipt are compared. The difference occurred somewhere along the chain, not necessarily at the landing."
			facts = "ORIGIN: %d\nARRIVAL: %d\n%s" % [origin_recorded, arrival_recorded, ("UNACCOUNTED VARIANCE: %d" % (origin_recorded - arrival_recorded)) if skill_level >= 2 else ("VARIANCE: %s" % ("present" if origin_recorded != arrival_recorded else "not indicated"))]
		&"reconcile_accounts":
			var institution_id := StringName(data.get("institution_id", &"eanna_household"))
			var institution: Dictionary = world.institutions.get(institution_id, {})
			var stock: Dictionary = institution.get("stockpiles", {})
			var total := 0
			for amount in stock.values():
				total += int(amount)
			if kind == &"form":
				summary = "The source form is reconciled against the institution's current records."
				facts = "FORM: %s\nURGENCY: %d\nINSTITUTIONAL STOCK TOTAL: %d" % [String(data.get("form_type", "")), int(data.get("urgency", 0)), total]
			else:
				summary = "The institution's recorded quantities are totalled from its current stockpile dictionary."
				facts = "INSTITUTION: %s\nMEMBERS: %d\nACTIVITY RECORDS: %d\nRECORDED STOCK TOTAL: %d\nRESOURCE LINES: %d" % [String(institution.get("name", institution_id)), int(data.get("member_count", institution.get("members", []).size())), int(data.get("activity_count", institution.get("activity_count", 0))), total, stock.size()]
			if skill_level >= 2:
				facts += "\nARITHMETIC CHECK: SECOND-LEVEL RECONCILIATION AVAILABLE"
		&"examine_records":
			if kind == &"form":
				summary = "The form's origin and urgency are confirmed against the pending register."
				facts = "FORM: %s\nSUBJECT: %s\nURGENCY: %d\nGENERATED BY: %s" % [String(data.get("form_type", "")), _place_name(world, StringName(data.get("subject_id", ""))), int(data.get("urgency", 0)), String(data.get("generated_by", "world"))]
			else:
				summary = "The written record is examined. The current account can be compared with the live institution state."
				facts = "SOURCE: %s\nPERIOD: %d\nSKILL: %s %d" % [String(record.get("source_id", "")), world.current_period_index(), "Literacy", skill_level]
		&"consult_official":
			var employer := world.get_person(StringName(record.get("employer_id", "")))
			var opinion := employer.get_opinion(actor.id) if employer != null else 0
			summary = "The responsible official's account is recorded. It is testimony, not proof."
			facts = "OFFICIAL: %s\nOPINION OF SCRIBE: %+d\nOFFICE: %s" % [employer.display_name if employer != null else "No named official", opinion, String(employer.office_id) if employer != null else "Unassigned"]
		&"inspect_source":
			if kind == &"hazard":
				var hazard: Dictionary = record.get("source_data", {})
				facts = "SITE: %s\nHAZARD: %s\nLOSS / PERIOD: %d %s\nTOTAL RECORDED LOSS: %d" % [_place_name(world, StringName(hazard.get("place_id", ""))), String(hazard.get("id", "")), int(hazard.get("rate", 0)), String(hazard.get("resource", "")), int(hazard.get("total_lost", 0))]
				summary = "The active hazard is physically inspected. The recorded loss is checked against the current site condition."
			else:
				var institution_id := StringName(data.get("institution_id", &"eanna_household"))
				var institution: Dictionary = world.institutions.get(institution_id, {})
				var stock: Dictionary = institution.get("stockpiles", {})
				var stock_lines := PackedStringArray()
				for resource_id in stock.keys():
					stock_lines.append("%s: %d" % [String(resource_id).replace("_", " ").capitalize(), int(stock[resource_id])])
				facts = "INSTITUTION: %s\nMEMBERS: %d\nACTIVITY RECORDS: %d\n%s" % [String(institution.get("name", institution_id)), int(data.get("member_count", institution.get("members", []).size())), int(data.get("activity_count", institution.get("activity_count", 0))), "\n".join(stock_lines)]
				summary = "The institution's current membership, activity, and resource records are inspected."
	if action_id == &"examine_records" and skill_level >= 2:
		facts += "\nGENERATION REASON: %s" % String(data.get("generation_reason", "not recorded"))
	elif action_id == &"consult_official" and skill_level >= 2:
		var consulted := world.get_person(StringName(record.get("employer_id", "")))
		if consulted != null:
			var tie: Dictionary = consulted.relationships.get(actor.id, {})
			facts += "\nRECORDED TRUST: %d / RELATIONSHIP: %s" % [int(tie.get("trust", 0)), String(tie.get("type", "unknown"))]
	facts += "\nCAPABILITY APPLIED: %s / LEVEL %d" % [String(action_id).replace("_", " ").to_upper(), skill_level]
	return {"summary": summary, "facts": facts, "skill_level": skill_level}

static func _institution_for_location(world: WorldState, location_id: StringName) -> StringName:
	if location_id == &"":
		return &""
	var place: Dictionary = world.places.get(location_id, {})
	var parent_id := StringName(place.get("parent", ""))
	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var institution_place := StringName(institution.get("place_id", ""))
		if institution_place == location_id or (parent_id != &"" and institution_place == parent_id):
			return StringName(institution_id)
	return &""

static func _form_employer(world: WorldState, form_type: StringName) -> StringName:
	var preferred_id: StringName = &"shuruppak_ilu"
	match form_type:
		&"grain_levy", &"held_barley":
			preferred_id = &"ur_nanna"
		&"pension_roll":
			preferred_id = &"utu_mansum"
		&"consignment_receipt":
			preferred_id = &"geme_inana"
		&"load_claim":
			preferred_id = &"lu_nanshe"
	return preferred_id if world.get_person(preferred_id) != null else &""

static func _career_bonus(path_id: StringName, work_kind: StringName) -> int:
	match path_id:
		&"path_civil":
			return 2 if work_kind in [&"form", &"pressure", &"ledger"] else 0
		&"path_religious":
			return 2 if work_kind in [&"form", &"ledger"] else 0
		&"path_martial":
			return 2 if work_kind in [&"hazard", &"pressure", &"project"] else 0
		&"path_merchant":
			return 2 if work_kind in [&"ledger", &"pressure"] else 0
	return 0

static func _form_title(form_type: StringName) -> String:
	var labels := {
		&"remote_dispatch": "Remote Consignment / Arrival Docket",
		&"remote_origin_reply": "Origin-Side Shipment Reply",
		&"grain_levy": "Grain Levy Assessment",
		&"pension_roll": "Workforce Roll",
		&"consignment_receipt": "Consignment Receipt",
		&"held_barley": "Held Barley Inspection",
		&"load_claim": "Load Allocation Claim"
	}
	return String(labels.get(form_type, String(form_type).replace("_", " ").capitalize()))



static func _regional_institution_for_place(world: WorldState, place_id: StringName) -> StringName:
	if place_id == &"uruk":
		return &"eanna_household"
	return StringName(world.places.get(place_id, {}).get("regional_institution_id", ""))

static func _find_importing_destination(world: WorldState, origin_id: StringName, commodity_id: StringName) -> StringName:
	var selected_place := &""
	var shortest := 2147483647
	for place_id_variant in world.places.keys():
		var place_id := StringName(place_id_variant)
		if place_id == origin_id:
			continue
		var place: Dictionary = world.places[place_id]
		var imports: Array = place.get("imports", [])
		if not imports.has(commodity_id) or _regional_institution_for_place(world, place_id) == &"":
			continue
		var route_ids := RegionalWorldSystem.find_route_path(world, origin_id, place_id)
		if route_ids.is_empty():
			continue
		var duration := RegionalWorldSystem.route_path_periods(world, route_ids)
		if duration < shortest:
			shortest = duration
			selected_place = place_id
	return selected_place

static func _find_exporting_source(world: WorldState, destination_id: StringName, commodity_id: StringName) -> Dictionary:
	var selected: Dictionary = {}
	var shortest := 2147483647
	for place_id_variant in world.places.keys():
		var place_id := StringName(place_id_variant)
		if place_id == destination_id:
			continue
		var place: Dictionary = world.places[place_id]
		var exports: Array = place.get("exports", [])
		if not exports.has(commodity_id):
			continue
		var institution_id := _regional_institution_for_place(world, place_id)
		if institution_id == &"":
			continue
		var stock: Dictionary = world.institutions.get(institution_id, {}).get("stockpiles", {})
		if int(stock.get(commodity_id, 0)) < 3:
			continue
		var route_ids := RegionalWorldSystem.find_route_path(world, place_id, destination_id)
		if route_ids.is_empty():
			continue
		var duration := RegionalWorldSystem.route_path_periods(world, route_ids)
		if duration < shortest:
			shortest = duration
			selected = {"place_id": place_id, "institution_id": institution_id}
	return selected

static func _regional_work_candidate(world: WorldState, path_id: StringName, place_id: StringName, institution_id: StringName, employer_id: StringName, work_type: StringName, commodity_id: StringName, quantity: int, origin_id: StringName, destination_id: StringName, source_institution_id: StringName, destination_institution_id: StringName, route_id: StringName) -> Dictionary:
	var work_id := StringName("regional_%s_%s_%s_%d" % [String(work_type), String(place_id), String(commodity_id), world.current_period_index()])
	var title := ""
	var summary := ""
	var priority := 3
	match work_type:
		&"dispatch_export":
			title = "%s / Outbound %s Dispatch" % [_place_name(world, place_id), String(commodity_id).replace("_", " ").capitalize()]
			summary = "The local institution has %d %s available for a sealed shipment to %s." % [quantity, String(commodity_id).replace("_", " "), _place_name(world, destination_id)]
			priority = 7
		&"request_import":
			title = "%s / Import Request" % _place_name(world, place_id)
			summary = "A connected trade house can send %d %s from %s to %s." % [quantity, String(commodity_id).replace("_", " "), _place_name(world, origin_id), _place_name(world, destination_id)]
			priority = 6
		&"route_provisions":
			title = "%s / Route Provisioning" % _place_name(world, place_id)
			summary = "A local allocation of %d beer can provision the route toward %s and reduce exposure for the next three periods." % [quantity, _place_name(world, destination_id)]
			priority = 3
	return {
		"id": work_id, "kind": &"regional_work", "source_id": work_id,
		"title": title, "summary": summary,
		"priority": priority + _career_bonus(path_id, &"regional_work"),
		"employer_id": employer_id,
		"source_data": {
			"work_type": work_type, "place_id": place_id,
			"institution_id": institution_id,
			"source_institution_id": source_institution_id,
			"destination_institution_id": destination_institution_id,
			"origin_id": origin_id, "destination_id": destination_id,
			"commodity_id": commodity_id, "quantity": quantity, "route_id": route_id
		},
		"path_id": path_id
	}

static func _highest_risk_route(world: WorldState, origin_id: StringName) -> StringName:
	var selected_route := &""
	var highest_risk := -1
	for route_id in world.routes.keys():
		var route: Dictionary = world.routes[route_id]
		if not bool(route.get("active", true)) or StringName(route.get("from_place_id", "")) != origin_id:
			continue
		var risk := RegionalWorldSystem.effective_route_risk(world, StringName(route_id))
		if risk > highest_risk:
			highest_risk = risk
			selected_route = StringName(route_id)
	return selected_route

static func _is_local_to_actor(world: WorldState, actor: PersonEntity, place_id: StringName) -> bool:
	if world == null or actor == null:
		return false
	var actor_place_id := actor.current_location_id if actor.current_location_id != &"" else &"uruk"
	if place_id == &"":
		return actor_place_id == &"uruk"
	var cursor := place_id
	for depth in range(8):
		if cursor == actor_place_id:
			return true
		var place: Dictionary = world.places.get(cursor, {})
		cursor = StringName(place.get("parent", ""))
		if cursor == &"":
			break
	return false

static func _form_summary(world: WorldState, form: Dictionary) -> String:
	var form_type := StringName(form.get("form_type", ""))
	if form_type == &"remote_dispatch":
		return "A sealed consignment from %s has arrived at %s. Its arrival must be entered." % [_place_name(world, StringName(form.get("origin_id", ""))), _place_name(world, StringName(form.get("destination_id", "")))]
	if form_type == &"remote_origin_reply":
		return "A delayed account from %s has reached %s. The origin and landing records can now be compared." % [_place_name(world, StringName(form.get("origin_id", ""))), _place_name(world, StringName(form.get("destination_id", "")))]
	return "%s requires an assessment at %s." % [_form_title(form_type), _place_name(world, StringName(form.get("subject_id", "")))]

static func _place_name(world: WorldState, place_id: StringName) -> String:
	if place_id == &"":
		return "the institution"
	if world.places.has(place_id):
		return String(world.places[place_id].get("name", place_id))
	return String(place_id).replace("_", " ").capitalize()
