class_name TravelService
extends RefCounted
## Executes a complete journey against the authoritative world simulation.
## UI code selects a route and destination; it never advances the clock itself.

var network: RouteNetwork
var simulator: WorldSimulator

func configure(route_network: RouteNetwork, world_simulator: WorldSimulator) -> bool:
	if route_network == null or world_simulator == null:
		return false
	network = route_network
	simulator = world_simulator
	return true

func get_available_destinations(world: WorldState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null or network == null or network.world != world:
		return result
	for route_id in network.get_connected_route_ids(world.current_location_id):
		var route := network.get_route(route_id)
		if route == null:
			continue
		var destination_id := route.destination_id if route.origin_id == world.current_location_id else route.origin_id
		var destination := network.get_place(destination_id)
		if destination == null:
			continue
		var periods := network.get_transit_periods(route_id, world.current_location_id, destination_id)
		result.append({
			"route_id": route_id,
			"destination_id": destination_id,
			"destination_name": destination.display_name,
			"route_type": route.route_type,
			"status": network.get_route_status(route_id),
			"transit_periods": periods,
			"available": periods > 0
		})
	return result

func travel(world: WorldState, route_id: StringName, destination_id: StringName) -> Dictionary:
	if world == null or network == null or simulator == null or network.world != world:
		return _failure("Travel service is not configured for this world.")
	var origin_id := world.current_location_id
	if destination_id == &"" or destination_id == origin_id:
		return _failure("The destination is invalid.")
	if network.get_place(destination_id) == null:
		return _failure("The destination is not registered in this region.")
	var route := network.get_route(route_id)
	if route == null:
		return _failure("The selected route is not registered.")
	var periods := network.get_transit_periods(route_id, origin_id, destination_id)
	if periods < 1:
		return _failure("The selected route is closed, disrupted beyond use, or does not connect these places.")
	var departure_period := world.total_periods
	for _period_index in range(periods):
		simulator.advance_period(world)
	world.current_location_id = destination_id
	return {
		"success": true,
		"route_id": route_id,
		"route_name": route.display_name,
		"route_type": route.route_type,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"transit_periods": periods,
		"departure_period": departure_period,
		"arrival_period": world.total_periods
	}

func _failure(reason: String) -> Dictionary:
	return {"success": false, "error": reason}
