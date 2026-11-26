extends Node

const SAVE_PATH := "user://saves/slot_1.json"
const SaveCodecScript = preload("res://systems/save_codec.gd")

var load_on_start := false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func request_load_on_start() -> void:
	load_on_start = true

func consume_load_on_start() -> bool:
	var requested := load_on_start
	load_on_start = false
	return requested

func save_game(world: WorldState, session: Dictionary = {}) -> Dictionary:
	if world == null or world.get_player() == null:
		return {"success": false, "error": "A confirmed player campaign is required to save."}
	var payload := SaveCodecScript.encode_world(world, session)
	if payload.is_empty():
		return {"success": false, "error": "Could not encode campaign state."}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	if directory_error != OK:
		return {"success": false, "error": "Could not create save directory (%d)." % directory_error}
	var temporary_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "Could not open temporary save (%d)." % FileAccess.get_open_error()}
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"success": false, "error": "Could not write save (%d)." % write_error}
	var absolute_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		if remove_error != OK:
			return {"success": false, "error": "Could not replace previous save (%d)." % remove_error}
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), absolute_save_path)
	if rename_error != OK:
		return {"success": false, "error": "Could not seal save (%d)." % rename_error}
	return {"success": true, "path": SAVE_PATH}

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"success": false, "error": "No campaign save exists yet."}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Could not open save (%d)." % FileAccess.get_open_error()}
	var contents := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(contents)
	if parse_error != OK:
		return {"success": false, "error": "Save JSON is malformed at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]}
	var decoded := SaveCodecScript.decode_save(parser.data)
	if not bool(decoded.get("success", false)):
		return decoded
	return {"success": true, "world": decoded.world, "session": decoded.session}
