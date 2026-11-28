class_name AssignmentNarrator
extends RefCounted

## Presentation normalization only. Assignment facts, evidence, and decisions come from
## AssignmentPipeline and authored source data; this class does not substitute story text.

const RAW_METRIC_LABELS := [
	"pressure_index", "progress_review", "resource_pressure", "completion_ratio",
	"work_progress", "capability applied", "form:", "pension_roll", "grain_levy",
	"travel_pass", "succession_claim", "form: pension_roll", "form: grain_levy",
	"form: travel_pass", "form: succession_claim"
]

static func translate_opportunity(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result["title"] = _clean_display(String(result.get("title", "")), "title")
	result["summary"] = _clean_display(String(result.get("summary", "")), "summary")
	return result

static func translate_payload(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result["title"] = _clean_display(String(result.get("title", "")), "Assignment")
	for card_key in ["left_card", "right_card"]:
		var card: Dictionary = result.get(card_key, {})
		for field in ["title", "quote", "facts"]:
			if card.has(field):
				card[field] = _clean_display(String(card[field]), "%s.%s" % [card_key, field])
		result[card_key] = card
	result["prompt"] = _clean_display(String(result.get("prompt", "")), "prompt")
	var choices: Array = result.get("choices", [])
	for choice in choices:
		if choice is Dictionary and choice.has("label"):
			choice["label"] = _clean_display(String(choice["label"]), "choice.label")
	result["choices"] = choices
	return result

static func translate_record(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result["title"] = _clean_display(String(result.get("title", "")), "Assignment")
	result["summary"] = _clean_display(String(result.get("summary", "")), "summary")
	var evidence: Dictionary = result.get("evidence", {})
	for action_id in evidence:
		var entry: Dictionary = evidence[action_id]
		entry["summary"] = _clean_display(String(entry.get("summary", "")), "evidence.%s.summary" % String(action_id))
		entry["facts"] = _clean_display(String(entry.get("facts", "")), "evidence.%s.facts" % String(action_id))
		evidence[action_id] = entry
	result["evidence"] = evidence
	return result

static func investigation_action_description(record: Dictionary, action_id: StringName) -> String:
	var kind := StringName(record.get("kind", ""))
	match action_id:
		&"examine_records":
			if kind == &"form":
				return "Confirm the register's source, subject, urgency, and office note."
			if kind == &"project_review":
				return "Read the stage entry and the last certified progress."
			return "Establish where the account came from and what it claims."
		&"reconcile_accounts":
			return "Compare entered quantities with the current institutional account."
		&"consult_official":
			return "Hear the responsible official's position. Testimony is not proof."
		&"inspect_source":
			if kind == &"hazard":
				return "Inspect the site and compare recorded loss with current conditions."
			return "Check the goods, stores, or site against the written claim."
	return "Spend an inquiry to establish a specific part of the matter."

static func narrate_record_examination(record: Dictionary, actor: PersonEntity, world: WorldState, evidence: Dictionary) -> Dictionary:
	## Builds the first record-reading scene from facts already present on the assignment.
	var source: Dictionary = record.get("source_data", {})
	var npc_evidence: Dictionary = source.get("npc_evidence", {})
	var beats: Array[Dictionary] = []
	var form_type := String(source.get("form_type", ""))
	var subject := String(source.get("subject_id", source.get("place_id", "the named place"))).replace("_", " ")
	var record_evidence: Dictionary = record.get("evidence", {})
	var record_entry: Dictionary = record_evidence.get(&"examine_records", evidence)
	var record_facts := String(record_entry.get("facts", ""))
	var official: PersonEntity = world.get_person(StringName(record.get("employer_id", ""))) if world != null else null
	var official_name := official.display_name if official != null else "the responsible office"

	beats.append({"kind": "description", "speaker": "", "text": "You read the record against the matter referred to your desk."})
	if not npc_evidence.is_empty():
		for field in [
			{"key": "dispatch_record", "speaker": "Dispatch record"},
			{"key": "threshold_tally", "speaker": "Threshold tally"},
			{"key": "discrepancy", "speaker": "Recorded discrepancy"}
		]:
			var value := String(npc_evidence.get(field.key, ""))
			if not value.is_empty():
				beats.append({"kind": "document", "speaker": field.speaker, "text": value})
	elif not record_facts.is_empty():
		beats.append({"kind": "document", "speaker": "Written record", "text": record_facts})
	elif not form_type.is_empty():
		beats.append({"kind": "document", "speaker": "Pending register", "text": "%s concerns %s. The entry identifies its subject and urgency; it does not establish the disputed facts." % [_form_display(form_type), subject]})
	else:
		beats.append({"kind": "document", "speaker": "Written record", "text": String(record.get("summary", "The record identifies a matter requiring assessment."))})

	var official_entry: Dictionary = record_evidence.get(&"consult_official", {})
	var stance := _extract_fact(String(official_entry.get("facts", "")), "STANCE")
	if not stance.is_empty():
		beats.append({"kind": "dialogue", "speaker": official_name, "text": stance})
	else:
		beats.append({"kind": "observation", "speaker": "", "text": "The responsible official has not yet given testimony. The written entry remains a claim, not a finding."})

	var thought := "The record establishes what was entered. It does not establish why it was entered."
	if actor != null and actor.skills != null and actor.skills.get_level(&"literacy") >= 2:
		thought = "The wording is deliberate. Separate the recorded statement from the fact it claims to describe."
	beats.append({"kind": "internal_monologue", "speaker": actor.display_name if actor != null else "The scribe", "text": thought})
	return {
		"heading": "A closer reading",
		"beats": beats,
		"closing": "The written record is one source. Compare it with the account, the official's testimony, and the physical matter before entering judgment."
	}

static func _extract_fact(facts: String, label: String) -> String:
	for line in facts.split("\n"):
		var prefix := label + ":"
		if line.strip_edges().to_upper().begins_with(prefix):
			return line.strip_edges().substr(prefix.length()).strip_edges().trim_prefix("“").trim_suffix("”").strip_edges()
	return ""

static func _form_display(form_type: String) -> String:
	match form_type:
		"pension_roll": return "Pension Ledger"
		"grain_levy": return "Grain Levy"
		"travel_pass": return "Travel Pass"
		"succession_claim": return "Succession Claim"
		_: return form_type.replace("_", " ").capitalize()

static func _clean_display(value: String, field_path: String) -> String:
	var lines := PackedStringArray()
	for line in value.split("\n"):
		if line.strip_edges().begins_with("CAPABILITY APPLIED:"):
			continue
		lines.append(line)
	var cleaned := "\n".join(lines)
	var form_pattern := RegEx.new()
	form_pattern.compile("form_[0-9]+")
	cleaned = form_pattern.sub(cleaned, "the pending record", true)
	var form_label_pattern := RegEx.new()
	form_label_pattern.compile("(?i)FORM:\\s*([a-z_]+)")
	var form_matches := form_label_pattern.search_all(cleaned)
	for form_match in form_matches:
		var form_type := form_match.get_string(1)
		cleaned = cleaned.replace(form_match.get_string(0), "RECORD TYPE: " + _form_display(form_type))
	if cleaned.strip_edges().is_empty():
		push_error("AssignmentNarrator: required player-facing field is empty: %s" % field_path)
		return ""
	if _contains_raw_metric(cleaned):
		push_error("AssignmentNarrator: internal simulation data reached player-facing field: %s" % field_path)
		return ""
	return cleaned

static func _contains_raw_metric(value: String) -> bool:
	var lowered := value.to_lower()
	for raw_label in RAW_METRIC_LABELS:
		if lowered.contains(raw_label):
			return true
	return false
