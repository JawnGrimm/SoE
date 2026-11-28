class_name AssignmentDialogueContext
extends RefCounted

## Read-only narrative state passed to Dialogue Manager.
## This object presents evidence already produced by AssignmentPipeline; it does not
## resolve actions or mutate WorldState.

var official_name: String = "The responsible official"
var opening_line: String = "The matter is entered. I will answer for my office."
var record_response: String = "The written record establishes only what is entered on the tablet."
var witness_response: String = "No witness statement is attached to the evidence currently entered."
var requested_result: String = "The official has not stated a separate requested disposition."
var client_name: String = "Claimant"
var opposing_name: String = "Opposing party"
var client_statement: String = "The claimant's statement is not recorded."
var opposing_statement: String = "The opposing statement is not recorded."
var client_record: String = "No particulars are attached to the claimant's entry."
var opposing_record: String = "No particulars are attached to the opposing entry."

static func from_record(record: Dictionary, world: WorldState) -> AssignmentDialogueContext:
	var context := AssignmentDialogueContext.new()
	var official_id := StringName(record.get("employer_id", ""))
	var official := world.get_person(official_id) if world != null else null
	if official != null:
		context.official_name = official.display_name

	var source: Dictionary = record.get("source_data", {})
	var npc_evidence: Dictionary = source.get("npc_evidence", {})
	var evidence: Dictionary = record.get("evidence", {})
	var official_entry: Dictionary = evidence.get(&"consult_official", {})
	var official_facts := String(official_entry.get("facts", ""))
	context.opening_line = _extract_fact(official_facts, "STANCE", context.opening_line)

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
		context.record_response = String(record.get("summary", context.record_response))

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

static func from_procedural_docket(source: Dictionary) -> AssignmentDialogueContext:
	var context := AssignmentDialogueContext.new()
	var left: Dictionary = source.get("left_card", {})
	var right: Dictionary = source.get("right_card", {})
	context.client_name = String(source.get("client_name", left.get("title", "Claimant")))
	context.opposing_name = String(source.get("opposing_name", right.get("title", "Opposing party")))
	context.client_statement = String(left.get("quote", context.client_statement))
	context.opposing_statement = String(right.get("quote", context.opposing_statement))
	context.client_record = String(left.get("facts", context.client_record))
	context.opposing_record = String(right.get("facts", context.opposing_record))
	context.requested_result = String(source.get("prompt", "Which account will you enter?"))
	return context

static func _extract_fact(facts: String, label: String, fallback: String) -> String:
	for line in facts.split("\n"):
		var prefix := label + ":"
		if line.strip_edges().to_upper().begins_with(prefix):
			return line.strip_edges().substr(prefix.length()).strip_edges().trim_prefix("“").trim_suffix("”").strip_edges()
	return fallback
