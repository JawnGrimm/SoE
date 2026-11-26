extends Node

var defs: DefinitionRegistry

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	defs = DefinitionRegistry.new()
	defs.load_defaults()

func get_event(definition_id: StringName) -> EventTemplate:
	return defs.get_event(definition_id)

func get_assignment(definition_id: StringName) -> AssignmentDef:
	return defs.get_assignment(definition_id)

func all_events() -> Array[EventTemplate]:
	return defs.all_events()

func get_era(definition_id: StringName) -> EraDef:
	return defs.get_era(definition_id)

func get_era_for_year(year: int) -> EraDef:
	return defs.get_era_for_year(year)

func get_trait(definition_id: StringName) -> Resource:
	return defs.get_trait(definition_id)

func get_form(definition_id: StringName) -> Resource:
	return defs.get_form(definition_id)

func get_definition(definition_id: StringName) -> Resource:
	return defs.get_definition(definition_id)

func has_definition(definition_id: StringName) -> bool:
	return defs.has_definition(definition_id)

func get_definitions(category: String) -> Array[Resource]:
	return defs.get_definitions(category)

func get_definition_ids(category: String = "") -> Array[StringName]:
	return defs.get_definition_ids(category)

var warnings: Array[String]:
	get:
		return defs.warnings if defs != null else []
