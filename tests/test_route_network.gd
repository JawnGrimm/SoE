extends SceneTree

var checks := 0
var failures: Array[String] = []

const SaveCodecScript = preload("res://systems/save_codec.gd")
const URUK: PlaceDef = preload("res://data/places/uruk.tres")
const NIPPUR: PlaceDef = preload("res://data/places/nippur.tres")
const UMMA: PlaceDef = preload("res://data/places/umma.tres")
const RIVER: RouteDef = preload("res://data/routes/river_uruk_nippur.tres")
const LAND: RouteDef = preload("res://data/routes/land_uruk_umma.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := WorldState.new()
	world.year = -3200
	world.period = 0
	var network := RouteNetwork.new()
	_check(network.configure(world, [URUK, NIPPUR, UMMA], [RIVER, LAND]) and network.places.size() == 3 and network.routes.size() == 2 and not network.routes.has(&"river_nippur_umma"), "Network is exactly three locations and two intended arteries")
	_check(network.get_transit_periods(RIVER.id, &"nippur", &"uruk") == 1, "Downstream Nippur-to-Uruk journey takes one period")
	_check(network.get_transit_periods(RIVER.id, &"uruk", &"nippur") == 2, "Upstream Uruk-to-Nippur journey takes two periods")
	_check(network.get_transit_periods(LAND.id, &"uruk", &"umma") == 1, "Baseline land journey takes one period")
	_check(network.get_transit_periods(RIVER.id, &"nippur", &"umma") == -1, "Non-adjacent travel is rejected")
	var now := world.total_periods
	_check(network.set_route_disruption(RIVER.id, &"disrupted", now + 2, 1) and world.routes.has(RIVER.id) and network.get_route_status(RIVER.id) == &"disrupted" and network.get_transit_periods(RIVER.id, &"nippur", &"uruk") == 2, "Timed disruption is stored in WorldState and affects route status and transit")
	world.advance_period()
	_check(network.get_route_status(RIVER.id) == &"disrupted", "Disruption remains active before its expiry period")
	world.advance_period()
	_check(network.get_route_status(RIVER.id) == &"open" and not world.routes.has(RIVER.id), "Disruption expires on its exact second-period deadline")
	_check(network.set_route_disruption(LAND.id, &"closed") and network.get_transit_periods(LAND.id, &"uruk", &"umma") == -1, "Closed route rejects travel")
	_check(network.clear_route_disruption(LAND.id) and network.get_route_status(LAND.id) == &"open" and network.get_transit_periods(LAND.id, &"uruk", &"umma") == 1, "Clearing disruption restores the original route")
	var player := PersonEntity.new()
	player.id = &"route_test_player"
	world.set_player(player)
	network.set_route_disruption(LAND.id, &"disrupted", world.total_periods + 3, 1)
	var encoded := SaveCodecScript.encode_world(world)
	var decoded := SaveCodecScript.decode_save(encoded)
	var restored: WorldState = decoded.get("world") as WorldState
	_check(bool(decoded.get("success", false)) and restored != null and restored.routes.has(LAND.id) and StringName(restored.routes[LAND.id].get("status", "")) == &"disrupted" and int(restored.routes[LAND.id].get("expiry_period", 0)) == world.total_periods + 3 and int(restored.routes[LAND.id].get("transit_penalty_periods", 0)) == 1 and RIVER.base_transit_periods == 1 and RIVER.downstream_destination_id == &"uruk", "Save/load preserves runtime disruption without mutating shared route definitions")
	print("Route network: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
