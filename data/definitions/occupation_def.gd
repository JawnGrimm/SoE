class_name OccupationDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var culture_tags: Array[StringName] = []
@export var era_ids: Array[StringName] = []
@export var office_id: StringName = &""
@export var skill_ranges: Dictionary = {}
@export var trait_ids: Array[StringName] = []
@export_range(1, 1000) var weight: int = 1

func is_valid() -> bool:
	if id == &"" or display_name.strip_edges().is_empty() or weight <= 0:
		return false
	for skill_id in skill_ranges:
		var bounds: Variant = skill_ranges[skill_id]
		if not (bounds is Vector2i) or bounds.x < 0 or bounds.y < bounds.x:
			return false
	return true
