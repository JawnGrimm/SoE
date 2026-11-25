class_name EventEffect
extends Resource

@export var effect_type: StringName = &""
@export_enum("actor", "target", "liege", "spouse", "rival") var target: String = "actor"
@export var parameters: Dictionary = {}
