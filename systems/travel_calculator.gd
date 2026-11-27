class_name TravelCalculator
extends RefCounted
## Pure transit calculations. No scene tree, plugin, or visual-node dependencies.

func calculate_transit_periods(route: RouteDef, from_id: StringName, to_id: StringName, world: WorldState) -> int:
	if route == null or not route.is_valid() or world == null:
		return -1
	if not _is_valid_direction(route, from_id, to_id):
		return -1
	var periods := route.base_transit_periods
	if route.route_type == &"river":
		if from_id == route.downstream_destination_id:
			pass # Travelling away from the downstream destination is upstream.
		elif to_id == route.downstream_destination_id:
			pass # Arriving at the downstream destination follows the current.
		else:
			return -1
		if to_id != route.downstream_destination_id:
			periods += 1
	var disruption: Dictionary = world.routes.get(route.id, {})
	if StringName(disruption.get("status", &"")) == &"closed":
		return -1
	periods += maxi(0, int(disruption.get("transit_penalty_periods", 0)))
	return periods

func _is_valid_direction(route: RouteDef, from_id: StringName, to_id: StringName) -> bool:
	return (from_id == route.origin_id and to_id == route.destination_id) or (from_id == route.destination_id and to_id == route.origin_id)
