class_name RouteDef
extends Resource
## Immutable transport corridor. Runtime disruptions belong in WorldState.routes.

@export var id: StringName = &""
@export var origin_id: StringName = &""
@export var destination_id: StringName = &""
@export var route_type: StringName = &"land"
@export var display_name: String = ""
@export var era_id: StringName = &""
@export_range(1, 12, 1) var base_transit_periods: int = 1
## Destination reached when travelling downstream. Empty for non-river routes.
@export var downstream_destination_id: StringName = &""

func is_valid() -> bool:
	if id == &"" or origin_id == &"" or destination_id == &"":
		return false
	if origin_id == destination_id or base_transit_periods < 1:
		return false
	if route_type not in [&"river", &"land"]:
		return false
	if route_type == &"river":
		return downstream_destination_id in [origin_id, destination_id]
	return downstream_destination_id == &""
