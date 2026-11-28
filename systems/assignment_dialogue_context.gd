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

	var requested := String(npc_evidence.get("official_demand", npc_evidence.get("requested_outcome", source.get("requested_outcome", ""))))
	if not requested.is_empty():
		context.requested_result = requested
	return context

static func from_procedural_docket(source: Dictionary, world: WorldState) -> AssignmentDialogueContext:
	var context := AssignmentDialogueContext.new()
	var left: Dictionary = source.get("left_card", {})
	var right: Dictionary = source.get("right_card", {})
	var client: PersonEntity = world.get_person(StringName(left.get("speaker_id", ""))) if world != null else null
	var opposing: PersonEntity = world.get_person(StringName(right.get("speaker_id", ""))) if world != null else null
	context.client_name = client.display_name if client != null else String(source.get("client_name", ""))
	context.opposing_name = opposing.display_name if opposing != null else String(source.get("opposing_name", ""))
	context.client_statement = String(left.get("quote", ""))
	context.opposing_statement = String(right.get("quote", ""))
	context.client_record = String(left.get("facts", ""))
	context.opposing_record = String(right.get("facts", ""))
	context.requested_result = String(source.get("prompt", ""))
	return context

static func _extract_fact(facts: String, label: String, fallback: String = "") -> String:
	for line in facts.split("\n"):
		var prefix := label + ":"
		if line.strip_edges().to_upper().begins_with(prefix):
			return line.strip_edges().substr(prefix.length()).strip_edges().trim_prefix("“").trim_suffix("”").strip_edges()
	return fallback
