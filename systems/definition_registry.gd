class_name DefinitionRegistry
extends RefCounted

const DEFAULT_FOLDERS: Dictionary = {
	"events": "res://data/events",
	"traits": "res://data/traits",
	"forms": "res://data/forms",
	"eras": "res://data/eras",
	"assignments": "res://data/assignments",
	"places": "res://data/places",
	"routes": "res://data/routes",
	"institutions": "res://data/institutions",
	"epics": "res://data/epics",
}

var warnings: Array[String] = []
var _definitions_by_id: Dictionary = {}
var _definitions_by_category: Dictionary = {}

func load_defaults() -> void:
	for category in DEFAULT_FOLDERS:
		load_folder(String(DEFAULT_FOLDERS[category]), String(category))
	validate_world_references()

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

func validate_world_references() -> bool:
	var valid := true
	for place in all_places():
		if place.parent_place_id != &"" and get_place(place.parent_place_id) == null:
			_warn("DefinitionRegistry: place '%s' references missing parent '%s'" % [place.id, place.parent_place_id])
			valid = false
		for connected_place_id in place.connected_to:
			if get_place(connected_place_id) == null:
				_warn("DefinitionRegistry: place '%s' references unknown connected place '%s'" % [place.id, connected_place_id])
				valid = false
		if place.era_id != &"" and get_era(place.era_id) == null:
			_warn("DefinitionRegistry: place '%s' references missing era '%s'" % [place.id, place.era_id])
			valid = false
	for institution in all_institutions():
		if get_place(institution.place_id) == null:
			_warn("DefinitionRegistry: institution '%s' references missing place '%s'" % [institution.id, institution.place_id])
			valid = false
		if get_era(institution.era_id) == null:
			_warn("DefinitionRegistry: institution '%s' references missing era '%s'" % [institution.id, institution.era_id])
			valid = false
	for route in all_routes():
		if get_place(route.origin_id) == null or get_place(route.destination_id) == null:
			_warn("DefinitionRegistry: route '%s' references an unknown endpoint" % route.id)
			valid = false
		if route.era_id != &"" and get_era(route.era_id) == null:
			_warn("DefinitionRegistry: route '%s' references missing era '%s'" % [route.id, route.era_id])
			valid = false
	return valid

func register_event(definition: EventTemplate) -> bool:
	return register_definition(definition, "events")

func register_era(definition: EraDef) -> bool:
	return register_definition(definition, "eras")

func register_epic(definition: EpicDef) -> bool:
	if definition == null or definition.id == &"":
		_warn("DefinitionRegistry: rejected malformed EpicDef")
		return false
	return register_definition(definition, "epics")

func register_assignment(definition: AssignmentDef) -> bool:
	if definition == null or not definition.is_valid():
		_warn("DefinitionRegistry: rejected malformed AssignmentDef")
		return false
	return register_definition(definition, "assignments")

func register_place(definition: PlaceDef) -> bool:
	if definition == null or not definition.is_valid():
		_warn("DefinitionRegistry: rejected malformed PlaceDef")
		return false
	return register_definition(definition, "places")

func register_institution(definition: InstitutionDef) -> bool:
	if definition == null or not definition.is_valid():
		_warn("DefinitionRegistry: rejected malformed InstitutionDef")
		return false
	return register_definition(definition, "institutions")

func register_route(definition: RouteDef) -> bool:
	if definition == null or not definition.is_valid():
		_warn("DefinitionRegistry: rejected malformed RouteDef")
		return false
	return register_definition(definition, "routes")

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
	if category == "places":
		var place := definition as PlaceDef
		if place == null or not place.is_valid():
			_warn("DefinitionRegistry: rejected malformed PlaceDef")
			return false
	if category == "institutions":
		var institution := definition as InstitutionDef
		if institution == null or not institution.is_valid():
			_warn("DefinitionRegistry: rejected malformed InstitutionDef")
			return false
	if category == "routes":
		var route := definition as RouteDef
		if route == null or not route.is_valid():
			_warn("DefinitionRegistry: rejected malformed RouteDef")
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

func get_epic(definition_id: StringName) -> EpicDef:
	return get_definition(definition_id) as EpicDef

func all_epics() -> Array[EpicDef]:
	var result: Array[EpicDef] = []
	for definition in _definitions_by_category.get("epics", []):
		if definition is EpicDef:
			result.append(definition)
	result.sort_custom(func(a: EpicDef, b: EpicDef) -> bool: return String(a.id) < String(b.id))
	return result

func get_assignment(definition_id: StringName) -> AssignmentDef:
	return get_definition(definition_id) as AssignmentDef

func get_place(definition_id: StringName) -> PlaceDef:
	return get_definition(definition_id) as PlaceDef

func get_institution(definition_id: StringName) -> InstitutionDef:
	return get_definition(definition_id) as InstitutionDef

func all_institutions() -> Array[InstitutionDef]:
	var result: Array[InstitutionDef] = []
	for definition in _definitions_by_category.get("institutions", []):
		if definition is InstitutionDef:
			result.append(definition)
	result.sort_custom(func(a: InstitutionDef, b: InstitutionDef) -> bool: return String(a.id) < String(b.id))
	return result

func get_route(definition_id: StringName) -> RouteDef:
	return get_definition(definition_id) as RouteDef

func all_routes() -> Array[RouteDef]:
	var result: Array[RouteDef] = []
	for definition in _definitions_by_category.get("routes", []):
		if definition is RouteDef:
			result.append(definition)
	result.sort_custom(func(a: RouteDef, b: RouteDef) -> bool: return String(a.id) < String(b.id))
	return result

func all_places() -> Array[PlaceDef]:
	var result: Array[PlaceDef] = []
	for definition in _definitions_by_category.get("places", []):
		if definition is PlaceDef:
			result.append(definition)
	result.sort_custom(func(a: PlaceDef, b: PlaceDef) -> bool: return String(a.id) < String(b.id))
	return result

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
