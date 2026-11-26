extends Node

const DEFINITION_DIRECTORIES: Array[String] = [
	"res://data/events",
	"res://data/traits",
	"res://data/forms",
	"res://data/eras",
]

var _definitions_by_id: Dictionary = {}
var _definitions_by_category: Dictionary = {}

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	_definitions_by_id.clear()
	_definitions_by_category.clear()

	for directory in DEFINITION_DIRECTORIES:
		var category := directory.get_file()
		var paths: Array[String] = []
		_collect_definition_paths(directory, paths)
		paths.sort()

		var category_definitions: Array[Resource] = []
		for resource_path in paths:
			var definition := ResourceLoader.load(resource_path)
			if definition == null:
				push_warning("Registry: failed to load definition at '%s'" % resource_path)
				continue
			if not _has_id_property(definition):
				push_warning("Registry: resource at '%s' has no 'id' property" % resource_path)
				continue

			var definition_id := StringName(str(definition.get("id")))
			if definition_id == &"":
				push_warning("Registry: resource at '%s' has an empty id" % resource_path)
				continue
			if _definitions_by_id.has(definition_id):
				push_error(
					"Registry: duplicate definition id '%s' at '%s'; keeping '%s'"
					% [definition_id, resource_path, _definitions_by_id[definition_id].resource_path]
				)
				continue

			_definitions_by_id[definition_id] = definition
			category_definitions.append(definition)

		_definitions_by_category[category] = category_definitions

func get_definition(definition_id: StringName) -> Resource:
	return _definitions_by_id.get(definition_id) as Resource

func has_definition(definition_id: StringName) -> bool:
	return _definitions_by_id.has(definition_id)

func get_definitions(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for definition in _definitions_by_category.get(category, []):
		result.append(definition)
	return result

func get_definition_ids(category: String = "") -> Array[StringName]:
	var result: Array[StringName] = []
	if category.is_empty():
		for definition_id in _definitions_by_id:
			result.append(definition_id)
	else:
		for definition in _definitions_by_category.get(category, []):
			result.append(StringName(str(definition.get("id"))))
	result.sort()
	return result

func _collect_definition_paths(directory: String, paths: Array[String]) -> void:
	var access := DirAccess.open(directory)
	if access == null:
		return

	access.list_dir_begin()
	var entry := access.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = access.get_next()
			continue

		var entry_path := directory.path_join(entry)
		if access.current_is_dir():
			_collect_definition_paths(entry_path, paths)
		else:
			var resource_path := entry_path.trim_suffix(".remap")
			if resource_path.ends_with(".tres"):
				paths.append(resource_path)
		entry = access.get_next()
	access.list_dir_end()

func _has_id_property(resource: Resource) -> bool:
	for property_info in resource.get_property_list():
		if String(property_info.get("name", "")) == "id":
			return true
	return false
