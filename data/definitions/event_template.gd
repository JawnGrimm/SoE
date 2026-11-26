class_name EventTemplate
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var era_tags: Array[StringName] = []
@export var weight: float = 1.0
@export var cooldown_years: int = 0
@export var once_per_character: bool = false
@export var once_per_world: bool = false
@export var conditions: Array[EventCondition] = []
@export var outcomes: Array[EventOutcome] = []
@export var records: Array[Dictionary] = []
