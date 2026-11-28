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
	result["title"] = _clean_display(String(result.get("title", "")), "title")
	for card_key in ["left_card", "right_card"]:
		var card: Dictionary = result.get(card_key, {})
		for field in ["title", "quote", "facts"]:
			if card.has(field):
				card[field] = _clean_display(String(card[field]), "%s.%s" % [card_key, field])
		result[card_key] = card
	result["prompt"] = _clean_display(String(result.get("prompt", "")), "prompt")
	var choices: Array = result.get("choices", [])
	for index in range(choices.size()):
		if not choices[index] is Dictionary:
			push_error("AssignmentNarrator: malformed disposition at index %d." % index)
			continue
		var choice: Dictionary = choices[index]
		choice["label"] = _clean_display(String(choice.get("label", "")), "choices[%d].label" % index)
		choice["result_title"] = _clean_display(String(choice.get("result_title", "")), "choices[%d].result_title" % index)
		choice["result_text"] = _clean_display(String(choice.get("result_text", "")), "choices[%d].result_text" % index)
		choices[index] = choice
	result["choices"] = choices
	return result

static func translate_record(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result["title"] = _clean_display(String(result.get("title", "")), "title")
	result["summary"] = _clean_display(String(result.get("summary", "")), "summary")
	var evidence: Dictionary = result.get("evidence", {})
	for action_id in evidence:
		var entry: Dictionary = evidence[action_id]
		entry["summary"] = _clean_display(String(entry.get("summary", "")), "evidence.%s.summary" % String(action_id))
		entry["facts"] = _clean_display(String(entry.get("facts", "")), "evidence.%s.facts" % String(action_id))
		evidence[action_id] = entry
	result["evidence"] = evidence
	return result

static var _investigation_prompt_data: Dictionary = {}

static func investigation_action_description(record: Dictionary, action_id: StringName) -> String:
	var source: Dictionary = record.get("source_data", {})
	var prompts: Dictionary = source.get("investigation_actions", {})
	var description := String(prompts.get(String(action_id), "")).strip_edges()
	if description.is_empty():
		if _investigation_prompt_data.is_empty():
			var prompt_file := FileAccess.open("res://data/assignments/investigation_prompts.json", FileAccess.READ)
			if prompt_file == null:
				push_error("AssignmentNarrator: investigation prompt data is missing.")
				return ""
			var parsed: Variant = JSON.parse_string(prompt_file.get_as_text())
			if not parsed is Dictionary:
				push_error("AssignmentNarrator: investigation prompt data is invalid.")
				return ""
			_investigation_prompt_data = parsed
		var profile_id := "forms" if StringName(record.get("kind", "")) == &"form" else String(record.get("kind", ""))
		if not source.get("npc_evidence", {}).is_empty():
			description = String(_investigation_prompt_data.get("grain_conflict", {}).get(String(action_id), ""))
		elif profile_id == "forms":
			var form_type := String(source.get("form_type", ""))
			var form_profiles: Dictionary = _investigation_prompt_data.get("forms", {})
			var form_profile: Dictionary = form_profiles.get(form_type, {})
			description = String(form_profile.get(String(action_id), ""))
		else:
			description = String(_investigation_prompt_data.get(profile_id, {}).get(String(action_id), ""))
	if description.strip_edges().is_empty():
		push_error("AssignmentNarrator: assignment '%s' of kind '%s' has no authored investigation prompt '%s'." % [String(record.get("id", "")), String(record.get("kind", "")), String(action_id)])
		return ""
	return description

static var _record_reading_data: Dictionary = {}

static func narrate_record_examination(record: Dictionary, actor: PersonEntity, world: WorldState, evidence: Dictionary) -> Dictionary:
	var source: Dictionary = record.get("source_data", {})
	var npc_evidence: Dictionary = source.get("npc_evidence", {})
	var record_evidence: Dictionary = record.get("evidence", {})
	var record_entry: Dictionary = record_evidence.get(&"examine_records", evidence)
	var record_facts := String(record_entry.get("facts", ""))
	var beats: Array[Dictionary] = []
	if not npc_evidence.is_empty():
		for field in [
			{"key": "dispatch_record", "speaker": "Dispatch record"},
			{"key": "threshold_tally", "speaker": "Threshold tally"},
			{"key": "discrepancy", "speaker": "Recorded discrepancy"}
		]:
			var value := String(npc_evidence.get(field.key, ""))
			if not value.is_empty():
				beats.append({"kind": "document", "speaker": field.speaker, "text": value})
	elif not record_facts.strip_edges().is_empty():
		beats.append({"kind": "document", "speaker": "Written record", "text": record_facts})
	else:
		push_error("AssignmentNarrator: assignment '%s' has no written-record evidence." % String(record.get("id", "")))
		return {}
	if _record_reading_data.is_empty():
		var reading_file := FileAccess.open("res://data/assignments/record_readings.json", FileAccess.READ)
		if reading_file == null:
			push_error("AssignmentNarrator: authored record-reading data is missing.")
			return {}
		var parsed: Variant = JSON.parse_string(reading_file.get_as_text())
		if not parsed is Dictionary:
			push_error("AssignmentNarrator: authored record-reading data is invalid.")
			return {}
		_record_reading_data = parsed
	var reading_key := "grain_conflict" if not npc_evidence.is_empty() else String(source.get("form_type", record.get("kind", "")))
	var thought := String(_record_reading_data.get(reading_key, ""))
	if thought.is_empty():
		push_error("AssignmentNarrator: no authored scribe reading for '%s'." % reading_key)
		return {}
	beats.append({"kind": "internal_monologue", "speaker": actor.display_name if actor != null else "", "text": thought})
	var official_entry: Dictionary = record_evidence.get(&"consult_official", {})
	var stance := _extract_fact(String(official_entry.get("facts", "")), "STANCE")
	if not stance.is_empty():
		var official: PersonEntity = world.get_person(StringName(record.get("employer_id", ""))) if world != null else null
		beats.append({"kind": "dialogue", "speaker": official.display_name if official != null else "", "text": stance})
	return {
		"heading": "A closer reading",
		"beats": beats,
		"closing": ""
	}

static func _extract_fact(facts: String, label: String) -> String:
	for line in facts.split("\n"):
		var prefix := label + ":"
		if line.strip_edges().to_upper().begins_with(prefix):
			return line.strip_edges().substr(prefix.length()).strip_edges().trim_prefix("“").trim_suffix("”").strip_edges()
	return ""

static var _form_title_data: Dictionary = {}
static var _player_term_data: Dictionary = {}

static func _form_display(form_type: String) -> String:
	if _form_title_data.is_empty():
		var file := FileAccess.open("res://data/dialogue/official_stances.json", FileAccess.READ)
		if file == null:
			push_error("AssignmentNarrator: authored form title data is missing.")
			return ""
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("AssignmentNarrator: authored form title data is invalid.")
			return ""
		_form_title_data = parsed.get("form_titles", {})
	var title := String(_form_title_data.get(form_type, ""))
	if title.is_empty():
		push_error("AssignmentNarrator: no authored title for form type '%s'." % form_type)
	return title

static func _clean_display(value: String, field_path: String) -> String:
	var lines := PackedStringArray()
	for line in value.split("\n"):
		if line.strip_edges().begins_with("CAPABILITY APPLIED:"):
			continue
		lines.append(line)
	var cleaned := "\n".join(lines)
	var form_pattern := RegEx.new()
	form_pattern.compile("form_[0-9]+")
	if form_pattern.search(cleaned) != null:
		push_error("AssignmentNarrator: internal form identifier reached player-facing field: %s" % field_path)
		return ""
	if _player_term_data.is_empty():
		var terms_file := FileAccess.open("res://data/assignments/player_terms.json", FileAccess.READ)
		if terms_file == null:
			push_error("AssignmentNarrator: authored player-facing term data is missing.")
			return ""
		var terms_parsed: Variant = JSON.parse_string(terms_file.get_as_text())
		if not terms_parsed is Dictionary:
			push_error("AssignmentNarrator: authored player-facing term data is invalid.")
			return ""
		_player_term_data = terms_parsed
	var form_label_pattern := RegEx.new()
	form_label_pattern.compile("(?i)FORM:\\s*([a-z_]+)")
	var form_matches := form_label_pattern.search_all(cleaned)
	for form_match in form_matches:
		var form_type := form_match.get_string(1)
		var display_title := _form_display(form_type)
		if display_title.is_empty():
			return ""
		cleaned = cleaned.replace(form_match.get_string(0), "RECORD TYPE: " + display_title)
	for raw_term in _player_term_data:
		cleaned = cleaned.replace(String(raw_term), String(_player_term_data[raw_term]))
	if cleaned.strip_edges().is_empty():
		push_error("AssignmentNarrator: required player-facing field is empty: %s" % field_path)
		return ""
	if _contains_raw_metric(cleaned):
		push_error("AssignmentNarrator: internal simulation data reached player-facing field: %s" % field_path)
		return ""
	var unresolved := RegEx.new()
	unresolved.compile("\\{[a-zA-Z0-9_]+\\}")
	if unresolved.search(cleaned) != null:
		push_error("AssignmentNarrator: unresolved authored substitution in player-facing field: %s" % field_path)
		return ""
	return cleaned

static func _contains_raw_metric(value: String) -> bool:
	var lowered := value.to_lower()
	for raw_label in RAW_METRIC_LABELS:
		if lowered.contains(raw_label):
			return true
	return false
