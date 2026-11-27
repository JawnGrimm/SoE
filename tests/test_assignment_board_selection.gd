extends SceneTree

const Pipeline = preload("res://systems/assignment_pipeline.gd")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidates: Array[Dictionary] = [
		{"id": &"review_canal", "kind": &"project_review"},
		{"id": &"review_temple", "kind": &"project_review"},
		{"id": &"form_a", "kind": &"form"},
		{"id": &"hazard_a", "kind": &"hazard"},
		{"id": &"ledger_a", "kind": &"ledger"},
		{"id": &"story", "kind": &"procedural_docket"}
	]
	var board := Pipeline._select_board_candidates(candidates, 4)
	_check(board.size() == 4, "Routine board should remain at four slots when reviews fit")
	_check(_contains_id(board, &"review_canal"), "Canal review must not be displaced by board rotation")
	_check(_contains_id(board, &"review_temple"), "Every pending review must be retained")
	_check(_contains_id(board, &"story"), "Reserve a procedural story slot when capacity allows")
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
