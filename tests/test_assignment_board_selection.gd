extends SceneTree

const Pipeline = preload("res://systems/assignment_pipeline.gd")
const Narrator = preload("res://systems/assignment_narrator.gd")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var docket_file := FileAccess.open("res://data/assignments/path_dockets.json", FileAccess.READ)
	_check(docket_file != null, "Career-path docket definitions must be readable")
	if docket_file != null:
		var docket_data: Variant = JSON.parse_string(docket_file.get_as_text())
		_check(docket_data is Dictionary, "Career-path docket definitions must parse as a dictionary")
		if docket_data is Dictionary:
			var docket_paths: Dictionary = docket_data.get("dockets", {})
			for path_id in docket_paths:
				for docket_value in docket_paths[path_id]:
					var docket: Dictionary = docket_value
					var docket_id := String(docket.get("id", ""))
					_check(not String(docket.get("left", "")).strip_edges().is_empty(), "%s must have a client claim" % docket_id)
					_check(not String(docket.get("right", "")).strip_edges().is_empty(), "%s must have an opposing claim" % docket_id)
					_check(not String(docket.get("prompt", "")).strip_edges().is_empty(), "%s must state the question for the scribe" % docket_id)
					var dispositions: Array = docket.get("choices", [])
					_check(dispositions.size() >= 2, "%s must author at least two dispositions" % docket_id)
					var seen_labels: Dictionary = {}
					for disposition_value in dispositions:
						var disposition: Dictionary = disposition_value
						var label := String(disposition.get("label", "")).strip_edges()
						_check(not label.is_empty(), "%s has a disposition without a label" % docket_id)
						_check(not String(disposition.get("result_title", "")).strip_edges().is_empty(), "%s / %s has no result title" % [docket_id, label])
						_check(not String(disposition.get("result_text", "")).strip_edges().is_empty(), "%s / %s has no result explanation" % [docket_id, label])
						_check(disposition.get("effects", {}) is Dictionary and not disposition.get("effects", {}).is_empty(), "%s / %s has no effects" % [docket_id, label])
						_check(not seen_labels.has(label.to_lower()), "%s repeats disposition label '%s'" % [docket_id, label])
						seen_labels[label.to_lower()] = true
			var procedural: Dictionary = docket_data.get("procedural_archetypes", {})
			for archetype_id in procedural:
				var archetype: Dictionary = procedural[archetype_id]
				var archetype_choices: Array = archetype.get("choices", [])
				_check(archetype_choices.size() >= 2, "%s must author at least two dispositions" % String(archetype_id))
				for choice_value in archetype_choices:
					var choice: Dictionary = choice_value
					_check(not String(choice.get("label", "")).strip_edges().is_empty(), "%s has an unlabeled disposition" % String(archetype_id))
					_check(not String(choice.get("result_title", "")).strip_edges().is_empty(), "%s has a disposition without an authored result title" % String(archetype_id))
					_check(not String(choice.get("result_text", "")).strip_edges().is_empty(), "%s has a disposition without an authored result explanation" % String(archetype_id))
					_check(choice.get("skill", "") != "" and int(choice.get("xp", 0)) > 0, "%s disposition must author its skill and experience effect" % String(archetype_id))
	var official_dialogue_file := FileAccess.open("res://data/dialogue/assignment_official.dialogue", FileAccess.READ)
	_check(official_dialogue_file != null, "Official interview dialogue must be readable")
	if official_dialogue_file != null:
		var official_dialogue := official_dialogue_file.get_as_text()
		_check(not official_dialogue.contains("Is there another question?"), "Official interview must not use conversational filler")
		_check(official_dialogue.contains("assignment_context.record_response"), "Official interview must answer from the record context")
		_check(official_dialogue.contains("assignment_context.witness_response"), "Official interview must answer from witness context")
		_check(official_dialogue.contains("assignment_context.requested_result"), "Official interview must answer the office's requested result")
	var stance_file := FileAccess.open("res://data/dialogue/official_stances.json", FileAccess.READ)
	_check(stance_file != null, "Official stance dialogue data must be readable")
	if stance_file != null:
		var stances: Variant = JSON.parse_string(stance_file.get_as_text())
		_check(stances is Dictionary, "Official stance dialogue data must parse")
		for stance_id in ["grain_clerk_conflict", "other_office_conflict", "canal_bailiff_requisition", "other_office_requisition", "archive_keeper", "trusted_complicit", "hostile_exacting", "general_office"]:
			_check(not String(stances.get(stance_id, "")).strip_edges().is_empty(), "Official stance data is missing %s" % stance_id)
	var candidates: Array[Dictionary] = [
		{"id": &"review_canal", "kind": &"project_review", "source_id": &"great_canal_cut"},
		{"id": &"review_temple", "kind": &"project_review"},
		{"id": &"form_a", "kind": &"form"},
		{"id": &"hazard_a", "kind": &"hazard"},
		{"id": &"ledger_a", "kind": &"ledger"},
		{"id": &"story", "kind": &"procedural_docket"}
	]
	var board := Pipeline._select_board_candidates(candidates, 4)
	_check(board.size() == 4, "Routine board should remain at four slots when reviews fit")
	_check(_contains_id(board, &"review_canal"), "Canal review must not be displaced by board rotation")
	_check(_contains_source(board, &"great_canal_cut"), "Great Canal Cut review must remain in the selected board")
	_check(_contains_id(board, &"review_temple"), "Every pending review must be retained")
	_check(_contains_id(board, &"story"), "Reserve a procedural story slot when capacity allows")
	var live_stock := Pipeline._live_stock_facts({&"clay": 4, &"labor": 2}, {"pressure_thresholds": {&"labor_warn": 5}})
	_check(live_stock.contains("Clay: 4"), "Evidence should report arbitrary recorded stock resources")
	_check(live_stock.contains("Labor: 2"), "Evidence should report actual labor stock")
	_check(not live_stock.contains("Barley") and not live_stock.contains("Textiles"), "Missing stock keys must not be invented as zero-valued resources")
	_check(Narrator._contains_raw_metric("FORM: pension_roll"), "Raw form identifiers must be caught by narrative cleanup")
	_check(Narrator._contains_raw_metric("CAPABILITY APPLIED"), "Internal capability diagnostics must be caught by narrative cleanup")
	var overfull_reviews: Array[Dictionary] = [
		{"id": &"review_1", "kind": &"project_review"},
		{"id": &"review_2", "kind": &"project_review"},
		{"id": &"review_3", "kind": &"project_review"},
		{"id": &"review_4", "kind": &"project_review"},
		{"id": &"review_5", "kind": &"project_review"},
		{"id": &"routine", "kind": &"form"}
	]
	var review_board := Pipeline._select_board_candidates(overfull_reviews, 4)
	_check(review_board.size() == 5, "All pending project reviews may exceed the routine board cap")
	for candidate in overfull_reviews:
		if StringName(candidate.get("kind", "")) == &"project_review":
			_check(_contains_id(review_board, StringName(candidate.id)), "Pending review %s must remain visible" % String(candidate.id))
	if _failures.is_empty():
		print("PASS: %d assignment board selection checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d assignment board selection checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			printerr(" - " + failure)
		quit(1)

func _contains_source(records: Array[Dictionary], expected: StringName) -> bool:
	for record in records:
		if StringName(record.get("source_id", "")) == expected:
			return true
	return false

func _contains_id(records: Array[Dictionary], expected: StringName) -> bool:
	for record in records:
		if StringName(record.get("id", "")) == expected:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)
