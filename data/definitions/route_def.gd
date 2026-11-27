class_name RouteDef
extends Resource
## Immutable route definition. Conditions and active disruptions live in WorldState.

@export var id: StringName = &""
@export var from_place_id: StringName = &""
@export var to_place_id: StringName = &""
@export var route_type: StringName = &"river"
@export_range(1, 24) var travel_periods: int = 1
@export_range(0, 100) var loss_risk_percent: int = 0
@export var era_id: StringName = &"uruk_storehouse"

func is_valid() -> bool:
	return id != &"" and from_place_id != &"" and to_place_id != &"" and from_place_id != to_place_id and travel_periods > 0 and loss_risk_percent >= 0 and loss_risk_percent <= 100 and era_id != &""
