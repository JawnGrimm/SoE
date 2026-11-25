class_name EventCondition
extends Resource

@export var condition_type: StringName = &""
@export_enum("actor", "target", "liege", "spouse", "rival") var target: String = "actor"
@export var parameters: Dictionary = {}
