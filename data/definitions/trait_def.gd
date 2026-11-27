class_name TraitDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var culture_tags: Array[StringName] = []
@export var era_ids: Array[StringName] = []

func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty()
