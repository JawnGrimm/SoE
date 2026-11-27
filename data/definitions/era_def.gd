class_name EraDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## Inclusive bounds in the world's continuous simulation-year timeline.
@export var start_year: int = 0
@export var end_year: int = 0
@export var starting_place_id: StringName = &""

## Stable tags for event/content matching, independent of this definition's ID.
@export var era_tags: Array[StringName] = []

## Optional calendar metadata used by CalendarFormatter.
@export var calendar_name: String = ""
@export var currency_name: String = "silver"
@export var period_label: String = "Period"
@export var period_names: Array[String] = []
