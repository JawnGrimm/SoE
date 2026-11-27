class_name CharacterTemplate
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var occupation_id: StringName = &""
@export var culture_id: StringName = &""
@export var era_ids: Array[StringName] = []
@export var trait_ids: Array[StringName] = []
@export var skill_bonuses: Dictionary = {}
@export_range(1, 1000) var weight: int = 1

func is_valid() -> bool:
	return id != &"" and occupation_id != &"" and culture_id != &"" and weight > 0
