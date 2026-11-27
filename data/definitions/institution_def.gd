class_name InstitutionDef
extends Resource
## Immutable institution definition. Live membership, activity, pressure, and stockpiles belong to WorldState.

@export var id: StringName = &""
@export var display_name: String = ""
@export var institution_type: StringName = &"institutional_household"
@export var place_id: StringName = &""
@export var era_id: StringName = &""
@export var members: Array[StringName] = []
@export var interests: Array[StringName] = []
@export var staffed_offices: Array[StringName] = []
@export var starting_stockpiles: Dictionary = {}
@export var periodic_deltas: Dictionary = {}
@export var harvest_deltas: Dictionary = {}
@export var pressure_thresholds: Dictionary = {}
@export var starting_activity_count: int = 0
@export var ledger_work_title: String = ""
@export_multiline var ledger_work_summary: String = ""
@export var ledger_work_priority: int = 1

func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty() and place_id != &"" and era_id != &""

func create_runtime_state() -> Dictionary:
	return {
		"name": display_name,
		"kind": institution_type,
		"place_id": place_id,
		"era_id": era_id,
		"members": members.duplicate(),
		"interests": interests.duplicate(),
		"staffed_offices": staffed_offices.duplicate(),
		"stockpiles": starting_stockpiles.duplicate(true),
		"periodic_deltas": periodic_deltas.duplicate(true),
		"harvest_deltas": harvest_deltas.duplicate(true),
		"pressure_thresholds": pressure_thresholds.duplicate(true),
		"activity_count": starting_activity_count,
		"ledger_work_title": ledger_work_title,
		"ledger_work_summary": ledger_work_summary,
		"ledger_work_priority": ledger_work_priority
	}
