extends SceneTree

var checks := 0
var failures: Array[String] = []

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
	_check(network.configure(world, [URUK, NIPPUR, UMMA], [RIVER, LAND]), "Three-location graph configures")
	_check(network.places.size() == 3 and network.routes.size() == 2, "Graph contains exactly three places and two routes")
	_check(network.routes.has(&"river_uruk_nippur") and network.routes.has(&"land_uruk_umma") and not network.routes.has(&"river_nippur_umma"), "Graph has only the two intended arteries")
	_check(network.get_transit_periods(RIVER.id, &"nippur", &"uruk") == 1, "Downstream Nippur-to-Uruk grain journey takes one period")
	_check(network.get_transit_periods(RIVER.id, &"uruk", &"nippur") == 2, "Upstream Uruk-to-Nippur journey takes two periods")
	_check(network.get_transit_periods(LAND.id, &"uruk", &"umma") == 1, "Baseline land journey takes one period")
	_check(network.get_transit_periods(RIVER.id, &"nippur", &"umma") == -1, "Non-adjacent travel is rejected")
	var now := world.total_periods
	_check(network.set_route_disruption(RIVER.id, &"disrupted", now + 2, 1) and world.routes.has(RIVER.id), "Timed disruption is stored in WorldState.routes")
	_check(network.get_route_status(RIVER.id) == &"disrupted" and network.get_transit_periods(RIVER.id, &"nippur", &"uruk") == 2, "Disruption changes route status and transit estimate")
	world.advance_period()
	_check(network.get_route_status(RIVER.id) == &"disrupted", "Disruption remains active before expiry")
	world.advance_period()
	_check(network.get_route_status(RIVER.id) == &"open" and not world.routes.has(RIVER.id), "Disruption expires on its exact expiry period")
	_check(network.get_route_status(LAND.id) == &"open" and network.get_transit_periods(LAND.id, &"uruk", &"umma") == 1, "Unaffected land route remains available")
	_check(network.set_route_disruption(LAND.id, &"closed") and network.get_transit_periods(LAND.id, &"uruk", &"umma") == -1, "Closed route rejects travel")
	_check(RIVER.base_transit_periods == 1 and RIVER.downstream_destination_id == &"uruk", "Runtime disruption never mutates shared route definitions")
	print("Route network: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
