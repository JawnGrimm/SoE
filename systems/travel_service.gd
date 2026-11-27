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
			"route_name": route.display_name,
			"route_type": route.route_type,
			"status": network.get_route_status(route_id),
			"transit_periods": periods,
			"available": periods > 0
		})
	return result

func travel(world: WorldState, route_id: StringName, destination_id: StringName) -> Dictionary:
	return execute_selected_journey(world, world.get_player() if world != null else null, destination_id, route_id)


func execute_journey(world: WorldState, actor: PersonEntity, destination_id: StringName) -> Dictionary:
	return execute_selected_journey(world, actor, destination_id, &"")


func execute_selected_journey(world: WorldState, actor: PersonEntity, destination_id: StringName, route_id: StringName) -> Dictionary:
	if world == null or actor == null or network == null or simulator == null or network.world != world:
		return _failure("Travel service is not configured for this traveler and world.")
	var origin_id := world.current_location_id
	if destination_id == &"" or destination_id == origin_id:
		return _failure("The destination is invalid.")
	if network.get_place(destination_id) == null:
		return _failure("The destination is not registered in this region.")
	var selected_route_id := route_id
	if selected_route_id == &"":
		for connected_route_id in network.get_connected_route_ids(origin_id):
			var connected_route := network.get_route(connected_route_id)
			if connected_route == null:
				continue
			var connected_destination := connected_route.destination_id if connected_route.origin_id == origin_id else connected_route.origin_id
			if connected_destination == destination_id:
				selected_route_id = connected_route_id
				break
	if selected_route_id == &"":
		return _failure("No registered route connects the current location to that destination.")
	var route := network.get_route(selected_route_id)
	if route == null:
		return _failure("The selected route is not registered.")
	var periods := network.get_transit_periods(selected_route_id, origin_id, destination_id)
	if periods < 1:
		return _failure("The selected route is closed, disrupted beyond use, or does not connect these places.")

	var origin := network.get_place(origin_id)
	var destination := network.get_place(destination_id)
	var origin_name := origin.display_name if origin != null else String(origin_id)
	var destination_name := destination.display_name if destination != null else String(destination_id)
	var departure_period := world.total_periods
	var fare_paid := 0
	var fare_due := 1
	var purse := int(actor.resources.get(&"silver", 0))
	if purse >= fare_due:
		actor.resources[&"silver"] = purse - fare_due
		fare_paid = fare_due
	else:
		actor.flags[&"unpaid_route_fees"] = int(actor.flags.get(&"unpaid_route_fees", 0)) + fare_due
		var archivist := world.get_person(&"shuruppak_ilu")
		if archivist != null:
			archivist.change_opinion(actor.id, -1, "The apprentice departed without paying the route fee.", world.year)
		world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "ROUTE FEE IN ARREARS", "summary": "One silver passage fee remains owed. Travel proceeds; the debt is recorded."})

	# The authoritative simulator owns every elapsed period; UI only presents arrival.
	for _period_index in range(periods):
		simulator.advance_period(world)
	_mark_arriving_dispatches(world, destination_id)
	world.current_location_id = destination_id
	world.last_period_deltas.append({"category": "travel", "text": "Arrived at %s (%s)" % [destination_name, "-1 silver fare paid" if fare_paid > 0 else "passage fee entered as debt"]})
	while world.last_period_deltas.size() > 12:
		world.last_period_deltas.pop_front()
	var fare_text := "paid one silver passage fare" if fare_paid > 0 else "deferred the one-silver passage fee"
	var log_entry := "Traveled from %s to %s via %s; %s." % [origin_name, destination_name, route.display_name, fare_text]
	return {
		"success": true,
		"route_id": selected_route_id,
		"route_name": route.display_name,
		"route_type": route.route_type,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"origin": origin_name,
		"destination": destination_name,
		"transit_periods": periods,
		"elapsed_periods": periods,
		"departure_period": departure_period,
		"arrival_period": world.total_periods,
		"fare_paid": fare_paid,
		"fare_due": fare_due,
		"log_entry": log_entry
	}

func _failure(reason: String) -> Dictionary:
	return {"success": false, "error": reason}


func _mark_arriving_dispatches(world: WorldState, destination_id: StringName) -> void:
	for index in range(world.pending_forms.size()):
		var form: Dictionary = world.pending_forms[index]
		var form_type := StringName(form.get("form_type", ""))
		var is_requisition := bool(form.get("is_requisition", false)) or String(form_type).to_lower().contains("requisition")
		if not is_requisition or bool(form.get("dispatch", false)):
			continue
		var institution_id := StringName(form.get("institution_id", ""))
		var institution: Dictionary = world.institutions.get(institution_id, {})
		var form_place := StringName(institution.get("place_id", form.get("place_id", form.get("subject_id", ""))))
		if form_place != destination_id:
			continue
		var created_period := int(form.get("created_period", world.current_period_index()))
		if world.current_period_index() - created_period <= 4:
			continue
		form["dispatch"] = true
		form["dispatch_destination_id"] = destination_id
		world.pending_forms[index] = form
