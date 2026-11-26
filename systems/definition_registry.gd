class_name DefinitionRegistry
extends RefCounted

const DEFAULT_FOLDERS: Dictionary = {
	"events": "res://data/events",
	"traits": "res://data/traits",
	"forms": "res://data/forms",
	"eras": "res://data/eras",
	"assignments": "res://data/assignments",
}

var warnings: Array[String] = []
var _definitions_by_id: Dictionary = {}
var _definitions_by_category: Dictionary = {}

func load_defaults() -> void:
	for category in DEFAULT_FOLDERS:
		load_folder(String(DEFAULT_FOLDERS[category]), String(category))

## Loads every .tres definition under a folder. Returns the number registered.
func load_folder(folder_path: String, category: String = "") -> int:
	var resolved_category := category if not category.is_empty() else folder_path.get_file()
	var access := DirAccess.open(folder_path)
	if access == null:
		# Traits and forms are optional data folders until their definitions are authored.
		if resolved_category == "traits" or resolved_category == "forms":
			return 0
		_warn("DefinitionRegistry: cannot open definition folder '%s'" % folder_path)
		return 0

	var paths: Array[String] = []
	_collect_definition_paths(folder_path, paths)
	paths.sort()
	var registered := 0
	for resource_path in paths:
		var definition := ResourceLoader.load(resource_path)
		if definition == null:
			_warn("DefinitionRegistry: failed to load definition at '%s'" % resource_path)
			continue
		if register_definition(definition, resolved_category):
			registered += 1
	return registered

func register_event(definition: EventTemplate) -> bool:
	return register_definition(definition, "events")

func register_era(definition: EraDef) -> bool:
	return register_definition(definition, "eras")

func register_assignment(definition: AssignmentDef) -> bool:
	if definition == null or not definition.is_valid():
		_warn("DefinitionRegistry: rejected malformed AssignmentDef")
		return false
	return register_definition(definition, "assignments")

func register_trait(definition: Resource) -> bool:
	return register_definition(definition, "traits")

func register_form(definition: Resource) -> bool:
	return register_definition(definition, "forms")

func register_definition(definition: Resource, category: String) -> bool:
	if definition == null:
		_warn("DefinitionRegistry: cannot register a null definition")
		return false
	if not _has_id_property(definition):
		_warn("DefinitionRegistry: resource has no 'id' property")
		return false
	if category == "assignments":
		var assignment := definition as AssignmentDef
		if assignment == null or not assignment.is_valid():
			_warn("DefinitionRegistry: rejected malformed AssignmentDef")
			return false

	var definition_id := StringName(str(definition.get("id")))
	if definition_id == &"":
		_warn("DefinitionRegistry: definition has an empty id")
		return false
	if _definitions_by_id.has(definition_id):
		_warn(
			"DefinitionRegistry: duplicate definition id '%s' in category '%s'; keeping first registration"
			% [definition_id, category]
		)
		return false

	_definitions_by_id[definition_id] = definition
	if not _definitions_by_category.has(category):
		_definitions_by_category[category] = []
	_definitions_by_category[category].append(definition)
	return true

func get_definition(definition_id: StringName) -> Resource:
	return _definitions_by_id.get(definition_id) as Resource

func get_event(definition_id: StringName) -> EventTemplate:
	return get_definition(definition_id) as EventTemplate

func get_era(definition_id: StringName) -> EraDef:
	return get_definition(definition_id) as EraDef

func get_assignment(definition_id: StringName) -> AssignmentDef:
	return get_definition(definition_id) as AssignmentDef

func get_era_for_year(year: int) -> EraDef:
	for definition in all_eras():
		if year >= definition.start_year and year <= definition.end_year:
			return definition
	return null

func get_trait(definition_id: StringName) -> Resource:
	return get_definition(definition_id)

func get_form(definition_id: StringName) -> Resource:
	return get_definition(definition_id)

func has_definition(definition_id: StringName) -> bool:
	return _definitions_by_id.has(definition_id)

func get_definitions(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for definition in _definitions_by_category.get(category, []):
		result.append(definition)
	return result

func all_events() -> Array[EventTemplate]:
	var result: Array[EventTemplate] = []
	for definition in _definitions_by_category.get("events", []):
		if definition is EventTemplate:
			result.append(definition)
	result.sort_custom(func(a: EventTemplate, b: EventTemplate) -> bool: return String(a.id) < String(b.id))
	return result

func all_eras() -> Array[EraDef]:
	var result: Array[EraDef] = []
	for definition in _definitions_by_category.get("eras", []):
		if definition is EraDef:
			result.append(definition)
	result.sort_custom(func(a: EraDef, b: EraDef) -> bool: return a.start_year < b.start_year)
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

func _warn(message: String) -> void:
	warnings.append(message)
	push_warning(message)
