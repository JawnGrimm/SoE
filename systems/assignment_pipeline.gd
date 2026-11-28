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
		var form_id := StringName(form.get("id", ""))
		if form_id == &"":
			continue
		var form_type := StringName(form.get("form_type", ""))
		var institution_id := StringName(form.get("institution_id", _institution_for_location(world, subject_id)))
		var institution: Dictionary = world.institutions.get(institution_id, {})
		var place_id := StringName(form.get("place_id", subject_id))
		if institution_id != &"":
			place_id = StringName(institution.get("place_id", place_id))
		var is_local := _is_local_to_current_location(world, subject_id) or _is_local_to_current_location(world, place_id)
		var created_period := int(form.get("created_period", int(form.get("year", world.year)) * WorldState.PERIODS_PER_YEAR + int(form.get("period", world.period))))
		var age_periods := maxi(0, world.current_period_index() - created_period)
		var form_name := String(form.get("form_type", "")).to_lower()
		var is_requisition := bool(form.get("is_requisition", false)) or form_name.contains("requisition")
		var is_external := institution_id != &"" and not is_local
		var is_dispatch := bool(form.get("dispatch", false)) or (is_external and is_requisition and age_periods > 4)
		if not is_local and not is_dispatch:
			continue
		var subject_name := _place_name(world, subject_id if subject_id != &"" else place_id)
		var urgency := int(form.get("urgency", 1))
		var form_title := _form_title(form_type)
		var form_summary := "%s requires an assessment at %s." % [form_title, subject_name]
		var form_source := form.duplicate(true)
		form_source["institution_id"] = institution_id
		form_source["place_id"] = place_id
		var npc_evidence: Dictionary = form.get("npc_evidence", {})
		if not npc_evidence.is_empty():
			form_title = "Contradictory North-Bay Grain Docket"
			form_summary = "Two records disagree about the barley held at %s. The dispatch docket declares prime seed-corn; the threshold tally records damp, mold-marked grain." % subject_name
		var dispatch_tag := "DISPATCH FROM %s" % _place_name(world, place_id).to_upper() if is_dispatch else ""
		if is_dispatch:
			form_summary = "A provincial requisition from %s has remained unanswered for %d periods. The provincial office now demands an answer." % [_place_name(world, place_id), age_periods]
		var base_priority := maxi(2 + urgency, int(form.get("priority", 0)))
		candidates.append({
			"id": StringName("work_form_%s_%d" % [form_id, world.current_period_index()]),
			"kind": &"form",
			"source_id": form_id,
			"title": form_title,
			"summary": form_summary,
			"priority": 8 if is_dispatch else (6 if not npc_evidence.is_empty() else base_priority),
			"tags": [dispatch_tag] if is_dispatch else [],
			"dispatch": is_dispatch,
			"requires_travel": is_dispatch and not is_local,
			"dispatch_destination_id": place_id if is_dispatch else &"",
			"age_periods": age_periods,
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
		var is_local_review := _is_local_to_current_location(world, place_id)
		var remote_canal_review := StringName(epic_id) == &"great_canal_cut" and world.current_location_id in [&"umma", &"nippur"] and not is_local_review
		if not is_local_review and not remote_canal_review:
			continue
		var progress := int(epic.get("progress", world.get_resource(StringName(epic.get("progress_resource", "")))))
		var target := int(epic.get("target", 100))
		var review_stage := int(epic.get("review_stage", world.get_epic_stage_index(progress, target)))
		var stage_label := String(epic.get("review_stage_label", world.get_epic_stage_label(review_stage)))
		var review_reason := String(epic.get("review_reason", "stage_reached"))
		var title_suffix := stage_label if review_reason in ["project_opened", "stage_reached"] else _epic_problem_label(review_reason)
		var review_summary := String(epic.get("review_summary", "Review labor, supply, and project progress."))
		if remote_canal_review:
			review_summary = "[REQUIRES TRAVEL TO URUK] " + review_summary + " Book passage on the regional survey map to convene this review."
		candidates.append({
			"id": StringName("epic:%s:r%d:s%d" % [epic_id, int(epic.get("review_cycle", 0)), review_stage]),
			"review_cycle": int(epic.get("review_cycle", 0)),
			"kind": &"project_review",
			"source_id": StringName(epic_id),
			"sponsor_institution": sponsor_id,
			"place_id": place_id,
			"title": "%s — %s" % [String(epic.get("title", epic_id)), title_suffix],
			"summary": "%s (%d / %d)." % [review_summary.trim_suffix("."), progress, target],
			"requires_travel": remote_canal_review,
			"tags": ["REQUIRES TRAVEL TO URUK"] if remote_canal_review else [],
			"priority": 90 if remote_canal_review else 2 + _career_bonus(selected_path, &"project"),
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
	# Aged provincial dispatches are compulsory board business, like Epic reviews.
	# Keep the highest-priority dispatch visible even when routine slots are full.
	for candidate in candidates:
		if bool(candidate.get("dispatch", false)):
			result.append(candidate.duplicate(true))
			break
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
		if bool(candidate.get("dispatch", false)) or kind in [&"project_review", &"procedural_docket"]:
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
	if bool(opportunity.get("requires_travel", false)):
		var destination_id := StringName(opportunity.get("dispatch_destination_id", opportunity.get("place_id", "")))
		if destination_id == &"" or world.current_location_id != destination_id:
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
	var custom_verdict := false
	var custom_skill_id: StringName = &""
	var custom_skill_xp := 0
	var silver_before := int(actor.resources.get(&"silver", 0))
	var traits_before: Array[StringName] = actor.traits.duplicate()
	var debt_before := int(actor.resources.get(&"debt", 0))
	var exposure_before := int(actor.flags.get(&"audit_exposure", 0))
	var opinion_before: Dictionary[StringName, int] = {}
	for person_value in world.people.values():
		if person_value != null and person_value.id != actor.id:
			opinion_before[person_value.id] = person_value.get_opinion(actor.id)
	var skill_levels_before: Dictionary[StringName, int] = {}
	for skill_key in [&"literacy", &"arithmetic", &"law", &"rhetoric", &"intrigue", &"stewardship"]:
		skill_levels_before[skill_key] = actor.skills.get_level(skill_key)
	var actor_flags_before: Dictionary = actor.flags.duplicate(true)
	var world_flags_before: Dictionary = world.world_flags.duplicate(true)
	var opinion_reasons: Dictionary[StringName, String] = {}
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
					opinion_reasons[archivist.id] = "The apprentice referred a concealed grain account for correction."
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
			var sponsor_id := StringName(record.get("sponsor_institution", project_state.get("sponsor_institution", &"eanna_household")))
			var notes: Array = project_state.get("history_notes", [])
			var reviewed_stage := String(project_state.get("stage", "unrecorded"))
			work_details = "Progress %d / %d. Current stage: %s. Recorded simulation entries: %d." % [progress, target, reviewed_stage, notes.size()]
			match verdict:
				&"epic_emergency":
					silver_award = 0
					if world.get_resource(&"barley", "institution", "", sponsor_id) < 20 or world.get_resource(&"labor", "institution", "", sponsor_id) < 2:
						return {"success": false, "message": "The sponsor cannot spare 20 barley and 2 labor. No resources were spent."}
					if not world.modify_resource(&"barley", -20, "institution", "", sponsor_id):
						return {"success": false, "message": "The barley allocation failed; the review remains open."}
					if not world.modify_resource(&"labor", -2, "institution", "", sponsor_id):
						world.modify_resource(&"barley", 20, "institution", "", sponsor_id)
						return {"success": false, "message": "The labor allocation failed; the barley was returned."}
					if not world.modify_resource(progress_resource, 15, "world"):
						world.modify_resource(&"labor", 2, "institution", "", sponsor_id)
						world.modify_resource(&"barley", 20, "institution", "", sponsor_id)
						return {"success": false, "message": "Epic progress could not be advanced; sponsor resources were returned."}
					project_state["progress"] = world.get_resource(progress_resource)
					project_state["stalled"] = false
					project_state["active_problem"] = ""
					result_text = "Twenty barley and two labor are released from the sponsor. Emergency rations reach the crews; the canal cut advances by fifteen progress."
				&"epic_audit":
					var foreman_id := StringName(project_state.get("foreman_id", &"enlil_kisu"))
					var foreman := world.get_person(foreman_id)
					if foreman != null:
						foreman.change_opinion(actor.id, -3, "Halted the canal cut to challenge the foreman's labor roll.", world.year)
						opinion_reasons[foreman.id] = "Halted the canal cut to challenge the foreman's labor roll."
					actor.skills.add_xp(&"law", 15)
					custom_skill_id = &"law"
					custom_skill_xp = 15
					actor.flags[&"audit_exposure"] = maxi(0, int(actor.flags.get(&"audit_exposure", 0)) - 1)
					silver_award = 0
					opinion_delta_override = -3
					project_state["stalled"] = true
					project_state["audit_hold_until_period"] = world.current_period_index() + 1
					result_text = "The cut is halted pending an audit. The foreman's standing with you falls by three; your law skill gains fifteen experience, and one audit exposure is cleared."
				&"epic_certify":
					if not world.modify_resource(progress_resource, 10, "world"):
						return {"success": false, "message": "Epic progress could not be advanced; no gratuity was accepted."}
					project_state["progress"] = world.get_resource(progress_resource)
					actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) + 2
					silver_award = 2
					if not actor.traits.has(&"pliable"):
						actor.traits.append(&"pliable")
					actor.flags[&"audit_exposure"] = int(actor.flags.get(&"audit_exposure", 0)) + 1
					world.set_flag(&"entangled_brewery_accounts", -1)
					result_text = "The milestone is certified on the crew's estimate. The cut advances by ten; two silver enter your purse, and the account acquires a pliable scribe, one more audit exposure, and entangled brewery accounts."
				_:
					return {"success": false, "message": "Choose one of the available Epic verdicts."}
			# Each Epic verdict owns its consequence text; do not replace it with a generic receipt.
			custom_verdict = true
			accurate = false
			project_state["last_reviewed_progress"] = progress
			project_state["last_reviewed_stage"] = reviewed_stage
			world.epics[source_id] = project_state
			record["reviewed_progress"] = progress
			record["reviewed_stage"] = reviewed_stage
			record["review_cycle"] = int(project_state.get("review_cycle", 0))
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
			match verdict:
				&"pressure_drawdown":
					if world.get_resource(&"barley", "institution", "", pressure_institution_id) < 15 or world.get_resource(&"labor", "institution", "", pressure_institution_id) < 15:
						return {"success": false, "message": "The reserves cannot cover 15 barley and 15 labor. No resources were spent."}
					if not world.modify_resource(&"barley", -15, "institution", "", pressure_institution_id):
						return {"success": false, "message": "The barley drawdown failed; no verdict was filed."}
					if not world.modify_resource(&"labor", -15, "institution", "", pressure_institution_id):
						world.modify_resource(&"barley", 15, "institution", "", pressure_institution_id)
						return {"success": false, "message": "The labor drawdown failed; barley was returned."}
					institution["resource_pressure"] = 0
					institution["local_opinion"] = int(institution.get("local_opinion", 0)) + 2
					silver_award = 0
					opinion_delta_override = 2
					result_text = "Fifteen barley and fifteen labor are drawn from local reserves. The immediate pressure is cleared; local opinion improves by two."
				&"pressure_ration":
					institution["local_opinion"] = int(institution.get("local_opinion", 0)) - 3
					silver_award = 0
					opinion_delta_override = -3
					world.set_flag(&"thirsty_diggers", -1)
					result_text = "Strict rationing is enforced. The pressure remains active, local opinion falls by three, and the diggers' thirst is entered in the record."
				&"pressure_falsify":
					actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) + 3
					silver_award = 3
					actor.flags[&"audit_exposure"] = int(actor.flags.get(&"audit_exposure", 0)) + 2
					world.set_flag(&"phantom_barley_measure", -1)
					result_text = "The balance is falsified. Three silver are pocketed; audit exposure rises by two, and the phantom barley measure enters the world record."
				_:
					return {"success": false, "message": "Choose one of the available pressure verdicts."}
			custom_verdict = true
			accurate = false
			var latest_institution: Dictionary = world.institutions.get(pressure_institution_id, {})
			institution["stockpiles"] = latest_institution.get("stockpiles", institution.get("stockpiles", {}))
			world.institutions[pressure_institution_id] = institution
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
	var opinion_delta := opinion_delta_override if opinion_delta_override != 0 else (0 if custom_verdict else (1 if accurate else -1))
	if not custom_verdict:
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
		"skill_awarded": String(custom_skill_id) if custom_verdict else ("law" if accurate else "arithmetic"),
		"skill_xp": custom_skill_xp if custom_verdict else (12 if accurate else 6),
		"path_id": String(record.get("path_id", ""))
	})
	actor.memory.append({
		"memory_id": &"assignment_assessment",
		"text": "%s — %s" % [String(record.get("title", "Assignment")), result_text],
		"year": world.year,
		"involved": [String(source_id)]
	})
	if custom_verdict:
		world.record_case_settlement(actor, silver_before, traits_before)
	else:
		world.record_case_settlement(actor, int(actor.resources.get(&"silver", 0)) - (2 if accurate else 1), actor.traits.duplicate())
	var consequences: Array[Dictionary] = []
	var skill_for_xp := custom_skill_id if custom_skill_id != &"" else (&"law" if accurate else &"arithmetic")
	var xp_for_skill := custom_skill_xp if custom_verdict else (12 if accurate else 6)
	if skill_for_xp != &"" and xp_for_skill > 0:
		consequences.append({"type": "xp", "skill": skill_for_xp, "delta": xp_for_skill})
		var level_after := actor.skills.get_level(skill_for_xp)
		var level_before := int(skill_levels_before.get(skill_for_xp, level_after))
		if level_after > level_before:
			consequences.append({"type": "level_up", "skill": skill_for_xp, "new_level": level_after})
	for person_value in world.people.values():
		if person_value == null or person_value.id == actor.id:
			continue
		var opinion_change: int = person_value.get_opinion(actor.id) - int(opinion_before.get(person_value.id, person_value.get_opinion(actor.id)))
		if opinion_change == 0:
			continue
		var office_title := String(person_value.office_id).replace("_", " ").capitalize() if person_value.office_id != &"" else "Official"
		var opinion_reason := String(opinion_reasons.get(person_value.id, record.get("opinion_reason", "Assignment assessment: %s" % String(record.get("title", "")))))
		if StringName(record.get("kind", "")) == &"project_review" and person_value.id == StringName(record.get("source_data", {}).get("foreman_id", &"enlil_kisu")):
			opinion_reason = "Halted the canal cut to challenge the foreman's labor roll."
		consequences.append({"type": "opinion", "target_name": person_value.display_name, "target_title": office_title, "delta": opinion_change, "reason": opinion_reason})
	var silver_delta := int(actor.resources.get(&"silver", 0)) - silver_before
	if silver_delta != 0:
		consequences.append({"type": "silver", "delta": silver_delta})
	var debt_delta := int(actor.resources.get(&"debt", 0)) - debt_before
	if debt_delta != 0:
		consequences.append({"type": "debt", "delta": debt_delta})
	var exposure_delta := int(actor.flags.get(&"audit_exposure", 0)) - exposure_before
	if exposure_delta != 0:
		consequences.append({"type": "exposure", "delta": exposure_delta})
	for trait_value in actor.traits:
		if trait_value not in traits_before:
			consequences.append({"type": "trait", "name": String(trait_value).capitalize()})
	for flag_key in actor.flags:
		if flag_key == &"audit_exposure":
			continue
		if not actor_flags_before.has(flag_key) or actor_flags_before[flag_key] != actor.flags[flag_key]:
			consequences.append({"type": "flag", "name": String(flag_key)})
	for flag_key in world.world_flags:
		if not world_flags_before.has(flag_key) or world_flags_before[flag_key] != world.world_flags[flag_key]:
			consequences.append({"type": "flag", "name": String(flag_key)})
	return {"success": true, "message": result_text, "accurate": accurate, "consequences": consequences}

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
			if kind == &"form":
				summary = "%s at %s: %s" % [String(institution.get("name", institution_id)), _place_name(world, StringName(data.get("place_id", data.get("subject_id", "")))), _live_stock_facts(stock, institution)]
				facts = "DOCUMENT: %s\nURGENCY: %d\n%s" % [_form_title(StringName(data.get("form_type", ""))), int(data.get("urgency", 0)), _live_stock_facts(stock, institution)]
			else:
				summary = "%s: %s" % [String(institution.get("name", institution_id)), _live_stock_facts(stock, institution)]
				facts = "INSTITUTION: %s\nMEMBERS: %d / ACTIVITY RECORDS: %d\n%s" % [String(institution.get("name", institution_id)), int(data.get("member_count", institution.get("members", []).size())), int(data.get("activity_count", institution.get("activity_count", 0))), _live_stock_facts(stock, institution)]
			if stock.has(&"barley") or institution.get("stock_records", {}).has("barley_recorded"):
				facts += "\nTABLET / STOREHOUSE: recorded barley %d; live barley %d; quantity gap %d." % [int(institution.get("stock_records", {}).get("barley_recorded", stock.get(&"barley", 0))), int(stock.get(&"barley", 0)), int(stock.get(&"barley", 0)) - int(institution.get("stock_records", {}).get("barley_recorded", stock.get(&"barley", 0)))]
			var ledger_records: Dictionary = institution.get("stock_records", {})
			if bool(ledger_records.get("concealed_spoilage", false)):
				facts += "\nTABLET / STOREHOUSE QUALITY GAP: tablet declares %s; physical tally records damp, mold-marked barley." % String(ledger_records.get("barley_quality_declaration", "unrecorded"))
			facts += "\n" + _stock_detail(stock, skill_level, "ARITHMETIC")
		&"examine_records":
			if kind == &"form":
				summary = "%s for %s; entered by %s at urgency %d." % [_form_title(StringName(data.get("form_type", ""))), _place_name(world, StringName(data.get("subject_id", ""))), employer_name_for_record(world, record), int(data.get("urgency", 0))]
				facts = "DOCUMENT: %s\nSUBJECT: %s\nURGENCY: %d\nRESPONSIBLE OFFICIAL: %s" % [_form_title(StringName(data.get("form_type", ""))), _place_name(world, StringName(data.get("subject_id", ""))), int(data.get("urgency", 0)), employer_name_for_record(world, record)]
			else:
				facts = "RECORD: %s\nPERIOD: %d" % [String(record.get("title", "")), world.current_period_index()]
				summary = String(record.get("summary", record.get("title", "")))
		&"consult_official":
			var employer := world.get_person(StringName(record.get("employer_id", "")))
			if employer == null:
				push_error("AssignmentPipeline: assignment '%s' has no responsible official to interview." % String(record.get("id", "")))
				return {}
			var opinion := employer.get_opinion(actor.id)
			var stance := _official_stance(world, actor, employer, data, opinion)
			if stance.is_empty():
				return {}
			summary = "%s states: %s" % [employer.display_name, stance]
			facts = "OFFICIAL: %s\nOPINION OF SCRIBE: %d\nOFFICE: %s\nSTANCE: “%s”" % [employer.display_name, opinion, String(employer.office_id), stance]
		&"inspect_source":
			if kind == &"hazard":
				var hazard: Dictionary = record.get("source_data", {})
				facts = "SITE: %s\nHAZARD: %s\nLOSS / PERIOD: %d %s\nTOTAL RECORDED LOSS: %d" % [_place_name(world, StringName(hazard.get("place_id", ""))), String(hazard.get("id", "")), int(hazard.get("rate", 0)), String(hazard.get("resource", "")), int(hazard.get("total_lost", 0))]
				summary = "%s at %s: %d %s lost each period; %d recorded in total." % [String(hazard.get("id", "")).replace("_", " "), _place_name(world, StringName(hazard.get("place_id", ""))), int(hazard.get("rate", 0)), String(hazard.get("resource", "")).replace("_", " "), int(hazard.get("total_lost", 0))]
			else:
				var institution_id := StringName(record.get("sponsor_institution", record.get("source_data", {}).get("sponsor_institution", data.get("institution_id", _institution_for_location(world, StringName(data.get("place_id", data.get("subject_id", ""))))))))
				var institution: Dictionary = world.institutions.get(institution_id, {})
				var stock: Dictionary = institution.get("stockpiles", {})
				facts = "PHYSICAL SITE: %s\nINSTITUTION: %s\n%s" % [_place_name(world, StringName(data.get("subject_id", data.get("place_id", "")))), String(institution.get("name", institution_id)), _live_stock_facts(stock, institution)]
				var physical_records: Dictionary = institution.get("stock_records", {})
				if bool(physical_records.get("concealed_spoilage", false)):
					facts += "\nPHYSICAL FINDING: damp or mold-marked barley contradicts the prime seed-corn declaration."
				summary = "%s at %s: %s" % [String(institution.get("name", institution_id)), _place_name(world, StringName(data.get("subject_id", data.get("place_id", "")))), _live_stock_facts(stock, institution)]
	var evidence_place := StringName(data.get("subject_id", data.get("place_id", "")))
	for hazard in world.hazards:
		if bool(hazard.get("active", false)) and StringName(hazard.get("place_id", "")) == evidence_place:
			facts += "\nACTIVE HAZARD: %s / loss %d %s each period" % [String(hazard.get("id", "hazard")).replace("_", " "), int(hazard.get("rate", 0)), String(hazard.get("resource", "")).replace("_", " ")]
	var npc_evidence: Dictionary = data.get("npc_evidence", {})
	if not npc_evidence.is_empty():
		facts += "\nAUTONOMOUS RECORDS"
		if not String(npc_evidence.get("dispatch_record", "")).is_empty():
			facts += "\nDISPATCH DOCKET: %s" % String(npc_evidence.get("dispatch_record", ""))
		if not String(npc_evidence.get("threshold_tally", "")).is_empty():
			facts += "\nTHRESHOLD TALLY: %s" % String(npc_evidence.get("threshold_tally", ""))
		if not String(npc_evidence.get("discrepancy", "")).is_empty():
			facts += "\nDISCREPANCY: %s" % String(npc_evidence.get("discrepancy", ""))

	elif action_id == &"consult_official" and skill_level >= 2:
		var consulted := world.get_person(StringName(record.get("employer_id", "")))
		if consulted != null:
			var tie: Dictionary = consulted.relationships.get(actor.id, {})
			facts += "\nRECORDED TRUST: %d / RELATIONSHIP: %s" % [int(tie.get("trust", 0)), String(tie.get("type", "unknown"))]

	facts = _sanitize_evidence_text(facts)
	summary = _sanitize_evidence_text(summary)
	return {"summary": summary, "facts": facts, "skill_level": skill_level}


static func employer_name_for_record(world: WorldState, record: Dictionary) -> String:
	var employer := world.get_person(StringName(record.get("employer_id", ""))) if world != null else null
	if employer == null:
		push_error("AssignmentPipeline: assignment '%s' has no responsible official." % String(record.get("id", "")))
		return ""
	return employer.display_name

static func _sanitize_evidence_text(value: String) -> String:
	var kept := PackedStringArray()
	for line in value.split("\n"):
		if line.strip_edges().begins_with("CAPABILITY APPLIED:"):
			continue
		var clean_line := line
		var form_pattern := RegEx.new()
		form_pattern.compile("form_[0-9]+")
		if form_pattern.search(clean_line) != null:
			push_error("AssignmentPipeline: internal form identifier reached evidence presentation.")
			continue
		var hazard_pattern := RegEx.new()
		hazard_pattern.compile("hazard_id:\\s*([a-z0-9_]+)")
		var hazard_match := hazard_pattern.search(clean_line)
		if hazard_match != null:
			clean_line = clean_line.replace(hazard_match.get_string(0), "SITE ISSUE: " + hazard_match.get_string(1).replace("_", " ").capitalize())
		kept.append(clean_line)
	return "\n".join(kept)

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
	var detail := "Recorded quantities: %s." % _format_stockpile_list(stock)
	if skill_level >= 1:
		detail = "Largest recorded reserve: %s / %d." % [resource_name, int(first.amount)]
	if skill_level >= 3 and ranked.size() > 1:
		var second: Dictionary = ranked[1]
		detail += "\nNext reserve: %s / %d." % [String(second.id).replace("_", " ").capitalize(), int(second.amount)]
	return "%s: %s" % [skill_label.capitalize(), detail]

static func _format_stockpile_list(stock: Dictionary) -> String:
	var entries := PackedStringArray()
	for resource_id in stock:
		entries.append("%s %d" % [String(resource_id).replace("_", " "), int(stock[resource_id])])
	return ", ".join(entries)

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
	if stock.is_empty():
		return "COMMODITY BALANCES: None on record"
	var thresholds: Dictionary = institution.get("pressure_thresholds", {})
	var lines := PackedStringArray()
	var resource_ids := stock.keys()
	resource_ids.sort()
	for resource_value in resource_ids:
		var resource_id := StringName(resource_value)
		var resource_label := String(resource_id).replace("_", " ").capitalize()
		var amount := int(stock[resource_value])
		if resource_id in [&"barley", &"labor", &"textiles"] and amount == 0 and not thresholds.has(StringName("%s_warn" % String(resource_id))):
			continue
		lines.append("%s: %d" % [resource_label, amount])
		var threshold_key := StringName("%s_warn" % String(resource_id))
		if thresholds.has(threshold_key) and amount < int(thresholds[threshold_key]):
			lines.append("  Below the office's warning measure (%d)." % int(thresholds[threshold_key]))
		elif resource_id == &"labor" and thresholds.has(&"labor_warn") and amount < int(thresholds[&"labor_warn"]):
			lines.append("  Below the office's minimum labor measure (%d)." % int(thresholds[&"labor_warn"]))
	if lines.is_empty():
		return "COMMODITY BALANCES: None on record"
	var records: Dictionary = institution.get("stock_records", {})
	if bool(records.get("concealed_spoilage", false)):
		lines.append("The stock record notes concealed spoilage; declared quality: %s." % String(records.get("barley_quality_declaration", "unrecorded")).replace("_", " "))
	return "\n".join(lines)

static var _official_stance_data: Dictionary = {}

static func _official_stance(world: WorldState, _actor: PersonEntity, official: PersonEntity, data: Dictionary, opinion: int) -> String:
	if official == null:
		push_error("AssignmentPipeline: cannot prepare an interview without a responsible official.")
		return ""
	if _official_stance_data.is_empty():
		var stance_file := FileAccess.open("res://data/dialogue/official_stances.json", FileAccess.READ)
		if stance_file == null:
			push_error("AssignmentPipeline: authored official stance data is missing.")
			return ""
		var parsed: Variant = JSON.parse_string(stance_file.get_as_text())
		if not parsed is Dictionary:
			push_error("AssignmentPipeline: authored official stance data is invalid.")
			return ""
		_official_stance_data = parsed
	var form_type := StringName(data.get("form_type", ""))
	var institution_id := StringName(data.get("institution_id", _institution_for_location(world, StringName(data.get("place_id", data.get("subject_id", ""))))))
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var records: Dictionary = institution.get("stock_records", {})
	var npc_evidence: Dictionary = data.get("npc_evidence", {})
	var stance_id := "office_profile"
	if not npc_evidence.is_empty() or bool(records.get("concealed_spoilage", false)):
		stance_id = "grain_clerk_conflict" if official.office_id == &"grain_clerk" else "other_office_conflict"
	elif form_type in [&"bailiff_requisition", &"pension_roll"]:
		stance_id = "canal_bailiff_requisition" if official.office_id == &"canal_bailiff" else "other_office_requisition"
	elif official.office_id == &"archive_keeper":
		stance_id = "archive_keeper"
	elif opinion >= 5 and (&"pliable" in official.traits or &"complicit" in official.traits):
		stance_id = "trusted_complicit"
	elif opinion <= -5 or &"severe" in official.traits or &"exacting" in official.traits:
		stance_id = "hostile_exacting"
	var statement := String(_official_stance_data.get(stance_id, ""))
	if stance_id == "office_profile":
		var office_profiles: Dictionary = _official_stance_data.get("office_profiles", {})
		statement = String(office_profiles.get(String(official.office_id), ""))
	if statement.is_empty():
		push_error("AssignmentPipeline: missing official stance data '%s' for office '%s'." % [stance_id, String(official.office_id)])
		return ""
	var stock: Dictionary = institution.get("stockpiles", {})
	var place_id := StringName(data.get("place_id", data.get("subject_id", "")))
	var form_titles: Dictionary = _official_stance_data.get("form_titles", {})
	var values := {
		"official_name": official.display_name,
		"scribe_name": world.get_player().display_name if world.get_player() != null else "",
		"office_name": String(official.office_id).replace("_", " ").capitalize(),
		"institution_name": String(institution.get("name", "")),
		"place_name": _place_name(world, place_id),
		"form_title": String(form_titles.get(String(form_type), "")),
		"labor": str(int(stock.get(&"labor", 0))),
		"barley": str(int(stock.get(&"barley", 0))),
		"dispatch_record": String(npc_evidence.get("dispatch_record", "No dispatch docket is attached.")),
		"threshold_tally": String(npc_evidence.get("threshold_tally", "No independent threshold tally is attached."))
	}
	for key in values:
		var token := "{%s}" % String(key)
		if statement.contains(token) and String(values[key]).strip_edges().is_empty():
			push_error("AssignmentPipeline: official stance '%s' requires missing context '%s'." % [stance_id, String(key)])
			return ""
		statement = statement.replace(token, String(values[key]))
	var unresolved := RegEx.new()
	unresolved.compile("\\{[a-zA-Z0-9_]+\\}")
	if unresolved.search(statement) != null:
		push_error("AssignmentPipeline: unresolved substitution in official stance '%s'." % stance_id)
		return ""
	return statement

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
		var last_reviewed_progress := int(epic.get("last_reviewed_progress", -1))
		var last_reviewed_stage := String(epic.get("last_reviewed_stage", ""))
		return current_stage != last_reviewed_stage or progress >= last_reviewed_progress + 20

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
