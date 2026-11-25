class_name EventOutcome
extends Resource

@export var label: String = ""
@export var weight: float = 1.0
@export var title_override: String = ""
@export_multiline var description_override: String = ""
@export var effects: Array[EventEffect] = []
@export var follow_up_event: StringName = &""
