extends SceneTree

const QueueScript = preload("res://ui/work_queue_overlay.gd")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(QueueScript.category_for({"kind": &"project_review"}) == "works", "Project reviews belong in Works")
	_check(QueueScript.category_for({"kind": &"work"}) == "works", "Long-form work belongs in Works")
	_check(QueueScript.category_for({"kind": &"challenge"}) == "challenges", "Challenges have their own queue section")
	_check(QueueScript.category_for({"challenge_id": &"audit_pattern"}) == "challenges", "Challenge records are grouped by challenge ID")
	_check(QueueScript.category_for({"kind": &"form"}) == "assignments", "Forms remain ordinary Assignments")
	_check(QueueScript.category_for({"kind": &"hazard"}) == "assignments", "Inspections remain ordinary Assignments")
	if _failures.is_empty():
		print("PASS: %d work queue grouping checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d work queue grouping checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			printerr(" - " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)
