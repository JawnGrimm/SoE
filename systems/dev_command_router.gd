class_name DevCommandRouter
extends RefCounted
## Registers SoE-only developer commands with the existing LimboConsole.
## Simulation and world mutations are injected as callbacks; this class owns no game state.

const ADVANCE_COMMAND := "soe advance_periods"
const INSPECT_WORLD_COMMAND := "soe inspect_world"
const INSPECT_PERSON_COMMAND := "soe inspect_person"
const ADJUST_RESOURCE_COMMAND := "soe adjust_resource"

var _console: Object
var _callbacks: Dictionary = {}
var _registered_commands: Array[String] = []


func register(console: Object, callbacks: Dictionary) -> bool:
	if not OS.is_debug_build():
		return false
	if console == null or not console.has_method("register_command"):
		push_warning("DevCommandRouter: LimboConsole is unavailable; commands were not registered.")
		return false

	unregister()
	_console = console
	_callbacks = callbacks.duplicate()

	_register_command(ADVANCE_COMMAND, "_cmd_advance_periods", "Debug fast-forward through normal simulation steps; intervening desk offers are not resolved. Usage: soe advance_periods <count>")
	_register_command(INSPECT_WORLD_COMMAND, "_cmd_inspect_world", "Print a concise summary of the current runtime world.")
	_register_command(INSPECT_PERSON_COMMAND, "_cmd_inspect_person", "Inspect a runtime person by ID.")
	_register_command(ADJUST_RESOURCE_COMMAND, "_cmd_adjust_resource", "Adjust a resource through WorldState.modify_resource(). Usage: soe adjust_resource <resource_id> <amount> [scope] [owner_id] [institution_id]")

	_register_autocomplete(INSPECT_PERSON_COMMAND, 0, "person_ids")
	_register_autocomplete(ADJUST_RESOURCE_COMMAND, 0, "resource_ids")
	return not _registered_commands.is_empty()


func unregister() -> void:
	if _console != null and is_instance_valid(_console) and _console.has_method("unregister_command"):
		for command_name in _registered_commands:
			_console.call("unregister_command", command_name)
	_registered_commands.clear()
	_callbacks.clear()
	_console = null


func _register_command(command_name: String, method_name: String, description: String) -> void:
	if _console == null:
		return
	if _console.has_method("has_command") and bool(_console.call("has_command", command_name)):
		push_warning("DevCommandRouter: command already exists and was not replaced: %s" % command_name)
		return
	_console.call("register_command", Callable(self, method_name), command_name, description)
	_registered_commands.append(command_name)


func _register_autocomplete(command_name: String, argument_index: int, callback_key: String) -> void:
	if _console == null or not _console.has_method("add_argument_autocomplete_source"):
		return
	var source: Callable = _callbacks.get(callback_key, Callable())
	if source.is_valid():
		_console.call("add_argument_autocomplete_source", command_name, argument_index, source)


func _run_callback(callback_key: String, arguments: Array) -> void:
	if _console == null:
		return
	var callback: Callable = _callbacks.get(callback_key, Callable())
	if not callback.is_valid():
		_report_error("The SoE debug handler '%s' is unavailable." % callback_key)
		return
	var result: Variant = callback.callv(arguments)
	if result is Dictionary:
		if bool(result.get("success", false)):
			_console.call("info", String(result.get("message", "Command completed.")))
		else:
			_report_error(String(result.get("error", "Command failed.")))
	else:
		_console.call("info", str(result))


func _report_error(message: String) -> void:
	if _console != null:
		_console.call("error", message)


func _cmd_advance_periods(count: int) -> void:
	_run_callback("advance_periods", [count])


func _cmd_inspect_world() -> void:
	_run_callback("inspect_world", [])


func _cmd_inspect_person(person_id: String) -> void:
	_run_callback("inspect_person", [person_id])


func _cmd_adjust_resource(
	resource_id: String,
	amount: int,
	scope: String = "world",
	owner_id: String = "",
	institution_id: String = ""
) -> void:
	_run_callback("adjust_resource", [resource_id, amount, scope, owner_id, institution_id])
