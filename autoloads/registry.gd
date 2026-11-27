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

func get_epic(definition_id: StringName) -> EpicDef:
	return defs.get_epic(definition_id)

func all_epics() -> Array[EpicDef]:
	return defs.all_epics()

func all_events() -> Array[EventTemplate]:
	return defs.all_events()

func get_era(definition_id: StringName) -> EraDef:
	return defs.get_era(definition_id)

func get_era_for_year(year: int) -> EraDef:
	return defs.get_era_for_year(year)

func get_institution(definition_id: StringName) -> InstitutionDef:
	return defs.get_institution(definition_id)

func all_institutions() -> Array[InstitutionDef]:
	return defs.all_institutions()

func get_route(definition_id: StringName) -> RouteDef:
	return defs.get_route(definition_id)

func all_routes() -> Array[RouteDef]:
	return defs.all_routes()

func get_place(definition_id: StringName) -> PlaceDef:
	return defs.get_place(definition_id)

func all_places() -> Array[PlaceDef]:
	return defs.all_places()

func get_trait(definition_id: StringName) -> TraitDef:
	return defs.get_trait(definition_id)

func get_occupation(definition_id: StringName) -> OccupationDef:
	return defs.get_occupation(definition_id)

func get_character_template(definition_id: StringName) -> CharacterTemplate:
	return defs.get_character_template(definition_id)

func all_occupations() -> Array[OccupationDef]:
	return defs.all_occupations()

func all_character_templates() -> Array[CharacterTemplate]:
	return defs.all_character_templates()

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
