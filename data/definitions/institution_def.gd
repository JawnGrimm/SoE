class_name InstitutionDef
extends Resource
## Immutable institution definition. Live membership, activity, pressure, and stockpiles belong to WorldState.

@export var id: StringName = &""
@export var display_name: String = ""
@export var institution_type: StringName = &"institutional_household"
@export var place_id: StringName = &""
@export var members: Array[StringName] = []
@export var interests: Array[StringName] = []
@export var starting_stockpiles: Dictionary = {}
@export var starting_activity_count: int = 0

func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty() and place_id != &""

func create_runtime_state() -> Dictionary:
	return {
		"name": display_name,
		"kind": institution_type,
		"place_id": place_id,
		"members": members.duplicate(),
		"interests": interests.duplicate(),
		"stockpiles": starting_stockpiles.duplicate(true),
		"activity_count": starting_activity_count
	}
