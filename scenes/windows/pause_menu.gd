@tool
extends PopupWindowPanel

@export var options_menu_scene : PackedScene
## Path to a main menu scene.
## Will use ProjectSettings paths if left empty.
@export_file("*.tscn") var main_menu_scene_path : String

@onready var restart_confirmation = %RestartConfirmation
@onready var main_menu_confirmation = %MainMenuConfirmation
@onready var exit_confirmation = %ExitConfirmation
@onready var options_button = %OptionsButton
@onready var main_menu_button = %MainMenuButton
@onready var exit_button = %ExitButton
@onready var save_button = %SaveButton
@onready var load_button = %LoadButton
## If Maaack's Scene Loader is installed, then it will be used to change scenes.
@onready var scene_loader_node = get_tree().root.get_node_or_null(^"SceneLoader")

var open_window : Node
var restarting : bool = false

func get_main_menu_scene_path() -> String:
	return MaaacksMenusTemplate.get_main_menu_path(main_menu_scene_path)

func close_window() -> void:
	if open_window != null:
		if open_window.has_method(&"close"):
			open_window.close()
		else:
			open_window.hide()
		open_window = null

func _load_scene(scene_path: String) -> void:
	_scene_tree.paused = false
	if scene_loader_node:
		scene_loader_node.load_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _show_window(window : Control) -> void:
	window.show()
	open_window = window
	await window.hidden
	open_window = null

func _load_and_show_menu(scene : PackedScene) -> void:
	var window_instance : Control = scene.instantiate()
	window_instance.visible = false
	add_sibling.call_deferred(window_instance)
	await _show_window(window_instance)
	window_instance.queue_free()

func _handle_cancel_input() -> void:
	if open_window != null:
		return
	super._handle_cancel_input()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and not Engine.is_editor_hint():
		_refresh_save_load_buttons()

func _refresh_exit_button() -> void:
	exit_button.visible = !OS.has_feature("web")

func _refresh_options_button() -> void:
	options_button.visible = options_menu_scene != null

func _refresh_main_menu_button() -> void:
	main_menu_button.visible = !get_main_menu_scene_path().is_empty()

func _refresh_save_load_buttons() -> void:
	var game := get_tree().current_scene
	save_button.disabled = game == null or not game.has_method("can_save_game") or not bool(game.call("can_save_game"))
	load_button.disabled = game == null or not game.has_method("load_game") or not SaveManager.has_save()

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		_refresh_exit_button()
		_refresh_options_button()
		_refresh_main_menu_button()
		_refresh_save_load_buttons()
		restart_confirmation.confirmed.connect(_on_restart_confirmation_confirmed)
		restart_confirmation.closed.connect(_on_restart_confirmation_closed)
		main_menu_confirmation.confirmed.connect(_on_main_menu_confirmation_confirmed)
		exit_confirmation.confirmed.connect(_on_exit_confirmation_confirmed)

func _on_restart_button_pressed() -> void:
	_show_window(restart_confirmation)

func _on_options_button_pressed() -> void:
	_load_and_show_menu(options_menu_scene)

func _on_main_menu_button_pressed() -> void:
	_show_window(main_menu_confirmation)

func _on_exit_button_pressed() -> void:
	_show_window(exit_confirmation)

func _on_save_button_pressed() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("save_game"):
		return
	var result: Dictionary = game.call("save_game")
	save_button.text = "Save / Seal  ✓" if bool(result.get("success", false)) else "Save Failed"

func _on_load_button_pressed() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("load_game"):
		return
	var result: Dictionary = game.call("load_game")
	if bool(result.get("success", false)):
		get_tree().paused = false
		hide()
	else:
		load_button.text = "Load Failed"

func _on_restart_confirmation_confirmed() -> void:
	restarting = true

func _on_restart_confirmation_closed() -> void:
	if restarting:
		await draw
		get_tree().reload_current_scene()

func _on_main_menu_confirmation_confirmed():
	_load_scene(get_main_menu_scene_path())

func _on_exit_confirmation_confirmed():
	get_tree().quit()
