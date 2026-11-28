class_name AssignmentDialogueContext
extends RefCounted

## Read-only narrative state passed to Dialogue Manager.
## This object presents evidence already produced by AssignmentPipeline; it does not
## resolve actions or mutate WorldState.

var official_name: String = ""
var opening_line: String = ""
var record_response: String = ""
var witness_response: String = ""
var requested_result: String = ""
var client_name: String = ""
var opposing_name: String = ""
var client_statement: String = ""
var opposing_statement: String = ""
var client_record: String = ""
var opposing_record: String = ""

static var _dialogue_copy: Dictionary = {}

static func from_record(record: Dictionary, world: WorldState) -> AssignmentDialogueContext:
	var context := AssignmentDialogueContext.new()
	var official_id := StringName(record.get("employer_id", ""))
	var official: PersonEntity = world.get_person(official_id) if world != null else null
	if official != null:
		context.official_name = official.display_name

	var source: Dictionary = record.get("source_data", {})
	var npc_evidence: Dictionary = source.get("npc_evidence", {})
	var evidence: Dictionary = record.get("evidence", {})
	var official_entry: Dictionary = evidence.get(&"consult_official", {})
	var official_facts := String(official_entry.get("facts", ""))
	context.opening_line = _extract_fact(official_facts, "STANCE", "")

	var record_entry: Dictionary = evidence.get(&"examine_records", {})
	var record_facts := String(record_entry.get("facts", ""))
	var dispatch := String(npc_evidence.get("dispatch_record", ""))
	var tally := String(npc_evidence.get("threshold_tally", ""))
	var discrepancy := String(npc_evidence.get("discrepancy", ""))
	if not dispatch.is_empty() or not tally.is_empty():
		var statements := PackedStringArray()
		if not dispatch.is_empty():
			statements.append("The dispatch record states: %s" % dispatch)
		if not tally.is_empty():
			statements.append("The threshold tally states: %s" % tally)
		if not discrepancy.is_empty():
			statements.append("The recorded discrepancy is: %s" % discrepancy)
		context.record_response = "\n\n".join(statements)
	elif not record_facts.is_empty():
		context.record_response = record_facts
	elif source.has("form_type"):
		var form_type := String(source.get("form_type", ""))
		var form_titles: Dictionary = _get_dialogue_copy("form_titles")
		var reason_labels: Dictionary = _get_dialogue_copy("generation_reasons")
		var subject_id := StringName(source.get("subject_id", source.get("place_id", "")))
		var subject_name := String(world.places.get(subject_id, {}).get("name", String(subject_id).replace("_", " ").capitalize())) if world != null else String(subject_id)
		var summary_template := String(_get_dialogue_copy("record_entry_summary"))
		context.record_response = _format_dialogue_copy(summary_template, {
			"form_title": String(form_titles.get(form_type, "")),
			"place_name": subject_name,
			"generated_by": official.display_name if official != null else context.official_name,
			"generation_reason": String(reason_labels.get(String(source.get("generation_reason", "")), "")),
			"urgency": String(source.get("urgency", ""))
		})
	else:
		context.record_response = String(record.get("summary", ""))

	var witness := String(npc_evidence.get("witness_statement", npc_evidence.get("witness", "")))
	if not witness.is_empty():
		context.witness_response = witness
	else:
		for action_id in evidence:
			var entry: Dictionary = evidence[action_id]
			var facts := String(entry.get("facts", ""))
			var witness_line := _extract_fact(facts, "WITNESS", "")
			if not witness_line.is_empty():
				context.witness_response = witness_line
				break
	if context.witness_response.is_empty():
		context.witness_response = _get_dialogue_copy("no_witness")

	var requested := String(npc_evidence.get("official_demand", npc_evidence.get("requested_outcome", source.get("requested_outcome", ""))))
	if not requested.is_empty():
		context.requested_result = requested
	else:
		var demands: Dictionary = _get_dialogue_copy("form_demands")
		context.requested_result = String(demands.get(String(source.get("form_type", "")), _get_dialogue_copy("no_separate_demand")))
	return context

static func from_procedural_docket(source: Dictionary, world: WorldState) -> AssignmentDialogueContext:
	var context := AssignmentDialogueContext.new()
	var left: Dictionary = source.get("left_card", {})
	var right: Dictionary = source.get("right_card", {})
	var client: PersonEntity = world.get_person(StringName(left.get("speaker_id", ""))) if world != null else null
	var opposing: PersonEntity = world.get_person(StringName(right.get("speaker_id", ""))) if world != null else null
	if client == null or opposing == null:
		push_error("AssignmentDialogueContext: procedural docket '%s' is missing a named party." % String(source.get("archetype", "")))
		return context
	context.client_name = client.display_name
	context.opposing_name = opposing.display_name
	context.client_statement = String(left.get("quote", ""))
	context.opposing_statement = String(right.get("quote", ""))
	context.client_record = String(left.get("facts", ""))
	context.opposing_record = String(right.get("facts", ""))
	context.requested_result = String(source.get("prompt", ""))
	return context



static func _format_dialogue_copy(template: String, values: Dictionary) -> String:
	var result := template
	for key in values:
		if String(values[key]).strip_edges().is_empty():
			push_error("AssignmentDialogueContext: missing value '%s' for authored interview copy." % String(key))
			return ""
		result = result.replace("{%s}" % String(key), String(values[key]))
	var unresolved := RegEx.new()
	unresolved.compile("\\{[a-zA-Z0-9_]+\\}")
	if unresolved.search(result) != null or result.strip_edges().is_empty():
		push_error("AssignmentDialogueContext: unresolved or empty authored interview copy.")
		return ""
	return result

static func _get_dialogue_copy(key: String) -> Variant:
	if _dialogue_copy.is_empty():
		var file := FileAccess.open("res://data/dialogue/official_stances.json", FileAccess.READ)
		if file == null:
			push_error("AssignmentDialogueContext: official interview copy is missing.")
			return ""
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("AssignmentDialogueContext: official interview copy is invalid.")
			return ""
		_dialogue_copy = parsed
	var value: Variant = _dialogue_copy.get(key, "")
	if value is String and String(value).is_empty():
		push_error("AssignmentDialogueContext: missing authored interview response '%s'." % key)
	return value

static func _extract_fact(facts: String, label: String, fallback: String = "") -> String:
	for line in facts.split("\n"):
		var prefix := label + ":"
		if line.strip_edges().to_upper().begins_with(prefix):
			return line.strip_edges().substr(prefix.length()).strip_edges().trim_prefix("“").trim_suffix("”").strip_edges()
	return fallback
