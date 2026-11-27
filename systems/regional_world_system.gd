class_name RegionalWorldSystem
extends RefCounted
## Advances regional routes, shipments, and player travel independently of assignments.

const ROUTE_FOLDER := "res://data/routes"


static func ensure_regional_world(world: WorldState) -> void:
	if world == null:
		return
	if world.routes.is_empty():
		seed_routes(world)
	var place_paths: Array[String] = []
	_collect_tres("res://data/places", place_paths)
	place_paths.sort()
	for place_path in place_paths:
		var definition := ResourceLoader.load(place_path) as PlaceDef
		if definition == null or not definition.is_valid():
			continue
		var place: Dictionary = world.places.get(definition.id, {})
		if place.is_empty():
			place = {
				"name": definition.display_name, "kind": definition.place_type,
				"region": definition.region, "political_relation": definition.political_relation,
				"exports": definition.exports.duplicate(), "imports": definition.imports.duplicate(),
				"connected_to": definition.connected_to.duplicate(), "era_id": definition.era_id
			}
		else:
			if not place.has("name"):
				place["name"] = definition.display_name
			if not place.has("kind"):
				place["kind"] = definition.place_type
			if not place.has("region"):
				place["region"] = definition.region
			if not place.has("political_relation"):
				place["political_relation"] = definition.political_relation
			if not place.has("exports"):
				place["exports"] = definition.exports.duplicate()
			if not place.has("imports"):
				place["imports"] = definition.imports.duplicate()
			if not place.has("connected_to"):
				place["connected_to"] = definition.connected_to.duplicate()
			if not place.has("era_id"):
				place["era_id"] = definition.era_id
		world.places[definition.id] = place
	if world.institutions.has(&"eanna_household"):
		var eanna_institution: Dictionary = world.institutions[&"eanna_household"]
		var eanna_stock: Dictionary = eanna_institution.get("stockpiles", {})
		if not eanna_stock.has(&"bread"):
			eanna_stock[&"bread"] = 40
		if not eanna_stock.has(&"beer"):
			eanna_stock[&"beer"] = 20
		eanna_institution["stockpiles"] = eanna_stock
		world.institutions[&"eanna_household"] = eanna_institution
	if not world.institutions.has(&"habuba_trade_post"):
		var habuba_place: Dictionary = world.places.get(&"habuba_kabira", {})
		var habuba_exports: Array = habuba_place.get("exports", [&"timber", &"limestone"])
		var habuba_stock: Dictionary = {}
		for commodity in habuba_exports:
			habuba_stock[StringName(commodity)] = 24
		habuba_stock[&"beer"] = 12
		habuba_stock[&"silver"] = 24
		var habuba_members: Array[StringName] = []
		if world.people.has(&"enki_ili"):
			habuba_members.append(&"enki_ili")
			world.people[&"enki_ili"].current_location_id = &"habuba_kabira"
		world.institutions[&"habuba_trade_post"] = {
			"name": "Habuba Kabira Trade Enclave", "kind": &"trade_enclave",
			"place_id": &"habuba_kabira", "members": habuba_members,
			"interests": habuba_exports.duplicate(), "stockpiles": habuba_stock,
			"activity_count": 2, "resource_pressure": 0
		}
		var habuba_record: Dictionary = world.places.get(&"habuba_kabira", {})
		habuba_record["regional_institution_id"] = &"habuba_trade_post"
		if not habuba_members.is_empty():
			habuba_record["regional_agent_id"] = habuba_members[0]
		world.places[&"habuba_kabira"] = habuba_record
	seed_regional_institutions(world)
	var player := world.get_player()
	if player != null and player.current_location_id == &"":
		player.current_location_id = &"uruk"

static func seed_regional_institutions(world: WorldState) -> int:
	if world == null:
		return 0
	var created := 0
	for place_id_variant in world.places.keys():
		var place_id := StringName(place_id_variant)
		if place_id == &"uruk":
			continue
		var place: Dictionary = world.places[place_id]
		if String(place.get("region", "")) == "uruk" or place.has("parent"):
			continue
		var connections: Array = place.get("connected_to", [])
		if connections.is_empty():
			continue
		var institution_id := StringName(place.get("regional_institution_id", ""))
		var institution: Dictionary = {}
		if institution_id != &"" and world.institutions.has(institution_id):
			institution = world.institutions[institution_id]
		else:
			for candidate_id in world.institutions.keys():
				var candidate: Dictionary = world.institutions[candidate_id]
				if StringName(candidate.get("place_id", "")) == place_id and StringName(candidate.get("kind", "")) in [&"trade_enclave", &"regional_trade_post"]:
					institution_id = StringName(candidate_id)
					institution = candidate
					break
		if institution.is_empty():
			institution_id = StringName("trade_post_%s" % String(place_id))
			var agent_id := StringName("regional_factor_%s" % String(place_id))
			var agent := PersonEntity.new()
			agent.id = agent_id
			agent.display_name = "%s Trade Factor" % String(place.get("name", place_id))
			agent.office_id = &"trade_factor"
			agent.current_location_id = place_id
			agent.skills.levels[&"literacy"] = world.rng_people.randi_range(1, 3)
			agent.skills.levels[&"arithmetic"] = world.rng_people.randi_range(1, 3)
			agent.skills.levels[&"rhetoric"] = world.rng_people.randi_range(1, 3)
			agent.skills.levels[&"intrigue"] = world.rng_people.randi_range(1, 3)
			agent.skills.levels[&"stewardship"] = world.rng_people.randi_range(1, 3)
			agent.resources[&"silver"] = world.rng_people.randi_range(1, 8)
			world.people[agent_id] = agent
			var exports: Array = place.get("exports", [])
			if exports.is_empty():
				exports = [&"timber", &"copper"]
			var stockpiles: Dictionary = {}
			for commodity in exports:
				stockpiles[StringName(commodity)] = world.rng_sim.randi_range(12, 48)
			stockpiles[&"beer"] = maxi(8, int(stockpiles.get(&"beer", 0)))
			stockpiles[&"bread"] = maxi(12, int(stockpiles.get(&"bread", 0)))
			stockpiles[&"silver"] = maxi(8, int(stockpiles.get(&"silver", 0)))
			institution = {
				"name": "%s Trade House" % String(place.get("name", place_id)),
				"kind": &"regional_trade_post", "place_id": place_id,
				"members": [agent_id], "interests": exports.duplicate(),
				"stockpiles": stockpiles,
				"activity_count": world.rng_sim.randi_range(1, 4),
				"resource_pressure": world.rng_sim.randi_range(0, 2)
			}
			world.institutions[institution_id] = institution
			place["regional_agent_id"] = agent_id
			created += 1
		else:
			var members: Array = institution.get("members", [])
			var existing_agent_id := StringName(members[0]) if not members.is_empty() else &""
			if existing_agent_id != &"" and world.people.has(existing_agent_id):
				var existing_agent: PersonEntity = world.people[existing_agent_id]
				existing_agent.current_location_id = place_id
				place["regional_agent_id"] = existing_agent_id
		place["regional_institution_id"] = institution_id
		world.places[place_id] = place
	return created

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
			"bread_required": route_path_periods(world, route_ids),
			"beer_required": int(ceil(float(route_path_periods(world, route_ids)) / 3.0)),
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
		"carrier_id": StringName(details.get("carrier_id", world.places.get(destination_id, {}).get("regional_agent_id", &"enlil_kisu"))),
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
		shipment["loss_route_id"] = StringName(route_ids[route_index])
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
		"institution_id": StringName(shipment.get("destination_institution_id", "")),
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
		"carrier_id": StringName(shipment.get("carrier_id", "")),
		"loss_route_id": StringName(shipment.get("loss_route_id", "")),
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
	var travel_periods := route_path_periods(world, route_ids)
	if route_ids.is_empty():
		actor.current_location_id = destination_id
		world.player_travel = {"actor_id": actor.id, "origin_id": origin_id, "destination_id": destination_id, "route_ids": [], "route_index": 0, "remaining_periods": 0, "departure_period": world.current_period_index(), "arrival_period": world.current_period_index(), "status": "arrived", "incidents": [], "rations_consumed": {"bread": 0, "beer": 0}, "silver_spent": 0}
		return {"success": true, "route_ids": [], "travel_periods": 0, "bread_required": 0, "beer_required": 0, "silver_spent": 0}
	var bread_required := travel_periods
	var beer_required := int(ceil(float(travel_periods) / 3.0))
	var bread_shortage := maxi(0, bread_required - int(actor.resources.get(&"bread", 0)))
	var beer_shortage := maxi(0, beer_required - int(actor.resources.get(&"beer", 0)))
	var local_institution_id := &"eanna_household" if origin_id == &"uruk" else StringName(world.places.get(origin_id, {}).get("regional_institution_id", ""))
	if (bread_shortage > 0 or beer_shortage > 0) and (local_institution_id == &"" or not world.institutions.has(local_institution_id)):
		return {"success": false, "error": "There is no local institution able to provision this journey."}
	var local_institution: Dictionary = world.institutions.get(local_institution_id, {})
	var local_stock: Dictionary = local_institution.get("stockpiles", {})
	if int(local_stock.get(&"bread", 0)) < bread_shortage or int(local_stock.get(&"beer", 0)) < beer_shortage:
		return {"success": false, "error": "The local stores cannot supply enough bread and beer for this route."}
	var silver_cost := bread_shortage + beer_shortage * 2
	if int(actor.resources.get(&"silver", 0)) < silver_cost:
		return {"success": false, "error": "The journey requires %d silver to purchase its missing rations." % silver_cost}
	if bread_shortage > 0 and not world.modify_resource(&"bread", -bread_shortage, "institution", "", local_institution_id):
		return {"success": false, "error": "Bread could not be issued from local stores."}
	if beer_shortage > 0 and not world.modify_resource(&"beer", -beer_shortage, "institution", "", local_institution_id):
		if bread_shortage > 0:
			world.modify_resource(&"bread", bread_shortage, "institution", "", local_institution_id)
		return {"success": false, "error": "Beer could not be issued from local stores."}
	actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) - silver_cost
	actor.resources[&"bread"] = int(actor.resources.get(&"bread", 0)) + bread_shortage
	actor.resources[&"beer"] = int(actor.resources.get(&"beer", 0)) + beer_shortage
	world.player_travel = {
		"actor_id": actor.id, "origin_id": origin_id, "destination_id": destination_id,
		"route_ids": route_ids, "route_index": 0,
		"remaining_periods": int(world.routes.get(route_ids[0], {}).get("travel_periods", 1)),
		"departure_period": world.current_period_index(),
		"status": "in_transit", "incidents": [],
		"bread_budget": bread_required, "beer_budget": beer_required,
		"rations_consumed": {"bread": 0, "beer": 0}, "silver_spent": silver_cost
	}
	return {"success": true, "route_ids": route_ids, "travel_periods": travel_periods, "bread_required": bread_required, "beer_required": beer_required, "silver_spent": silver_cost}

static func _advance_player_travel(world: WorldState) -> void:
	if String(world.player_travel.get("status", "")) != "in_transit":
		return
	var travel: Dictionary = world.player_travel
	var actor := world.get_person(StringName(travel.get("actor_id", "")))
	var remaining := int(travel.get("remaining_periods", 1)) - 1
	travel["remaining_periods"] = remaining
	if actor != null:
		var bread := int(actor.resources.get(&"bread", 0))
		if bread <= 0:
			var shortage := {"kind": "ration_shortage", "period": world.current_period_index(), "route_id": StringName(travel.get("route_ids", [])[int(travel.get("route_index", 0))]) if not travel.get("route_ids", []).is_empty() else &""}
			var incidents: Array = travel.get("incidents", [])
			incidents.append(shortage)
			travel["incidents"] = incidents
			world.travel_history.append(shortage)
			travel["remaining_periods"] = int(travel.get("remaining_periods", 0)) + 1
			world.player_travel = travel
			return
		actor.resources[&"bread"] = bread - 1
		var consumed: Dictionary = travel.get("rations_consumed", {"bread": 0, "beer": 0})
		consumed["bread"] = int(consumed.get("bread", 0)) + 1
		var elapsed := world.current_period_index() - int(travel.get("departure_period", world.current_period_index()))
		if elapsed == 1 or (elapsed > 1 and (elapsed - 1) % 3 == 0):
			var beer := int(actor.resources.get(&"beer", 0))
			if beer > 0:
				actor.resources[&"beer"] = beer - 1
				consumed["beer"] = int(consumed.get("beer", 0)) + 1
			else:
				var beer_incident := {"kind": "beer_shortage", "period": world.current_period_index(), "route_id": &""}
				var beer_incidents: Array = travel.get("incidents", [])
				beer_incidents.append(beer_incident)
				travel["incidents"] = beer_incidents
				world.travel_history.append(beer_incident)
		travel["rations_consumed"] = consumed
	if remaining > 0:
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

static func simulate_regional_flows(world: WorldState) -> void:
	if world == null:
		return
	var place_ids: Array = world.places.keys()
	place_ids.sort()
	for place_id_variant in place_ids:
		var origin_id := StringName(place_id_variant)
		var place: Dictionary = world.places[origin_id]
		var institution_id := &"eanna_household" if origin_id == &"uruk" else StringName(place.get("regional_institution_id", ""))
		if institution_id == &"" or not world.institutions.has(institution_id):
			continue
		var institution: Dictionary = world.institutions[institution_id]
		var stockpiles: Dictionary = institution.get("stockpiles", {})
		var exports: Array = place.get("exports", [])
		var activity := int(institution.get("activity_count", 1))
		var flow_chance := clampf(0.08 + float(activity) * 0.04, 0.08, 0.28)
		for commodity_variant in exports:
			var commodity_id := StringName(commodity_variant)
			var available := int(stockpiles.get(commodity_id, 0))
			if available < 4:
				continue
			var destination_id := _find_trade_destination(world, origin_id, commodity_id)
			if destination_id == &"" or _has_open_shipment(world, origin_id, destination_id, commodity_id):
				continue
			if world.rng_sim.randf() >= flow_chance:
				break
			var quantity := world.rng_sim.randi_range(4, mini(12, available))
			if not world.modify_resource(commodity_id, -quantity, "institution", "", institution_id):
				break
			var destination_institution_id := &"eanna_household" if destination_id == &"uruk" else StringName(world.places.get(destination_id, {}).get("regional_institution_id", ""))
			var sender_id := StringName(place.get("regional_agent_id", &"geme_inana"))
			if origin_id == &"uruk":
				sender_id = &"geme_inana"
			var launched := launch_shipment(world, {
				"origin_id": origin_id, "destination_id": destination_id,
				"commodity_id": commodity_id, "quantity": quantity,
				"seal_id": "%s_trade_seal_%d" % [String(origin_id), world.current_period_index()],
				"sender_id": sender_id, "destination_institution_id": destination_institution_id
			})
			if not bool(launched.get("success", false)):
				world.modify_resource(commodity_id, quantity, "institution", "", institution_id)
			break

static func _find_trade_destination(world: WorldState, origin_id: StringName, commodity_id: StringName) -> StringName:
	var selected_place := &""
	var shortest := 2147483647
	for place_id_variant in world.places.keys():
		var place_id := StringName(place_id_variant)
		if place_id == origin_id:
			continue
		var place: Dictionary = world.places[place_id]
		var imports: Array = place.get("imports", [])
		if not imports.has(commodity_id):
			continue
		var institution_id := &"eanna_household" if place_id == &"uruk" else StringName(place.get("regional_institution_id", ""))
		if institution_id == &"" or not world.institutions.has(institution_id):
			continue
		var route_ids := find_route_path(world, origin_id, place_id)
		if route_ids.is_empty():
			continue
		var duration := route_path_periods(world, route_ids)
		if duration < shortest:
			shortest = duration
			selected_place = place_id
	return selected_place

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
			"carrier_id": StringName(shipment.get("carrier_id", "")),
			"loss_route_id": StringName(shipment.get("loss_route_id", "")),
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
