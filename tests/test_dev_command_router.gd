extends SceneTree

const RouterScript = preload("res://systems/dev_command_router.gd")

class FakeConsole:
	extends RefCounted

	var commands: Dictionary = {}
	var autocomplete: Dictionary = {}
	var output: Array[String] = []
	var errors: Array[String] = []

	func register_command(callback: Callable, command_name: String, _description: String) -> void:
		commands[command_name] = callback

	func unregister_command(command_name: String) -> void:
		commands.erase(command_name)
		autocomplete.erase(command_name)

	func has_command(command_name: String) -> bool:
		return commands.has(command_name)

	func add_argument_autocomplete_source(command_name: String, argument_index: int, source: Callable) -> void:
		autocomplete["%s:%d" % [command_name, argument_index]] = source

	func info(message: String) -> void:
		output.append(message)

	func error(message: String) -> void:
		errors.append(message)


var _checks := 0
var _failures: Array[String] = []
var _advanced_periods := 0
var _adjusted_resource := 0
var _finished := false


func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(15.0).timeout
	if not _finished:
		printerr("DEV ROUTER TEST WATCHDOG: test did not finish")
		quit(2)


func _run() -> void:
	var console := FakeConsole.new()
	var router = RouterScript.new()
	var callbacks := {
		"advance_periods": Callable(self, "_fake_advance_periods"),
		"inspect_world": Callable(self, "_fake_inspect_world"),
		"inspect_person": Callable(self, "_fake_inspect_person"),
		"adjust_resource": Callable(self, "_fake_adjust_resource"),
		"person_ids": Callable(self, "_fake_person_ids"),
		"resource_ids": Callable(self, "_fake_resource_ids"),
	}

	_check(router.register(console, callbacks), "Router should register in a debug build")
	_check(console.commands.has("soe advance_periods"), "Advance command should be registered")
	_check(console.commands.has("soe inspect_world"), "World inspection command should be registered")
	_check(console.commands.has("soe inspect_person"), "Person inspection command should be registered")
	_check(console.commands.has("soe adjust_resource"), "Resource adjustment command should be registered")
	_check(console.autocomplete.has("soe inspect_person:0"), "Person ID autocomplete should be registered")
	_check(console.autocomplete.has("soe adjust_resource:0"), "Resource ID autocomplete should be registered")

	var advance_command: Callable = console.commands["soe advance_periods"]
	advance_command.call(4)
	_check(_advanced_periods == 4, "Advance command should delegate the requested count")
	_check(not console.output.is_empty(), "Successful command should report through LimboConsole")

	var person_command: Callable = console.commands["soe inspect_person"]
	person_command.call("clerk")
	_check(console.output.back() == "Person: clerk", "Person inspection should delegate the supplied ID")
	person_command.call("missing")
	_check(console.errors.back() == "No such person.", "Failed command results should be reported through LimboConsole")

	var adjust_command: Callable = console.commands["soe adjust_resource"]
	adjust_command.call("silver", 25, "actor", "clerk", "")
	_check(_adjusted_resource == 25, "Resource adjustment should delegate amount and scope")

	router.unregister()
	_check(console.commands.is_empty(), "Unregister should remove only this router's commands")
	_finish()


func _fake_advance_periods(count: int) -> Dictionary:
	_advanced_periods += count
	return {"success": true, "message": "Advanced %d periods." % count}


func _fake_inspect_world() -> Dictionary:
	return {"success": true, "message": "World inspected."}


func _fake_inspect_person(person_id: String) -> Dictionary:
	if person_id == "missing":
		return {"success": false, "error": "No such person."}
	return {"success": true, "message": "Person: %s" % person_id}


func _fake_adjust_resource(_resource_id: String, amount: int, _scope: String, _owner_id: String, _institution_id: String) -> Dictionary:
	_adjusted_resource = amount
	return {"success": true, "message": "Resource adjusted."}


func _fake_person_ids() -> Array[String]:
	return ["clerk", "scribe"]


func _fake_resource_ids() -> Array[String]:
	return ["grain", "silver"]


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: " + message)


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("PASS: %d developer command router checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d developer command router checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			printerr(" - " + failure)
		quit(1)
