class_name AssignmentPipeline
extends RefCounted
## Converts persistent world conditions into professional opportunities.
## It never invents economic quantities: all facts are read from WorldState.

const BOARD_SIZE := 4
const MAX_INVESTIGATION_ACTIONS := 2
const AssignmentGeneratorScript = preload("res://systems/assignment_generator.gd")
const INVESTIGATION_ACTIONS := [
	{"id": &"examine_records", "label": "Examine the written record", "skill": &"literacy", "xp": 8},
	{"id": &"reconcile_accounts", "label": "Reconcile the figures", "skill": &"arithmetic", "xp": 8},
	{"id": &"consult_official", "label": "Consult the responsible official", "skill": &"rhetoric", "xp": 8},
	{"id": &"inspect_source", "label": "Inspect the goods, stores, or site", "skill": &"stewardship", "xp": 8}
]

static func generate_opportunities(world: WorldState, actor: PersonEntity, selected_path: StringName = &"") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if world == null or actor == null:
		return candidates

	for form in world.pending_forms:
		var subject_id := StringName(form.get("subject_id", ""))
		if not _is_local_to_current_location(world, subject_id):
			continue
		var form_id := StringName(form.get("id", ""))
		if form_id == &"":
			continue
		var form_type := StringName(form.get("form_type", ""))
		var subject_name := _place_name(world, subject_id)
		var urgency := int(form.get("urgency", 1))
		var form_title := _form_title(form_type)
		var form_summary := "%s requires an assessment at %s." % [form_title, subject_name]
		var institution_id := StringName(form.get("institution_id", _institution_for_location(world, subject_id)))
		var place_id := StringName(form.get("place_id", subject_id))
		if institution_id != &"":
			place_id = StringName(world.institutions.get(institution_id, {}).get("place_id", place_id))
		var form_source := form.duplicate(true)
		form_source["institution_id"] = institution_id
		form_source["place_id"] = place_id
		var npc_evidence: Dictionary = form.get("npc_evidence", {})
		if not npc_evidence.is_empty():
			form_title = "Contradictory North-Bay Grain Docket"
			form_summary = "Two records disagree about the barley held at %s. The dispatch docket declares prime seed-corn; the threshold tally records damp, mold-marked grain." % subject_name
		candidates.append({
			"id": StringName("work_form_%s_%d" % [form_id, world.current_period_index()]),
			"kind": &"form",
			"source_id": form_id,
			"title": form_title,
			"summary": form_summary,
			"priority": 6 if not npc_evidence.is_empty() else 2 + urgency,
			"employer_id": _resolve_local_employer(world, institution_id, place_id, _preferred_office(form_type)),
			"source_data": form_source,
			"path_id": selected_path
		})

	for hazard in world.hazards:
		if not bool(hazard.get("active", false)):
			continue
		var hazard_id := StringName(hazard.get("id", ""))
		var place_id := StringName(hazard.get("place_id", ""))
		if not _is_local_to_current_location(world, place_id):
			continue
		candidates.append({
			"id": StringName("work_hazard_%s_%d" % [hazard_id, world.current_period_index()]),
			"kind": &"hazard",
			"source_id": hazard_id,
			"title": "Inspect %s" % _place_name(world, place_id),
			"summary": "An active %s continues to damage institutional stores." % String(hazard_id).replace("_", " "),
			"priority": 4 + int(hazard.get("rate", 0)) + _career_bonus(selected_path, &"hazard"),
			"employer_id": _resolve_local_employer(world, StringName(hazard.get("institution_id", _institution_for_location(world, place_id))), place_id, &"canal_bailiff"),
			"source_data": _hazard_source(hazard, world),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		if not _is_local_to_current_location(world, StringName(institution.get("place_id", ""))):
			continue
		var pressure := int(institution.get("resource_pressure", 0))
		if pressure < 1:
			continue
		candidates.append({
			"id": StringName("work_pressure_%s_%d" % [institution_id, world.current_period_index()]),
			"kind": &"pressure",
			"source_id": StringName(institution_id),
			"title": "%s / Resource Pressure" % String(institution.get("name", institution_id)),
			"summary": "The institution reports a pressure index of %d. Its current stockpiles need review." % pressure,
			"priority": 2 + pressure + _career_bonus(selected_path, &"pressure"),
			"employer_id": _resolve_local_employer(world, StringName(institution_id), StringName(institution.get("place_id", "")), &""),
			"source_data": {"institution_id": StringName(institution_id), "place_id": StringName(institution.get("place_id", "")), "pressure": pressure},
			"path_id": selected_path
		})

	# Epic reviews are state-latched: only initial or newly reached stages appear.
	for epic_id in world.epics.keys():
		var epic: Dictionary = world.epics[epic_id]
		if not bool(epic.get("active", false)) or bool(epic.get("completed", false)):
			continue
		world.ensure_epic_review_state(StringName(epic_id))
		epic = world.epics[epic_id]
		if not bool(epic.get("review_pending", false)):
			continue
		var sponsor_id := StringName(epic.get("sponsor_institution", &"eanna_household"))
		var sponsor: Dictionary = world.institutions.get(sponsor_id, {})
		var place_id := StringName(sponsor.get("place_id", ""))
		if not _is_local_to_current_location(world, place_id):
			continue
		var progress := int(epic.get("progress", world.get_resource(StringName(epic.get("progress_resource", "")))))
		var target := int(epic.get("target", 100))
		var review_stage := int(epic.get("review_stage", world.get_epic_stage_index(progress, target)))
		var stage_label := String(epic.get("review_stage_label", world.get_epic_stage_label(review_stage)))
		var review_reason := String(epic.get("review_reason", "stage_reached"))
		var title_suffix := stage_label if review_reason in ["project_opened", "stage_reached"] else _epic_problem_label(review_reason)
		var review_summary := String(epic.get("review_summary", "Review labor, supply, and project progress."))
		candidates.append({
			"id": StringName("epic:%s:s%d" % [epic_id, review_stage]),
			"kind": &"project_review",
			"source_id": StringName(epic_id),
			"sponsor_institution": sponsor_id,
			"place_id": place_id,
			"title": "%s — %s" % [String(epic.get("title", epic_id)), title_suffix],
			"summary": "%s (%d / %d)." % [review_summary.trim_suffix("."), progress, target],
			"priority": 2 + _career_bonus(selected_path, &"project"),
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": epic.duplicate(true),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		if not _is_local_to_current_location(world, StringName(institution.get("place_id", ""))):
			continue
		var routine_id := StringName("work_ledger_%s_%d" % [institution_id, world.current_period_index()])
		candidates.append({
			"id": routine_id,
			"kind": &"ledger",
			"source_id": StringName(institution_id),
			"title": String(institution.get("ledger_work_title", "")) if not String(institution.get("ledger_work_title", "")).is_empty() else "%s / Periodic Account" % String(institution.get("name", institution_id)),
			"summary": String(institution.get("ledger_work_summary", "")) if not String(institution.get("ledger_work_summary", "")).is_empty() else "Reconcile the institution's current membership, activity, and resource records.",
			"priority": mini(3, int(institution.get("ledger_work_priority", 1)) + _career_bonus(selected_path, &"ledger")),
			"employer_id": _resolve_local_employer(world, StringName(institution_id), StringName(institution.get("place_id", "")), &""),
			"source_data": {"institution_id": StringName(institution_id), "place_id": StringName(institution.get("place_id", "")), "member_count": institution.get("members", []).size(), "activity_count": int(institution.get("activity_count", 0))},
			"path_id": selected_path
		})

	# The career-path docket joins ordinary world work on the same board.
	# Board construction is a preview. Keep narrative RNG and rotation history
	# untouched until the player actually opens the procedural docket.
	var prior_narrative_rng_state := world.rng_narrative.state
	var procedural_payload := AssignmentGeneratorScript.generate(world, actor, selected_path, false)
	world.rng_narrative.state = prior_narrative_rng_state
	if not procedural_payload.is_empty():
		var procedural_archetype := StringName(procedural_payload.get("archetype", "docket"))
		candidates.append({
			"id": StringName("work_procedural_%s_%d" % [procedural_archetype, world.current_period_index()]),
			"kind": &"procedural_docket",
			"source_id": procedural_archetype,
			"title": String(procedural_payload.get("title", "Local Docket")),
			"summary": String(procedural_payload.get("prompt", "A local matter awaits your judgment.")),
			"priority": 5,
			"employer_id": _resolve_local_employer(world, _institution_for_location(world, world.current_location_id), world.current_location_id, &""),
			"source_data": procedural_payload.duplicate(true),
			"path_id": selected_path
		})

	# Abandoning an assignment removes that period-keyed docket from this board.
	# Its source may return naturally next period under a fresh opportunity ID.
	var filtered_candidates: Array[Dictionary] = []
	var seen_sources: Dictionary = {}
	for candidate in candidates:
		var source_key := "%s:%s" % [String(candidate.get("kind", "")), String(candidate.get("source_id", ""))]
		if seen_sources.has(source_key):
			continue
		seen_sources[source_key] = true
		var candidate_id := StringName(candidate.get("id", ""))
		var prior_assignment: Dictionary = world.assignments.get(candidate_id, {})
		if String(prior_assignment.get("status", "")) == "abandoned" and int(prior_assignment.get("started_period", -1)) == world.current_period_index():
			continue
		filtered_candidates.append(candidate)
	candidates = filtered_candidates

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return _select_board_candidates(candidates, BOARD_SIZE)


static func _select_board_candidates(candidates: Array[Dictionary], board_size: int = BOARD_SIZE) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_kinds: Dictionary = {}
	var procedural_candidate: Dictionary = {}
	# Active project reviews are obligations, not optional board rotation.
	# Include every pending review first; BOARD_SIZE limits routine work only.
	for candidate in candidates:
		if StringName(candidate.get("kind", "")) == &"project_review":
			result.append(candidate.duplicate(true))
			used_kinds[&"project_review"] = true
		elif StringName(candidate.get("kind", "")) == &"procedural_docket":
			procedural_candidate = candidate
	# Fill the ordinary board around the reviews, preserving one story slot.
	for candidate in candidates:
		var kind := StringName(candidate.get("kind", ""))
		if kind in [&"project_review", &"procedural_docket"]:
			continue
		if result.size() >= maxi(0, board_size - 1):
			break
		if used_kinds.has(kind):
			continue
		result.append(candidate.duplicate(true))
		used_kinds[kind] = true
	if not procedural_candidate.is_empty() and result.size() < board_size:
		result.append(procedural_candidate.duplicate(true))
	# If the story slot was unavailable, fill remaining routine slots by priority.
	if result.size() < board_size:
		for candidate in candidates:
			if candidate in result or StringName(candidate.get("kind", "")) == &"procedural_docket":
				continue
			result.append(candidate.duplicate(true))
			if result.size() >= board_size:
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
	if actions.size() >= MAX_INVESTIGATION_ACTIONS:
		return {"success": false, "message": "2 / 2 inquiries spent — choose your disposition."}
	if actions.has(action_id):
		return {"success": false, "message": "That action has already been recorded."}
	var action: Dictionary = {}
	for candidate in INVESTIGATION_ACTIONS:
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
	var opinion_delta_override := 0
	var silver_award := 2
	match kind:
		&"form":
			var form_data: Dictionary = record.get("source_data", {})
			var disposition := "certified"
			if verdict == &"refer":
				disposition = "referred"
				accurate = false
			elif verdict == &"defer":
				disposition = "deferred"
				accurate = false
			var resolved := world.resolve_form({
				"form_id": String(source_id),
				"assessment": disposition,
				"disposition": disposition,
				"notes": "Assessment by %s after %d investigative actions." % [actor.display_name, actions.size()]
			}, world.year)
			if not resolved:
				return {"success": false, "message": "The source form has already changed or been resolved."}
			var form_type := StringName(form_data.get("form_type", ""))
			var npc_evidence: Dictionary = form_data.get("npc_evidence", {})
			var form_institution_id := StringName(form_data.get("institution_id", _institution_for_location(world, StringName(form_data.get("place_id", form_data.get("subject_id", ""))))))
			var form_institution: Dictionary = world.institutions.get(form_institution_id, {})
			var form_stock_records: Dictionary = form_institution.get("stock_records", {})
			var concealed := not npc_evidence.is_empty() or bool(form_stock_records.get("concealed_spoilage", false))
			if concealed and verdict == &"refer":
				form_stock_records["concealed_spoilage"] = false
				form_stock_records.erase("barley_quality_declaration")
				form_institution["stock_records"] = form_stock_records
				var form_stock: Dictionary = form_institution.get("stockpiles", {})
				form_stock[&"barley"] = maxi(0, int(form_stock.get(&"barley", 0)) - 8)
				form_institution["stockpiles"] = form_stock
				world.institutions[form_institution_id] = form_institution
				opinion_delta_override = -3
				silver_award = 1
				var archivist := world.get_person(&"shuruppak_ilu")
				if archivist != null and world.current_location_id == &"uruk":
					archivist.change_opinion(actor.id, 2, "The apprentice referred a concealed grain account for correction.", world.year)
				world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "FORMAL AUDIT CORRECTION", "summary": "The damp-barley declaration was referred. Concealed spoilage was cleared, eight measures were struck from the usable stock, and the archive received the correction.", "institution_id": String(form_institution_id)})
				result_text = "The %s is referred. Concealed spoilage is exposed, eight measures are struck from usable barley, and the archive records a formal correction." % _form_title(form_type)
			elif concealed and verdict == &"certify":
				opinion_delta_override = 2
				silver_award = 4
				actor.flags[&"audit_exposure"] = int(actor.flags.get(&"audit_exposure", 0)) + 1
				form_institution["audit_exposure"] = int(form_institution.get("audit_exposure", 0)) + 1
				world.institutions[form_institution_id] = form_institution
				result_text = "The %s is certified. The official pays four silver; damp grain and the shortage remain concealed. Your name is exposed to an archive audit." % _form_title(form_type)
			elif form_type in [&"bailiff_requisition", &"pension_roll"] and verdict == &"certify":
				var relief_stock: Dictionary = form_institution.get("stockpiles", {})
				var relief_resource := &"labor" if form_type == &"pension_roll" else &"barley"
				var relief_amount := 3 if relief_resource == &"labor" else 12
				relief_stock[relief_resource] = int(relief_stock.get(relief_resource, 0)) + relief_amount
				form_institution["stockpiles"] = relief_stock
				form_institution["resource_pressure"] = maxi(0, int(form_institution.get("resource_pressure", 0)) - 2)
				form_institution["requisition_relief_note"] = "Authorized %d %s against the immediate backlog." % [relief_amount, String(relief_resource)]
				world.institutions[form_institution_id] = form_institution
				result_text = "The %s is certified. %d %s are reassigned to the institution; the immediate backlog is reduced." % [_form_title(form_type), relief_amount, String(relief_resource)]
			else:
				result_text = "The %s is entered as %s. The current stock and shortage remain visible for the next account." % [_form_title(form_type), disposition]
		&"hazard":
			var hazard: Dictionary = record.get("source_data", {})
			var place_id := StringName(hazard.get("place_id", ""))
			if verdict == &"repair":
				var labor_cost := 3
				var hazard_institution_id := StringName(hazard.get("institution_id", _institution_for_location(world, place_id)))
				if not world.has_active_hazard(place_id, source_id):
					return {"success": false, "message": "The hazard has already been repaired by someone else."}
				if world.get_resource(&"labor", "institution", "", hazard_institution_id) < labor_cost:
					return {"success": false, "message": "The institution cannot spare the required labor. The hazard remains active."}
				if not world.modify_resource(&"labor", -labor_cost, "institution", "", hazard_institution_id):
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
			if not bool(project_state.get("review_pending", false)):
				return {"success": false, "message": "This stage review has already been acknowledged."}
			var presented_stage := int(project.get("review_stage", project_state.get("review_stage", -1)))
			if presented_stage != int(project_state.get("review_stage", -2)) or String(project.get("review_reason", "")) != String(project_state.get("review_reason", "")):
				return {"success": false, "message": "The project's conditions changed while this review was in progress. Return to the board for the current docket."}
			var notes: Array = project_state.get("history_notes", [])
			var reviewed_stage := String(project_state.get("stage", "unrecorded"))
			work_details = "Progress %d / %d. Current stage: %s. Recorded simulation entries: %d." % [progress, target, reviewed_stage, notes.size()]
			project_state["last_reviewed_progress"] = progress
			project_state["last_reviewed_stage"] = reviewed_stage
			world.epics[source_id] = project_state
			record["reviewed_progress"] = progress
			record["reviewed_stage"] = reviewed_stage
			record["review_cycle"] = int(project_state.get("review_cycle", 0))
			result_text = "The project's actual progress, stage, and recorded interruptions are entered in the archive. The crews continue their work independently."
			world.resolve_epic_review(source_id)
		&"pressure":
			var pressure_institution_id := StringName(record.get("source_data", {}).get("institution_id", source_id))
			var institution: Dictionary = world.institutions.get(pressure_institution_id, {})
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
			result_text = "The institution's membership, activity, and current stock ledger are entered in the archive. The recorded balances remain unchanged by this filing."
		_:
			return {"success": false, "message": "Unsupported world situation."}

	var employer_id := StringName(record.get("employer_id", ""))
	var employer := world.get_person(employer_id)
	var opinion_delta := opinion_delta_override if opinion_delta_override != 0 else (1 if accurate else -1)
	if employer != null:
		employer.change_opinion(actor.id, opinion_delta, "Assignment assessment: %s" % String(record.get("title", "")), world.year)
	if opinion_delta_override == 0:
		silver_award = 2 if accurate else 1
	actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) + silver_award
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
		"silver_awarded": silver_award,
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
		&"reconcile_accounts":
			var institution_id := StringName(data.get("institution_id", _institution_for_location(world, StringName(data.get("place_id", data.get("subject_id", ""))))))
			var institution: Dictionary = world.institutions.get(institution_id, {})
			var stock: Dictionary = institution.get("stockpiles", {})
			var total := 0
			for amount in stock.values():
				total += int(amount)
			if kind == &"form":
				summary = "The form is checked against the institution's current recorded position."
				facts = "DOCUMENT: %s\nURGENCY: %d\n%s" % [_form_title(StringName(data.get("form_type", ""))), int(data.get("urgency", 0)), _live_stock_facts(stock, institution)]
			else:
				summary = "The institution's current stock records are reconciled. No discrepancy is presumed without a separate expected balance."
				facts = "INSTITUTION: %s\nMEMBERS: %d / ACTIVITY RECORDS: %d\n%s" % [String(institution.get("name", institution_id)), int(data.get("member_count", institution.get("members", []).size())), int(data.get("activity_count", institution.get("activity_count", 0))), _live_stock_facts(stock, institution)]
			facts += "\nTABLET / STOREHOUSE: recorded barley %d; live barley %d; quantity gap %d." % [int(institution.get("stock_records", {}).get("barley_recorded", stock.get(&"barley", 0))), int(stock.get(&"barley", 0)), int(stock.get(&"barley", 0)) - int(institution.get("stock_records", {}).get("barley_recorded", stock.get(&"barley", 0)))]
			var ledger_records: Dictionary = institution.get("stock_records", {})
			if bool(ledger_records.get("concealed_spoilage", false)):
				facts += "\nTABLET / STOREHOUSE QUALITY GAP: tablet declares %s; physical tally records damp, mold-marked barley." % String(ledger_records.get("barley_quality_declaration", "unrecorded"))
			facts += "\n" + _stock_detail(stock, skill_level, "ARITHMETIC")
		&"examine_records":
			if kind == &"form":
				summary = "The form's origin and urgency are confirmed against the pending register."
				facts = "FORM: %s\nSUBJECT: %s\nURGENCY: %d\nGENERATED BY: %s\nREASON: %s" % [String(data.get("form_type", "")), _place_name(world, StringName(data.get("subject_id", ""))), int(data.get("urgency", 0)), String(data.get("generated_by", "world")), String(data.get("generation_reason", "routine office request")).replace("_", " ")]
			else:
				summary = "The written record is examined. The current account can be compared with the live institution state."
				facts = "SOURCE: %s\nPERIOD: %d\nSKILL: %s %d" % [String(record.get("source_id", "")), world.current_period_index(), "Literacy", skill_level]
		&"consult_official":
			var employer := world.get_person(StringName(record.get("employer_id", "")))
			var opinion := employer.get_opinion(actor.id) if employer != null else 0
			summary = "The responsible official gives a position and a demand. It is testimony, not proof."
			var stance := _official_stance(world, actor, employer, data, opinion)
			facts = "OFFICIAL: %s\nOPINION OF SCRIBE: %d\nOFFICE: %s\nSTANCE: “%s”" % [employer.display_name if employer != null else "No named official", opinion, String(employer.office_id) if employer != null else "Unassigned", stance]
		&"inspect_source":
			if kind == &"hazard":
				var hazard: Dictionary = record.get("source_data", {})
				facts = "SITE: %s\nHAZARD: %s\nLOSS / PERIOD: %d %s\nTOTAL RECORDED LOSS: %d" % [_place_name(world, StringName(hazard.get("place_id", ""))), String(hazard.get("id", "")), int(hazard.get("rate", 0)), String(hazard.get("resource", "")), int(hazard.get("total_lost", 0))]
				summary = "The active hazard is physically inspected. The recorded loss is checked against the current site condition."
			else:
				var institution_id := StringName(data.get("institution_id", _institution_for_location(world, StringName(data.get("place_id", data.get("subject_id", ""))))))
				var institution: Dictionary = world.institutions.get(institution_id, {})
				var stock: Dictionary = institution.get("stockpiles", {})
				var total := 0
				for amount in stock.values():
					total += int(amount)
				facts = "PHYSICAL SITE: %s\nBIN COUNT / BARLEY: %d | LABOR ROSTER: %d | TEXTILES: %d\nINSTITUTION: %s" % [_place_name(world, StringName(data.get("subject_id", data.get("place_id", "")))), int(stock.get(&"barley", 0)), int(stock.get(&"labor", 0)), int(stock.get(&"textiles", 0)), String(institution.get("name", institution_id))]
				var physical_records: Dictionary = institution.get("stock_records", {})
				if bool(physical_records.get("concealed_spoilage", false)):
					facts += "\nPHYSICAL FINDING: damp or mold-marked barley contradicts the prime seed-corn declaration."
				facts += "\n" + _live_stock_facts(stock, institution)
				summary = "The physical storehouse is inspected. These are the current bin and roster counts, not a clerk's tablet claim."
	var evidence_place := StringName(data.get("subject_id", data.get("place_id", "")))
	for hazard in world.hazards:
		if bool(hazard.get("active", false)) and StringName(hazard.get("place_id", "")) == evidence_place:
			facts += "\nACTIVE HAZARD: %s / loss %d %s each period" % [String(hazard.get("id", "hazard")).replace("_", " "), int(hazard.get("rate", 0)), String(hazard.get("resource", "")).replace("_", " ")]
	var npc_evidence: Dictionary = data.get("npc_evidence", {})
	if not npc_evidence.is_empty():
		facts += "\nAUTONOMOUS RECORDS"
		facts += "\nDISPATCH DOCKET: %s" % String(npc_evidence.get("dispatch_record", "No dispatch text recorded."))
		facts += "\nTHRESHOLD TALLY: %s" % String(npc_evidence.get("threshold_tally", "No threshold text recorded."))
		facts += "\nDISCREPANCY: %s" % String(npc_evidence.get("discrepancy", "No discrepancy description recorded."))
		summary += " The pending docket includes conflicting records generated by an autonomous grain-office action."
	if action_id == &"examine_records" and skill_level >= 2:
		facts += "\nGENERATION REASON: %s" % String(data.get("generation_reason", "not recorded"))
	elif action_id == &"consult_official" and skill_level >= 2:
		var consulted := world.get_person(StringName(record.get("employer_id", "")))
		if consulted != null:
			var tie: Dictionary = consulted.relationships.get(actor.id, {})
			facts += "\nRECORDED TRUST: %d / RELATIONSHIP: %s" % [int(tie.get("trust", 0)), String(tie.get("type", "unknown"))]
	facts += "\nCAPABILITY APPLIED: %s / LEVEL %d" % [String(action_id).replace("_", " ").to_upper(), skill_level]
	return {"summary": summary, "facts": facts, "skill_level": skill_level}

static func _stock_detail(stock: Dictionary, skill_level: int, skill_label: String) -> String:
	if stock.is_empty():
		return "No resource quantities are recorded."
	var ranked: Array[Dictionary] = []
	for resource_id in stock.keys():
		ranked.append({"id": String(resource_id), "amount": int(stock[resource_id])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.amount) == int(b.amount):
			return String(a.id) < String(b.id)
		return int(a.amount) > int(b.amount)
	)
	var first: Dictionary = ranked[0]
	var resource_name := String(first.id).replace("_", " ").capitalize()
	var detail := ""
	if skill_level < 1:
		detail = "The records identify stored resources, but no reliable ranking is established."
	elif skill_level == 1:
		detail = "Largest recorded reserve: %s / %d." % [resource_name, int(first.amount)]
	else:
		detail = "LARGEST RECORDED RESERVE: %s / %d" % [resource_name, int(first.amount)]
	if skill_level >= 3 and ranked.size() > 1:
		var second: Dictionary = ranked[1]
		detail += "\nNEXT RESERVE: %s / %d" % [String(second.id).replace("_", " ").capitalize(), int(second.amount)]
	return "%s DETAIL / LEVEL %d\n%s" % [skill_label, skill_level, detail]

static func _institution_for_location(world: WorldState, location_id: StringName) -> StringName:
	if location_id == &"":
		return &""
	# These Uruk work records are Eanna household responsibilities, not
	# agricultural-household or exchange ledgers merely because of their parent.
	for worksite_id in [&"ditch_labor_tally", &"textile_workshop", &"brewery_delivery", &"river_fish_supply"]:
		if location_id == worksite_id and world.institutions.has(&"eanna_household"):
			return &"eanna_household"
	var cursor := location_id
	var visited: Dictionary = {}
	while cursor != &"" and not visited.has(cursor):
		visited[cursor] = true
		for institution_id in world.institutions.keys():
			var institution: Dictionary = world.institutions[institution_id]
			if StringName(institution.get("place_id", "")) == cursor:
				return StringName(institution_id)
		var place: Dictionary = world.places.get(cursor, {})
		cursor = StringName(place.get("parent", ""))
	if visited.has(&"uruk") and world.institutions.has(&"eanna_household"):
		return &"eanna_household"
	return &""

static func _live_stock_facts(stock: Dictionary, institution: Dictionary) -> String:
	var thresholds: Dictionary = institution.get("pressure_thresholds", {})
	var lines := PackedStringArray()
	var resource_ids := stock.keys()
	resource_ids.sort()
	for resource_value in resource_ids:
		var resource_id := StringName(resource_value)
		var resource_label := String(resource_id).replace("_", " ").capitalize()
		var amount := int(stock[resource_value])
		lines.append("%s: %d" % [resource_label, amount])
		var threshold_key := StringName("%s_warn" % String(resource_id))
		if thresholds.has(threshold_key) and amount < int(thresholds[threshold_key]):
			lines.append("  Below the office's warning measure (%d)." % int(thresholds[threshold_key]))
		elif resource_id == &"labor" and thresholds.has(&"labor_warn") and amount < int(thresholds[&"labor_warn"]):
			lines.append("  Below the office's minimum labor measure (%d)." % int(thresholds[&"labor_warn"]))
	if lines.is_empty():
		lines.append("No stockpile resources are recorded for this institution.")
	var records: Dictionary = institution.get("stock_records", {})
	if bool(records.get("concealed_spoilage", false)):
		lines.append("The stock record notes concealed spoilage; declared quality: %s." % String(records.get("barley_quality_declaration", "unrecorded")).replace("_", " "))
	return "\n".join(lines)

static func _official_stance(world: WorldState, actor: PersonEntity, official: PersonEntity, data: Dictionary, opinion: int) -> String:
	if official == null:
		return "No official will answer for this entry. Ask the archive to name the responsible hand."
	var form_type := StringName(data.get("form_type", ""))
	var institution_id := StringName(data.get("institution_id", _institution_for_location(world, StringName(data.get("place_id", data.get("subject_id", ""))))))
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var records: Dictionary = institution.get("stock_records", {})
	var npc_evidence: Dictionary = data.get("npc_evidence", {})
	if not npc_evidence.is_empty() or bool(records.get("concealed_spoilage", false)):
		if official.office_id == &"grain_clerk":
			return "The seed-corn entry stands. The roof was poor, not my measure; certify the tablet and let the household keep its reserve."
		return "This contradiction will reach the archive unless you refer it. I ask you to preserve the office's standing—and name who bears the loss."
	if form_type in [&"bailiff_requisition", &"pension_roll"]:
		if official.office_id == &"canal_bailiff":
			return "The sluice is choked and the crew is short. Authorize labor now; the fields will pay for delay."
		return "The roll is not a plea for favor. Certify the shortage and write whose stores must be reassigned."
	if official.office_id == &"archive_keeper":
		return "Do not make a patron's seal into evidence. Enter the source, and let the record name the responsible office."
	if opinion >= 5 and (&"pliable" in official.traits or &"complicit" in official.traits):
		return "We have kept one another's accounts before. A clean seal now will be remembered in your favor."
	if opinion <= -5 or &"severe" in official.traits or &"exacting" in official.traits:
		return "Do not ask me to soften a figure. Show the source and state plainly who carries the consequence."
	return "The office asks for a clear finding: certify what the source supports, or refer what it cannot explain."

static func _preferred_office(form_type: StringName) -> StringName:
	match form_type:
		&"grain_levy", &"held_barley": return &"grain_clerk"
		&"pension_roll": return &"tax_scribe"
		&"consignment_receipt": return &"market_trader"
		&"bailiff_requisition": return &"canal_bailiff"
	return &""

static func _hazard_source(hazard: Dictionary, world: WorldState) -> Dictionary:
	var source := hazard.duplicate(true)
	var place_id := StringName(source.get("place_id", ""))
	source["institution_id"] = StringName(source.get("institution_id", _institution_for_location(world, place_id)))
	source["place_id"] = place_id
	return source

static func _resolve_local_employer(world: WorldState, institution_id: StringName, place_id: StringName, preferred_office_id: StringName) -> StringName:
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var members: Array = institution.get("members", [])
	for member_value in members:
		var member := world.get_person(StringName(member_value))
		if member != null and member.office_id != &"" and (preferred_office_id == &"" or member.office_id == preferred_office_id):
			return member.id
	for member_value in members:
		var member := world.get_person(StringName(member_value))
		if member != null and member.office_id != &"":
			return member.id
	var local_ids: Array[StringName] = []
	for person in world.people.values():
		if person != null and person.location_id == place_id:
			local_ids.append(person.id)
	local_ids.sort()
	if not local_ids.is_empty():
		return local_ids[0]
	if place_id == &"uruk":
		for person in world.people.values():
			if person != null and person.location_id == &"uruk" and (preferred_office_id == &"" or person.office_id == preferred_office_id):
				return person.id
	var fallback := _form_employer(world, &"pension_roll")
	if fallback != &"":
		return fallback
	return world.player_id

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
		&"grain_levy": "Grain Levy Assessment",
		&"pension_roll": "Workforce Roll",
		&"consignment_receipt": "Consignment Receipt",
		&"held_barley": "Held Barley Inspection",
		&"load_claim": "Load Allocation Claim"
	}
	return String(labels.get(form_type, String(form_type).replace("_", " ").capitalize()))

static func _is_local_to_current_location(world: WorldState, place_id: StringName) -> bool:
	if world == null or world.current_location_id == &"":
		return true
	if place_id == &"":
		return true
	if world.institutions.has(place_id):
		place_id = StringName(world.institutions[place_id].get("place_id", ""))
	if place_id == &"" or not world.places.has(place_id):
		# Unplaced forms are compound-wide until they receive a PlaceDef.
		return true
	var cursor := place_id
	var visited: Dictionary = {}
	while cursor != &"" and not visited.has(cursor):
		if cursor == world.current_location_id:
			return true
		visited[cursor] = true
		var place: Dictionary = world.places.get(cursor, {})
		cursor = StringName(place.get("parent", ""))
	return false

static func _epic_problem_label(reason: String) -> String:
	match reason:
		"labor_shortage": return "Labor Shortage Review"
		"barley_shortage": return "Ration Shortage Review"
		"site_hazard": return "Site Disruption Review"
		"scandal_audit": return "Audit Inquiry"
		_: return "Project Conditions Review"

static func _place_name(world: WorldState, place_id: StringName) -> String:
	if place_id == &"":
		return "the institution"
	if world.places.has(place_id):
		return String(world.places[place_id].get("name", place_id))
	return String(place_id).replace("_", " ").capitalize()


static func _project_review_due(world: WorldState, epic_id: StringName, epic: Dictionary, progress: int) -> bool:
	var current_stage := String(epic.get("stage", ""))
	var current_cycle := int(epic.get("review_cycle", 0))
	for assignment_value in world.assignments.values():
		var active_assignment: Dictionary = assignment_value
		if StringName(active_assignment.get("kind", "")) != &"project_review" or StringName(active_assignment.get("source_id", "")) != epic_id:
			continue
		var active_source: Dictionary = active_assignment.get("source_data", {})
		if int(active_assignment.get("review_cycle", active_source.get("review_cycle", 0))) == current_cycle and String(active_assignment.get("status", "")) == "active":
			return false
	if epic.has("last_reviewed_progress"):
		var reviewed_progress := int(epic.get("last_reviewed_progress", -1))
		var reviewed_stage := String(epic.get("last_reviewed_stage", ""))
		return current_stage != reviewed_stage or progress >= reviewed_progress + 20

	# Migrate older saves from completed assignment records. Active reviews block
	# another; completed reviews return after a stage change or twenty progress.
	var latest_review: Dictionary = {}
	var latest_period := -1
	for assignment_value in world.assignments.values():
		var assignment: Dictionary = assignment_value
		if StringName(assignment.get("kind", "")) != &"project_review" or StringName(assignment.get("source_id", "")) != epic_id:
			continue
		var assignment_source: Dictionary = assignment.get("source_data", {})
		if int(assignment.get("review_cycle", assignment_source.get("review_cycle", 0))) != current_cycle:
			continue
		if String(assignment.get("status", "")) == "active":
			return false
		var completed_period := int(assignment.get("completed_period", assignment.get("started_period", -1)))
		if completed_period >= latest_period:
			latest_period = completed_period
			latest_review = assignment
	if latest_review.is_empty():
		return true
	var source_data: Dictionary = latest_review.get("source_data", {})
	var reviewed_progress := int(latest_review.get("reviewed_progress", source_data.get("progress", -1)))
	var reviewed_stage := String(latest_review.get("reviewed_stage", source_data.get("stage", "")))
	if reviewed_progress < 0:
		return false
	return current_stage != reviewed_stage or progress >= reviewed_progress + 20