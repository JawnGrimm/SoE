@tool
extends RefCounted
## Read-only view of a save or settings file. Nothing in this class writes to disk:
## the file is read once per open/reload and only the resolved text span is exposed.
## A name that declares a format (.json, .cfg, .ini) is read that way; a name that declares
## nothing (save_data.sav, .dat, a file with no extension) is read as JSON when the whole text
## parses as JSON, otherwise as the supported ConfigFile subset.

const Parser = preload("parser.gd")
const MAX_BYTES := 8 * 1024 * 1024
## The two words the panel and the README use for the reader that accepted the file.
const JSON_FORMAT := "json"
const CONFIG_FORMAT := "config"
## Extensions that name their own reader. A file named this way is never read the other way.
const JSON_NAMES := ["json"]
const CONFIG_NAMES := ["cfg", "ini"]

var path: String = ""
var last_error: String = ""
var file_size: int = 0
var rows: Array[Dictionary] = []

var _index: Dictionary = {}
var _format: String = ""


func open_file(file_path: String) -> bool:
	last_error = ""
	if file_path.strip_edges().is_empty():
		return _fail("Choose a file first.")
	var absolute := ProjectSettings.globalize_path(file_path).simplify_path()
	if not absolute.is_absolute_path():
		return _fail("Choose an absolute path, or a res:// or user:// path.")
	var read := _read(absolute)
	if read.is_empty():
		return false
	var decision := decide_format(absolute, read["text"])
	if str(decision["format"]).is_empty():
		return _fail("Cannot read %s: %s" % [absolute, decision["error"]])
	path = absolute
	file_size = read["size"]
	_format = str(decision["format"])
	rows = decision["rows"]
	_index.clear()
	for i in rows.size():
		_index[rows[i]["id"]] = i
	return true


func reload() -> bool:
	return open_file(path) if not path.is_empty() else _fail("No file is open.")


func count() -> int:
	return rows.size()


func format_name() -> String:
	## "json" or "config": the reader that accepted the open file, never the extension.
	return _format


func is_json() -> bool:
	## Kept for callers that only ask whether the open file was read as JSON.
	return _format == JSON_FORMAT


func entry(id: String) -> Dictionary:
	if not _index.has(id):
		return {}
	var row: Dictionary = rows[_index[id]]
	return {
		"id": row["id"],
		"section": row["section"],
		"key": row["key"],
		"kind": row["kind"],
		"value": row["original"],
		"editable_in_editor_addon": row["editable"],
	}


static func decide_format(absolute: String, text: String) -> Dictionary:
	## The one place that decides how a file is read. Returns {"format": "json"|"config"|"",
	## "error": "", "rows": []}. The rows come back with the decision so a large file is
	## parsed once, not twice.
	var rows: Array[Dictionary] = []
	var extension := absolute.get_extension().to_lower()
	if extension in JSON_NAMES or extension in CONFIG_NAMES:
		# The name claims a format, so the content is not consulted: a JSON body named .cfg is
		# reported as the ConfigFile error it is, not silently read the other way.
		var named := Parser.new()
		var named_json := extension in JSON_NAMES
		if not named.parse(text, named_json):
			return {"format": "", "error": named.error, "rows": rows}
		return {"format": JSON_FORMAT if named_json else CONFIG_FORMAT, "error": "", "rows": named.rows}
	# The name says nothing (a SaveMadeEasy save_data.sav, .dat, a file with no extension).
	# JSON is tried first and must parse to the end; an input that parses both ways is JSON,
	# so the same file always opens the same way.
	var as_json := Parser.new()
	if as_json.parse(text, true):
		return {"format": JSON_FORMAT, "error": "", "rows": as_json.rows}
	var as_config := Parser.new()
	if as_config.parse(text, false):
		return {"format": CONFIG_FORMAT, "error": "", "rows": as_config.rows}
	# Neither reader accepts it: report the one the first significant character points at, so
	# a truncated JSON save shows a JSON position and a broken .cfg-style file shows the other.
	var reason := as_json.error if _leads_like_json(text) else as_config.error
	return {"format": "", "error": "this file is not JSON and not a Godot ConfigFile (%s)" % reason, "rows": rows}


static func _leads_like_json(text: String) -> bool:
	## BOM and whitespace skipped, the first character of every JSON document this reader
	## accepts: an object, an array, a string, a number, true, false or null.
	var cursor := 1 if text.length() > 0 and text.unicode_at(0) == 0xFEFF else 0
	while cursor < text.length():
		var character := text[cursor]
		if character != " " and character != "	" and character != "\r" and character != "\n":
			break
		cursor += 1
	if cursor >= text.length():
		return false
	var lead := text[cursor]
	return lead in ["{", "[", "\"", "-", "t", "f", "n"] or (lead >= "0" and lead <= "9")


func _read(absolute: String) -> Dictionary:
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		_fail("Cannot open %s: %s." % [absolute, error_string(FileAccess.get_open_error())])
		return {}
	var length := file.get_length()
	if length > MAX_BYTES:
		file.close()
		_fail("This file is larger than the 8 MiB limit: " + absolute)
		return {}
	var bytes := file.get_buffer(length)
	var read_error := file.get_error()
	var end_length := file.get_length()
	file.close()
	if bytes.size() != length or end_length != length or read_error != OK:
		_fail("The file could not be read completely: " + absolute)
		return {}
	if bytes.has(0):
		_fail("Binary, UTF-16 and compressed save files are not supported: " + absolute)
		return {}
	var bom := bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf
	var payload := bytes.slice(3) if bom else bytes
	var text := ("\ufeff" if bom else "") + payload.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		_fail("This file is not valid UTF-8 text: " + absolute)
		return {}
	return {"text": text, "size": bytes.size()}


func _fail(message: String) -> bool:
	last_error = message
	return false
