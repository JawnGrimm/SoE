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

static func generate_opportunities(world: WorldState, actor: PersonEntity, selected_path: StringName = &"") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if world == null or actor == null:
		return candidates

	for form in world.pending_forms:
		var form_id := StringName(form.get("id", ""))
		if form_id == &"":
			continue
		var form_type := StringName(form.get("form_type", ""))
		var subject_id := StringName(form.get("subject_id", ""))
		var subject_name := _place_name(world, subject_id)
		var urgency := int(form.get("urgency", 1))
		var overdue := String(form.get("status", "pending")) == "overdue"
		candidates.append({
			"id": StringName("work_form_%s_%d" % [form_id, world.current_period_index()]),
			"kind": &"form",
			"source_id": form_id,
			"title": _form_title(form_type),
			"summary": "%s requires an assessment at %s." % [_form_title(form_type), subject_name],
			"priority": urgency + (3 if overdue else 0),
			"employer_id": &"ur_nanna" if world.get_person(&"ur_nanna") != null else &"",
			"source_data": form.duplicate(true),
			"path_id": selected_path
		})

	for hazard in world.hazards:
		if not bool(hazard.get("active", false)):
			continue
		var hazard_id := StringName(hazard.get("id", ""))
		var place_id := StringName(hazard.get("place_id", ""))
		candidates.append({
			"id": StringName("work_hazard_%s_%d" % [hazard_id, world.current_period_index()]),
			"kind": &"hazard",
			"source_id": hazard_id,
			"title": "Inspect %s" % _place_name(world, place_id),
			"summary": "An active %s continues to damage institutional stores." % String(hazard_id).replace("_", " "),
			"priority": 4 + int(hazard.get("rate", 0)),
			"employer_id": &"ur_nanna" if world.get_person(&"ur_nanna") != null else &"",
			"source_data": hazard.duplicate(true),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var pressure := int(institution.get("resource_pressure", 0))
		if pressure < 1:
			continue
		candidates.append({
			"id": StringName("work_pressure_%s_%d" % [institution_id, world.current_period_index()]),
			"kind": &"pressure",
			"source_id": StringName(institution_id),
			"title": "%s / Resource Pressure" % String(institution.get("name", institution_id)),
			"summary": "The institution reports a pressure index of %d. Its current stockpiles need review." % pressure,
			"priority": 2 + pressure,
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": {"institution_id": StringName(institution_id), "pressure": pressure},
			"path_id": selected_path
		})

	# Routine reconciliation is real work against each institution's actual
	# stockpile record. It is not a fabricated shortage or a scripted dispute.
	for epic_id in world.epics.keys():
		var epic: Dictionary = world.epics[epic_id]
		if not bool(epic.get("active", false)) or bool(epic.get("completed", false)):
			continue
		var progress := world.get_resource(StringName(epic.get("progress_resource", "")))
		var target := int(epic.get("target", 100))
		if target <= 0 or progress >= target:
			continue
		candidates.append({
			"id": StringName("work_project_%s_%d" % [epic_id, world.current_period_index()]),
			"kind": &"project_review",
			"source_id": StringName(epic_id),
			"title": "%s / Progress Review" % String(epic.get("title", epic_id)),
			"summary": "The active public work stands at %d of %d. Its current labor and provisioning position requires review." % [progress, target],
			"priority": 2,
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": epic.duplicate(true),
			"path_id": selected_path
		})

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var routine_id := StringName("work_ledger_%s_%d" % [institution_id, world.current_period_index()])
		candidates.append({
			"id": routine_id,
			"kind": &"ledger",
			"source_id": StringName(institution_id),
			"title": "%s / Periodic Account" % String(institution.get("name", institution_id)),
			"summary": "Reconcile the institution's current stockpiles and record the period's actual position.",
			"priority": 1,
			"employer_id": &"shuruppak_ilu" if world.get_person(&"shuruppak_ilu") != null else &"",
			"source_data": {"institution_id": StringName(institution_id)},
			"path_id": selected_path
		})

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
	var actions: Dictionary = record.get("actions", {})
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
	var actions: Dictionary = record.get("actions", {})
	if actions.size() < 2:
		return {"success": false, "message": "At least two investigative actions must be recorded before assessment."}

	var kind := StringName(record.get("kind", ""))
	var source_id := StringName(record.get("source_id", ""))
	var result_text := ""
	var accurate := true
	match kind:
		&"form":
			var form_data: Dictionary = record.get("source_data", {})
			var disposition := "certified"
			if verdict == &"refer":
				disposition = "referred"
				accurate = false
			elif verdict == &"defer":
				accurate = false
				result_text = "The assessment is deferred. The original form remains pending and may return to the desk."
			if verdict != &"defer":
				var resolved := world.resolve_form({
					"form_id": String(source_id),
					"disposition": disposition,
					"notes": "Assessment by %s after %d investigative actions." % [actor.display_name, actions.size()]
				}, world.year)
				if not resolved:
					return {"success": false, "message": "The source form has already changed or been resolved."}
				result_text = "The %s is entered as %s." % [_form_title(StringName(form_data.get("form_type", ""))), disposition]
		&"hazard":
			var hazard: Dictionary = record.get("source_data", {})
			var place_id := StringName(hazard.get("place_id", ""))
			if verdict == &"repair":
				var labor_cost := 3
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
			world.cedar_desk_log.append({
				"year": world.year,
				"period": world.period,
				"title": "PUBLIC WORK PROGRESS REVIEW / %s" % String(project.get("title", source_id)),
				"summary": "Progress %d / %d. Current stage: %s. Recorded simulation entries: %d." % [progress, target, String(project_state.get("stage", "unrecorded")), notes.size()]
			})
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
			world.cedar_desk_log.append({
				"year": world.year,
				"period": world.period,
				"title": "RESOURCE PRESSURE REVIEW / %s" % String(institution.get("name", institution_id)),
				"summary": "Pressure index %d. %s" % [int(institution.get("resource_pressure", 0)), "; ".join(lines)]
			})
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
			world.cedar_desk_log.append({
				"year": world.year,
				"period": world.period,
				"title": "PERIODIC STOREHOUSE ACCOUNT / %s" % String(ledger.get("name", ledger_institution_id)),
				"summary": "; ".join(ledger_lines)
			})
			result_text = "The period's actual stockpile balances are copied into the archive. No goods are created or moved by the act of recording them."
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
	world.record_case_settlement(actor, int(actor.resources.get(&"silver", 0)) - (2 if accurate else 1), actor.traits.duplicate())
	return {"success": true, "message": result_text, "accurate": accurate}

static func _build_evidence(world: WorldState, actor: PersonEntity, record: Dictionary, action_id: StringName, skill_level: int) -> Dictionary:
	var kind := StringName(record.get("kind", ""))
	var data: Dictionary = record.get("source_data", {})
	var summary := ""
	var facts := ""
	match action_id:
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
				facts = "INSTITUTION: %s\nRECORDED STOCK TOTAL: %d\nRESOURCE LINES: %d" % [String(institution.get("name", institution_id)), total, stock.size()]
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
				facts = "INSTITUTION: %s\n%s" % [String(institution.get("name", institution_id)), "\n".join(stock_lines)]
				summary = "The physical stockpile position is checked against the institution's current ledger."
	return {"summary": summary, "facts": facts, "skill_level": skill_level}

static func _form_title(form_type: StringName) -> String:
	var labels := {
		&"grain_levy": "Grain Levy Assessment",
		&"pension_roll": "Workforce Roll",
		&"consignment_receipt": "Consignment Receipt",
		&"held_barley": "Held Barley Inspection",
		&"load_claim": "Load Allocation Claim"
	}
	return String(labels.get(form_type, String(form_type).replace("_", " ").capitalize()))

static func _place_name(world: WorldState, place_id: StringName) -> String:
	if place_id == &"":
		return "the institution"
	if world.places.has(place_id):
		return String(world.places[place_id].get("name", place_id))
	return String(place_id).replace("_", " ").capitalize()
