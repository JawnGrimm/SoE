class_name EpicDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var target: int = 100
@export var sponsor_institution: StringName = &""
@export var strong_labor: int = 10
@export var strong_barley: int = 120
@export var strong_progress: int = 3
@export var strong_barley_cost: int = 4
@export var partial_labor: int = 6
@export var partial_barley: int = 60
@export var partial_progress: int = 1
@export var partial_barley_cost: int = 2
@export var disruption_flags: Array[StringName] = []
@export var inundation_period_min: int = 0
@export var inundation_period_max: int = 2
@export var regression_labor_below: int = 6
@export var regression_amount: int = 2
