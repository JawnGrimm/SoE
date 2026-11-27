extends SceneTree

var checks := 0
var failures: Array[String] = []

const RegistryScript = preload("res://systems/definition_registry.gd")
const UrukSeederScript = preload("res://systems/uruk_seeder.gd")
const WorldSimulatorScript = preload("res://systems/world_simulator.gd")
const RouteNetworkScript = preload("res://systems/route_network.gd")
const TravelServiceScript = preload("res://systems/travel_service.gd")
const AssignmentPipelineScript = preload("res://systems/assignment_pipeline.gd")
const SaveCodecScript = preload("res://systems/save_codec.gd")
const CalendarFormatterScript = preload("res://systems/calendar_formatter.gd")
const URUK: PlaceDef = preload("res://data/places/uruk.tres")
const NIPPUR: PlaceDef = preload("res://data/places/nippur.tres")
const UMMA: PlaceDef = preload("res://data/places/umma.tres")
const RIVER: RouteDef = preload("res://data/routes/river_uruk_nippur.tres")
const LAND: RouteDef = preload("res://data/routes/land_uruk_umma.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := RegistryScript.new()
	registry.load_defaults()
	var world := WorldState.new()
	UrukSeederScript.seed_campaign(world, 32003200)
	var simulator := WorldSimulatorScript.new(registry)
	var network := RouteNetworkScript.new()
	var travel := TravelServiceScript.new()
	_check(world.current_location_id == &"uruk", "A new campaign begins in Uruk")
	_check(network.configure(world, [URUK, NIPPUR, UMMA], [RIVER, LAND]), "The existing three-place route network configures for the campaign")
	_check(travel.configure(network, simulator), "TravelService configures with the route graph and authoritative world simulator")

	var baseline_barley := world.get_resource(&"barley", "institution", "", &"eanna_household")
	_check(baseline_barley > 0 and world.has_active_hazard(&"north_bay", &"roof_leak"), "Baseline Eanna barley stores and active North-Bay leak are present")
	_check(world.year == -3200 and world.period == 0, "Campaign begins at 3201 BCE, Month 1")

	var upstream_periods := network.get_transit_periods(&"river_uruk_nippur", &"uruk", &"nippur")
	_check(upstream_periods == 2, "Uruk-to-Nippur river passage is two periods")
	var upstream_result := travel.travel(world, &"river_uruk_nippur", &"nippur")
	_check(bool(upstream_result.get("success", false)) and int(upstream_result.get("transit_periods", 0)) == upstream_periods, "TravelService executes the complete upstream journey")
	_check(world.current_location_id == &"nippur", "Arrival updates the persistent current location to Nippur")
	_check(world.year == -3200 and world.period == 2, "Two transit periods arrive in Month 3 of 3201 BCE")
	var month_three := CalendarFormatterScript.format_date(registry.get_era(&"uruk_storehouse"), world.year, world.period)
	_check(month_three.contains("Month 03") and month_three.contains("3201 BCE"), "The desk calendar presents Month 3 and 3201 BCE")
	_check(world.get_hazard_total_lost(&"north_bay", &"roof_leak") == 2, "North-Bay loses exactly two barley to the leak during the upstream passage")
	var institution: Dictionary = world.institutions.get(&"nippur_shrine", {})
	_check(not institution.is_empty() and int(institution.get("stockpiles", {}).get(&"offerings", 0)) == 24, "Nippur's shrine offering ledger is available on arrival")

	var opportunity := {
		"id": &"nippur_shrine_offerings_audit",
		"kind": &"ledger",
		"source_id": &"nippur_shrine",
		"title": "Audit Nippur Shrine Offerings",
		"summary": "Reconcile the shrine's offering register against its current stores.",
		"employer_id": &"",
		"source_data": {
			"institution_id": &"nippur_shrine",
			"place_id": &"nippur",
			"member_count": 0,
			"activity_count": int(institution.get("activity_count", 0))
		}
	}
	var player := world.get_player()
	var audit_id := StringName(opportunity.id)
	_check(AssignmentPipelineScript.begin(world, opportunity, player), "The Nippur local audit opens through the existing assignment lifecycle")
	var written := AssignmentPipelineScript.perform_action(world, player, audit_id, &"examine_records")
	var reconciled := AssignmentPipelineScript.perform_action(world, player, audit_id, &"reconcile_accounts")
	_check(bool(written.get("success", false)) and bool(reconciled.get("success", false)), "The player can examine the offering register and reconcile its accounts")
	var assessment := AssignmentPipelineScript.resolve(world, player, audit_id, &"record")
	_check(bool(assessment.get("success", false)) and String(AssignmentPipelineScript.get_record(world, audit_id).get("status", "")) == "completed", "The Nippur offering audit can be completed and sealed")

	var downstream_periods := network.get_transit_periods(&"river_uruk_nippur", &"nippur", &"uruk")
	_check(downstream_periods == 1, "Nippur-to-Uruk downstream river passage is one period")
	var downstream_result := travel.travel(world, &"river_uruk_nippur", &"uruk")
	_check(bool(downstream_result.get("success", false)) and int(downstream_result.get("transit_periods", 0)) == downstream_periods, "TravelService executes the complete downstream journey")
	_check(world.current_location_id == &"uruk", "Return arrival restores the current location to Uruk")
	_check(world.year == -3200 and world.period == 3, "The return passage arrives in Month 4 of 3201 BCE")
	var month_four := CalendarFormatterScript.format_date(registry.get_era(&"uruk_storehouse"), world.year, world.period)
	_check(month_four.contains("Month 04") and month_four.contains("3201 BCE"), "The desk calendar presents Month 4 and 3201 BCE")
	_check(world.get_hazard_total_lost(&"north_bay", &"roof_leak") == 3, "North-Bay has lost exactly three barley after the complete circuit")
	var eanna: Dictionary = world.institutions.get(&"eanna_household", {})
	_check(int(eanna.get("agenda_evaluation_count", 0)) == 3, "Ur-Nanna's autonomous agenda evaluates once per transit period")
	var last_agenda: Dictionary = eanna.get("last_grain_clerk_agenda", {})
	_check(not last_agenda.is_empty(), "Ur-Nanna records an autonomous agenda decision while the player is away")

	var encoded := SaveCodecScript.encode_world(world)
	var decoded := SaveCodecScript.decode_save(encoded)
	var restored: WorldState = decoded.get("world") as WorldState
	_check(bool(decoded.get("success", false)) and restored != null and restored.current_location_id == &"uruk", "Save/load preserves the current settlement after the circuit")

	print("Nippur travel circuit: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
