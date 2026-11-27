class_name RegionalWorldSystem
extends RefCounted
## Advances regional routes, shipments, and player travel independently of assignments.

const ROUTE_FOLDER := "res://data/routes"

static func seed_routes(world: WorldState) -> int:
	if world == null:
		return 0
	world.routes.clear()
	var directory := DirAccess.open(ROUTE_FOLDER)
	if directory == null:
		push_warning("RegionalWorldSystem: route definition folder is missing.")
		return 0
	var paths: Array[String] = []
	_collect_tres(ROUTE_FOLDER, paths)
	paths.sort()
	var loaded := 0
	for path in paths:
		var definition := ResourceLoader.load(path) as RouteDef
		if definition == null or not definition.is_valid():
			push_warning("RegionalWorldSystem: invalid route definition %s" % path)
			continue
		if world.routes.has(definition.id):
			push_warning("RegionalWorldSystem: duplicate route id %s" % definition.id)
			continue
		world.routes[definition.id] = {
			"id": definition.id, "from_place_id": definition.from_place_id,
			"to_place_id": definition.to_place_id, "route_type": definition.route_type,
			"travel_periods": definition.travel_periods,
			"loss_risk_percent": definition.loss_risk_percent,
			"risk_modifier": 0, "risk_modifier_until": -1,
			"era_id": definition.era_id, "active": true
		}
		loaded += 1
	return loaded

static func _collect_tres(folder: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".tres"):
			paths.append(folder.path_join(filename))
	for subdir in directory.get_directories():
		_collect_tres(folder.path_join(subdir), paths)

static func find_route_path(world: WorldState, origin_id: StringName, destination_id: StringName) -> Array[StringName]:
	if world == null or origin_id == &"" or destination_id == &"":
		return []
	if origin_id == destination_id:
		return []
	var queue: Array[StringName] = [origin_id]
	var visited: Dictionary = {origin_id: true}
	var previous_place: Dictionary = {}
	var previous_route: Dictionary = {}
	while not queue.is_empty():
		var place_id: StringName = queue.pop_front()
		for route_id in world.routes.keys():
			var route: Dictionary = world.routes[route_id]
			if not bool(route.get("active", true)) or StringName(route.get("from_place_id", "")) != place_id:
				continue
			var next_place := StringName(route.get("to_place_id", ""))
			if visited.has(next_place):
				continue
			visited[next_place] = true
			previous_place[next_place] = place_id
			previous_route[next_place] = StringName(route_id)
			if next_place == destination_id:
				var path: Array[StringName] = []
				var cursor := destination_id
				while cursor != origin_id:
					path.push_front(StringName(previous_route[cursor]))
					cursor = StringName(previous_place[cursor])
				return path
			queue.append(next_place)
	return []

static func route_path_periods(world: WorldState, route_ids: Array) -> int:
	var total := 0
	if world == null:
		return total
	for route_id in route_ids:
		total += maxi(1, int(world.routes.get(StringName(route_id), {}).get("travel_periods", 1)))
	return total


static func get_destination_options(world: WorldState, origin_id: StringName) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if world == null or origin_id == &"":
		return options
	for place_id in world.places.keys():
		if StringName(place_id) == origin_id:
			continue
		var route_ids := find_route_path(world, origin_id, StringName(place_id))
		if route_ids.is_empty():
			continue
		var total_risk := 0
		for route_id in route_ids:
			total_risk += effective_route_risk(world, route_id)
		options.append({
			"place_id": StringName(place_id),
			"name": String(world.places[place_id].get("name", place_id)),
			"route_ids": route_ids,
			"travel_periods": route_path_periods(world, route_ids),
			"route_risk_percent": total_risk
		})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("travel_periods", 0)) == int(b.get("travel_periods", 0)):
			return String(a.get("name", "")) < String(b.get("name", ""))
		return int(a.get("travel_periods", 0)) < int(b.get("travel_periods", 0))
	)
	return options

static func launch_shipment(world: WorldState, details: Dictionary) -> Dictionary:
	if world == null:
		return {"success": false, "error": "World is unavailable."}
	var origin_id := StringName(details.get("origin_id", ""))
	var destination_id := StringName(details.get("destination_id", ""))
	var commodity_id := StringName(details.get("commodity_id", ""))
	var quantity := int(details.get("quantity", 0))
	if not world.places.has(origin_id) or not world.places.has(destination_id) or commodity_id == &"" or quantity <= 0:
		return {"success": false, "error": "Shipment requires valid places, a commodity, and a positive quantity."}
	var route_ids := find_route_path(world, origin_id, destination_id)
	if origin_id != destination_id and route_ids.is_empty():
		return {"success": false, "error": "No active route connects the origin and destination."}
	var shipment_id := StringName("shipment_%06d" % world._next_shipment_sequence)
	world._next_shipment_sequence += 1
	var shipment := {
		"id": shipment_id, "origin_id": origin_id, "destination_id": destination_id,
		"commodity_id": commodity_id, "declared_quantity": quantity,
		"received_quantity": quantity, "loss_quantity": 0,
		"route_ids": route_ids, "route_index": 0,
		"remaining_periods": int(world.routes.get(route_ids[0], {}).get("travel_periods", 1)) if not route_ids.is_empty() else 0,
		"departure_period": world.current_period_index(),
		"status": "in_transit" if not route_ids.is_empty() else "arrived",
		"seal_id": String(details.get("seal_id", "")),
		"seal_valid": bool(details.get("seal_valid", true)),
		"sender_id": StringName(details.get("sender_id", "")),
		"destination_institution_id": StringName(details.get("destination_institution_id", "")),
		"origin_account_quantity": int(details.get("origin_account_quantity", quantity)),
		"origin_reply_due_period": -1
	}
	world.shipments[shipment_id] = shipment
	if route_ids.is_empty():
		_arrive_shipment(world, shipment)
	return {"success": true, "shipment_id": shipment_id, "route_ids": route_ids, "travel_periods": route_path_periods(world, route_ids)}

static func advance_period(world: WorldState) -> void:
	if world == null:
		return
	for shipment_id in world.shipments.keys():
		var shipment: Dictionary = world.shipments[shipment_id]
		if String(shipment.get("status", "")) != "in_transit":
			continue
		shipment["remaining_periods"] = int(shipment.get("remaining_periods", 1)) - 1
		if int(shipment["remaining_periods"]) <= 0:
			_finish_shipment_leg(world, shipment)
		world.shipments[shipment_id] = shipment
	_advance_player_travel(world)

static func _finish_shipment_leg(world: WorldState, shipment: Dictionary) -> void:
	var route_ids: Array = shipment.get("route_ids", [])
	var route_index := int(shipment.get("route_index", 0))
	if route_index < 0 or route_index >= route_ids.size():
		shipment["status"] = "arrived"
		_arrive_shipment(world, shipment)
		return
	var route: Dictionary = world.routes.get(StringName(route_ids[route_index]), {})
	var risk := effective_route_risk(world, StringName(route_ids[route_index]))
	var received := int(shipment.get("received_quantity", 0))
	if risk > 0 and received > 0 and world.rng_sim.randi_range(1, 100) <= risk:
		var lost := mini(received, world.rng_sim.randi_range(1, mini(4, received)))
		shipment["received_quantity"] = received - lost
		shipment["loss_quantity"] = int(shipment.get("loss_quantity", 0)) + lost
		shipment["last_route_loss"] = lost
	else:
		shipment["last_route_loss"] = 0
	route_index += 1
	shipment["route_index"] = route_index
	if route_index >= route_ids.size():
		shipment["status"] = "arrived"
		_arrive_shipment(world, shipment)
	else:
		shipment["remaining_periods"] = maxi(1, int(world.routes.get(StringName(route_ids[route_index]), {}).get("travel_periods", 1)))

static func _arrive_shipment(world: WorldState, shipment: Dictionary) -> void:
	if bool(shipment.get("arrival_recorded", false)):
		return
	shipment["arrival_recorded"] = true
	shipment["arrival_period"] = world.current_period_index()
	shipment["status"] = "arrived"
	var shipment_id := StringName(shipment.get("id", ""))
	world.enqueue_form({
		"form_type": &"remote_dispatch", "subject_id": StringName(shipment.get("destination_id", "")),
		"origin_id": StringName(shipment.get("origin_id", "")),
		"destination_id": StringName(shipment.get("destination_id", "")),
		"shipment_id": shipment_id,
		"commodity_id": StringName(shipment.get("commodity_id", "")),
		"declared_quantity": int(shipment.get("declared_quantity", 0)),
		"received_quantity": int(shipment.get("received_quantity", 0)),
		"loss_quantity": int(shipment.get("loss_quantity", 0)),
		"seal_id": String(shipment.get("seal_id", "")),
		"seal_valid": bool(shipment.get("seal_valid", true)),
		"sender_id": StringName(shipment.get("sender_id", "")),
		"route_ids": shipment.get("route_ids", []).duplicate(),
		"departure_period": int(shipment.get("departure_period", 0)),
		"arrival_period": int(shipment.get("arrival_period", 0)),
		"urgency": 8, "status": "pending", "generated_by": "regional_world"
	})

static func start_player_travel(world: WorldState, actor: PersonEntity, destination_id: StringName) -> Dictionary:
	if world == null or actor == null:
		return {"success": false, "error": "A world and traveling character are required."}
	if not world.player_travel.is_empty() and String(world.player_travel.get("status", "")) == "in_transit":
		return {"success": false, "error": "The character is already traveling."}
	if not world.places.has(destination_id):
		return {"success": false, "error": "Destination is not a known place."}
	var origin_id := actor.current_location_id if actor.current_location_id != &"" else &"uruk"
	var route_ids := find_route_path(world, origin_id, destination_id)
	if origin_id != destination_id and route_ids.is_empty():
		return {"success": false, "error": "No active route connects the current location and destination."}
	world.player_travel = {
		"actor_id": actor.id, "origin_id": origin_id, "destination_id": destination_id,
		"route_ids": route_ids, "route_index": 0,
		"remaining_periods": int(world.routes.get(route_ids[0], {}).get("travel_periods", 1)) if not route_ids.is_empty() else 0,
		"departure_period": world.current_period_index(),
		"status": "in_transit" if not route_ids.is_empty() else "arrived",
		"incidents": []
	}
	if route_ids.is_empty():
		actor.current_location_id = destination_id
	return {"success": true, "route_ids": route_ids, "travel_periods": route_path_periods(world, route_ids)}

static func _advance_player_travel(world: WorldState) -> void:
	if String(world.player_travel.get("status", "")) != "in_transit":
		return
	var travel: Dictionary = world.player_travel
	travel["remaining_periods"] = int(travel.get("remaining_periods", 1)) - 1
	if int(travel["remaining_periods"]) > 0:
		world.player_travel = travel
		return
	var route_ids: Array = travel.get("route_ids", [])
	var route_index := int(travel.get("route_index", 0))
	if route_index >= route_ids.size():
		travel["status"] = "arrived"
		world.player_travel = travel
		return
	var route_id := StringName(route_ids[route_index])
	var route: Dictionary = world.routes.get(route_id, {})
	var next_place := StringName(route.get("to_place_id", ""))
	var actor := world.get_person(StringName(travel.get("actor_id", "")))
	if actor != null and next_place != &"":
		actor.current_location_id = next_place
	var risk := effective_route_risk(world, route_id)
	if risk > 0 and world.rng_sim.randi_range(1, 100) <= risk:
		var incident := {"route_id": route_id, "period": world.current_period_index(), "kind": "travel_disruption"}
		var incidents: Array = travel.get("incidents", [])
		incidents.append(incident)
		travel["incidents"] = incidents
		world.travel_history.append(incident)
		if actor != null:
			actor.memory.append({"memory_id": &"regional_travel_incident", "text": "A travel disruption on %s delayed the journey." % String(route.get("route_type", "route")), "year": world.year, "involved": []})
	route_index += 1
	travel["route_index"] = route_index
	if route_index >= route_ids.size():
		travel["status"] = "arrived"
		travel["arrival_period"] = world.current_period_index()
	else:
		travel["remaining_periods"] = maxi(1, int(world.routes.get(StringName(route_ids[route_index]), {}).get("travel_periods", 1)))
	world.player_travel = travel



static func effective_route_risk(world: WorldState, route_id: StringName) -> int:
	if world == null or not world.routes.has(route_id):
		return 100
	var route: Dictionary = world.routes[route_id]
	var risk := int(route.get("loss_risk_percent", 0))
	if world.current_period_index() < int(route.get("risk_modifier_until", -1)):
		risk += int(route.get("risk_modifier", 0))
	return clampi(risk, 0, 100)

static func provision_route(world: WorldState, route_id: StringName, risk_reduction: int = 8, duration_periods: int = 3) -> bool:
	if world == null or not world.routes.has(route_id) or risk_reduction <= 0 or duration_periods <= 0:
		return false
	var route: Dictionary = world.routes[route_id]
	if not bool(route.get("active", true)):
		return false
	route["risk_modifier"] = -risk_reduction
	route["risk_modifier_until"] = world.current_period_index() + duration_periods
	world.routes[route_id] = route
	return true

static func simulate_regional_flows(world: WorldState) -> void:
	if world == null or not world.institutions.has(&"habuba_trade_post"):
		return
	var habuba: Dictionary = world.institutions[&"habuba_trade_post"]
	var habuba_stock: Dictionary = habuba.get("stockpiles", {})
	var timber := int(habuba_stock.get(&"timber", 0))
	if timber >= 4 and not _has_open_shipment(world, &"habuba_kabira", &"uruk", &"timber") and world.rng_sim.randf() < 0.30:
		var quantity := world.rng_sim.randi_range(4, mini(12, timber))
		if world.modify_resource(&"timber", -quantity, "institution", "", &"habuba_trade_post"):
			var launched := launch_shipment(world, {
				"origin_id": &"habuba_kabira", "destination_id": &"uruk",
				"commodity_id": &"timber", "quantity": quantity,
				"seal_id": "habuba_trade_seal_%d" % world.current_period_index(),
				"sender_id": &"enki_ili", "destination_institution_id": &"eanna_household"
			})
			if not bool(launched.get("success", false)):
				world.modify_resource(&"timber", quantity, "institution", "", &"habuba_trade_post")
	var eanna: Dictionary = world.institutions.get(&"eanna_household", {})
	var eanna_stock: Dictionary = eanna.get("stockpiles", {})
	var textiles := int(eanna_stock.get(&"textiles", 0))
	if textiles >= 3 and not _has_open_shipment(world, &"uruk", &"habuba_kabira", &"textiles") and world.rng_sim.randf() < 0.22:
		var quantity := world.rng_sim.randi_range(3, mini(6, textiles))
		if world.modify_resource(&"textiles", -quantity, "institution", "", &"eanna_household"):
			var launched := launch_shipment(world, {
				"origin_id": &"uruk", "destination_id": &"habuba_kabira",
				"commodity_id": &"textiles", "quantity": quantity,
				"seal_id": "eanna_export_seal_%d" % world.current_period_index(),
				"sender_id": &"geme_inana", "destination_institution_id": &"habuba_trade_post"
			})
			if not bool(launched.get("success", false)):
				world.modify_resource(&"textiles", quantity, "institution", "", &"eanna_household")

static func _has_open_shipment(world: WorldState, origin_id: StringName, destination_id: StringName, commodity_id: StringName) -> bool:
	for shipment in world.shipments.values():
		if StringName(shipment.get("origin_id", "")) != origin_id or StringName(shipment.get("destination_id", "")) != destination_id or StringName(shipment.get("commodity_id", "")) != commodity_id:
			continue
		if String(shipment.get("status", "")) in ["in_transit", "arrived", "held", "awaiting_origin"]:
			return true
	return false

static func resolve_remote_dispatch(world: WorldState, form_data: Dictionary, verdict: StringName) -> Dictionary:
	var shipment_id := StringName(form_data.get("shipment_id", ""))
	if world == null or shipment_id == &"" or not world.shipments.has(shipment_id):
		return {"success": false, "message": "The shipment record is no longer available."}
	var shipment: Dictionary = world.shipments[shipment_id]
	if String(shipment.get("status", "")) not in ["arrived", "held", "awaiting_origin"]:
		return {"success": false, "message": "The shipment is not available for assessment."}
	if verdict == &"certify":
		var quantity := int(shipment.get("received_quantity", 0))
		var commodity_id := StringName(shipment.get("commodity_id", ""))
		var institution_id := StringName(shipment.get("destination_institution_id", ""))
		if quantity > 0 and institution_id != &"":
			if not world.modify_resource(commodity_id, quantity, "institution", "", institution_id):
				return {"success": false, "message": "The destination institution cannot accept this cargo."}
		shipment["status"] = "accepted"
		shipment["accepted_quantity"] = quantity
		shipment["assessment_period"] = world.current_period_index()
		world.shipments[shipment_id] = shipment
		return {"success": true, "message": "The dispatch is certified. %d %s enter the destination account; the recorded loss remains attached to the route." % [quantity, String(commodity_id).replace("_", " ")]}
	if verdict == &"refer":
		shipment["status"] = "awaiting_origin"
		shipment["origin_reply_due_period"] = world.current_period_index() + 2
		world.shipments[shipment_id] = shipment
		world.enqueue_form({
			"form_type": &"remote_origin_reply", "subject_id": StringName(shipment.get("destination_id", "")),
			"shipment_id": shipment_id, "origin_id": StringName(shipment.get("origin_id", "")),
			"destination_id": StringName(shipment.get("destination_id", "")),
			"commodity_id": StringName(shipment.get("commodity_id", "")),
			"declared_quantity": int(shipment.get("declared_quantity", 0)),
			"received_quantity": int(shipment.get("received_quantity", 0)),
			"origin_account_quantity": int(shipment.get("origin_account_quantity", shipment.get("declared_quantity", 0))),
			"seal_id": String(shipment.get("seal_id", "")),
			"sender_id": StringName(shipment.get("sender_id", "")),
			"due_period": int(shipment.get("origin_reply_due_period", 0)),
			"urgency": 6, "status": "pending", "generated_by": "regional_world"
		})
		return {"success": true, "message": "The cargo is held. An origin-side account has been requested; the reply is due in two periods."}
	if verdict == &"defer":
		shipment["status"] = "held"
		shipment["assessment_period"] = world.current_period_index()
		world.shipments[shipment_id] = shipment
		world.enqueue_form({
			"form_type": &"remote_dispatch", "subject_id": StringName(shipment.get("destination_id", "")),
			"shipment_id": shipment_id, "origin_id": StringName(shipment.get("origin_id", "")),
			"destination_id": StringName(shipment.get("destination_id", "")),
			"commodity_id": StringName(shipment.get("commodity_id", "")),
			"declared_quantity": int(shipment.get("declared_quantity", 0)),
			"received_quantity": int(shipment.get("received_quantity", 0)),
			"loss_quantity": int(shipment.get("loss_quantity", 0)),
			"seal_id": String(shipment.get("seal_id", "")),
			"sender_id": StringName(shipment.get("sender_id", "")),
			"route_ids": shipment.get("route_ids", []).duplicate(),
			"due_period": world.current_period_index() + 1,
			"urgency": 5, "status": "pending", "generated_by": "regional_world"
		})
		return {"success": true, "message": "The cargo remains held at the destination. The dispatch will return to the docket next period."}
	return {"success": false, "message": "Unsupported dispatch assessment."}
