class_name RouteNetwork
extends RefCounted
## Headless route graph. The map UI reads this model; it never owns simulation rules.

var world: WorldState
var era_id: StringName = &""
var places: Dictionary[StringName, PlaceDef] = {}
var routes: Dictionary[StringName, RouteDef] = {}
var calculator := TravelCalculator.new()

func configure(world_state: WorldState, place_definitions: Array[PlaceDef], route_definitions: Array[RouteDef], active_era_id: StringName = &"") -> bool:
	if world_state == null:
		return false
	var next_places: Dictionary[StringName, PlaceDef] = {}
	var next_routes: Dictionary[StringName, RouteDef] = {}
	for place in place_definitions:
		if place == null or not place.is_valid() or next_places.has(place.id):
			return false
		next_places[place.id] = place
	for route in route_definitions:
		if route == null or not route.is_valid() or next_routes.has(route.id):
			return false
		if active_era_id != &"" and route.era_id != &"" and route.era_id != active_era_id:
			continue
		if not next_places.has(route.origin_id) or not next_places.has(route.destination_id):
			return false
		next_routes[route.id] = route
	world = world_state
	era_id = active_era_id
	places = next_places
	routes = next_routes
	return true

func get_place(place_id: StringName) -> PlaceDef:
	return places.get(place_id) as PlaceDef

func get_route(route_id: StringName) -> RouteDef:
	return routes.get(route_id) as RouteDef

func get_route_between(from_id: StringName, to_id: StringName) -> RouteDef:
	for route in routes.values():
		if (route.origin_id == from_id and route.destination_id == to_id) or (route.origin_id == to_id and route.destination_id == from_id):
			return route
	return null

func get_route_status(route_id: StringName) -> StringName:
	if not routes.has(route_id) or world == null:
		return &"unknown"
	var state: Dictionary = world.routes.get(route_id, {})
	var status := StringName(state.get("status", &"open"))
	if status == &"closed":
		return &"closed"
	if status == &"disrupted":
		return &"disrupted"
	return &"open"

func get_transit_periods(route_id: StringName, from_id: StringName, to_id: StringName) -> int:
	if world == null or not routes.has(route_id):
		return -1
	return calculator.calculate_transit_periods(routes[route_id], from_id, to_id, world)

func set_route_disruption(route_id: StringName, status: StringName, expiry_period: int = -1, transit_penalty_periods: int = 0) -> bool:
	if world == null or not routes.has(route_id) or status not in [&"disrupted", &"closed"]:
		return false
	world.routes[route_id] = {
		"status": status,
		"expiry_period": expiry_period,
		"has_expiry": expiry_period != -1,
		"transit_penalty_periods": maxi(0, transit_penalty_periods),
	}
	return true

func clear_route_disruption(route_id: StringName) -> bool:
	if world == null or not world.routes.has(route_id):
		return false
	world.routes.erase(route_id)
	return true

func get_connected_route_ids(place_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if not places.has(place_id):
		return result
	for route_id in routes:
		var route: RouteDef = routes[route_id]
		if route.origin_id == place_id or route.destination_id == place_id:
			result.append(route_id)
	result.sort()
	return result
