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
const RegionalSurveyMapScript = preload("res://components/regional_survey_map.gd")
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
	UrukSeederScript.seed_campaign(world, 32003200, true, registry)
	var simulator := WorldSimulatorScript.new(registry)
	var network := RouteNetworkScript.new()
	var travel := TravelServiceScript.new()
	_check(world.current_location_id == &"uruk", "A new campaign begins in Uruk")
	_check(network.configure(world, [URUK, NIPPUR, UMMA], [RIVER, LAND]), "The existing three-place route network configures for the campaign")
	_check(travel.configure(network, simulator), "TravelService configures with the route graph and authoritative world simulator")
	var initial_total_periods := world.total_periods
	var invalid_journey := travel.travel(world, &"river_uruk_nippur", &"umma")
	_check(not bool(invalid_journey.get("success", false)) and world.total_periods == initial_total_periods, "TravelService rejects a route that does not connect the current location without advancing time")
	network.set_route_disruption(&"river_uruk_nippur", &"closed")
	var closed_journey := travel.travel(world, &"river_uruk_nippur", &"nippur")
	_check(not bool(closed_journey.get("success", false)) and world.total_periods == initial_total_periods, "TravelService refuses a closed route without partially advancing the simulation")
	network.clear_route_disruption(&"river_uruk_nippur")
	var survey_map: Variant = RegionalSurveyMapScript.new()
	root.add_child(survey_map)
	_check(survey_map.configure(network, world, false), "The Worldmap Builder survey opens against the authoritative route graph")
	await process_frame
	_check(survey_map.get_map_node_count() == 3 and survey_map.get_map_connection_count() == 2, "The survey renders exactly three authored settlements and two route connections")
	var journey_results: Array[Dictionary] = []
	survey_map.travel_requested.connect(func(route_id: StringName, destination_id: StringName) -> void:
		journey_results.append(travel.travel(world, route_id, destination_id))
	)

	var baseline_barley := world.get_resource(&"barley", "institution", "", &"eanna_household")
	_check(baseline_barley > 0 and world.has_active_hazard(&"north_bay", &"roof_leak"), "Baseline Eanna barley stores and active North-Bay leak are present")
	_check(world.year == -3200 and world.period == 0, "Campaign begins at 3201 BCE, Month 1")

	_check(not survey_map.select_destination(&"nippur") and not survey_map.board_selected_route() and journey_results.is_empty(), "The survey displays routes but prevents departure while the current docket is active")
	_check(survey_map.configure(network, world, true), "The survey enables departure from a clear desk")
	await process_frame
	var upstream_periods := network.get_transit_periods(&"river_uruk_nippur", &"uruk", &"nippur")
	_check(upstream_periods == 2, "Uruk-to-Nippur river passage is two periods")
	var nippur_index: int = survey_map.map_nodes.get(&"nippur", -1)
	var nippur_data: Variant = survey_map.graph.get_node_data(nippur_index)
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	survey_map.graph.emit_signal("node_gui_input", map_click, nippur_index, nippur_data)
	_check(survey_map.get_selected_destination_id() == &"nippur" and survey_map.can_board_selected_route(), "A Worldmap Builder node click selects the upstream river destination")
	_check(survey_map.board_selected_route() and journey_results.size() == 1, "The survey's Board Barge action invokes the authoritative travel service")
	var upstream_result: Dictionary = journey_results[0]
	_check(bool(upstream_result.get("success", false)) and int(upstream_result.get("transit_periods", 0)) == upstream_periods, "TravelService executes the complete upstream journey")
	_check(world.current_location_id == &"nippur", "Arrival updates the persistent current location to Nippur")
	var nippur_save := SaveCodecScript.decode_save(SaveCodecScript.encode_world(world, {"survey_open": true}))
	var nippur_saved_world: WorldState = nippur_save.get("world") as WorldState
	_check(bool(nippur_save.get("success", false)) and nippur_saved_world != null and nippur_saved_world.current_location_id == &"nippur", "Save/load preserves the player's location while away in Nippur")
	_check(bool(nippur_save.get("session", {}).get("survey_open", false)), "Save/load preserves the cedar-desk survey's open state")
	_check(world.year == -3200 and world.period == 2, "Two transit periods arrive in Month 3 of 3201 BCE")
	var month_three := CalendarFormatterScript.format_date(registry.get_era(&"uruk_storehouse"), world.year, world.period)
	_check(month_three.contains("Month 03") and month_three.contains("3201 BCE"), "The desk calendar presents Month 3 and 3201 BCE")
	_check(world.get_hazard_total_lost(&"north_bay", &"roof_leak") == 2, "North-Bay loses exactly two barley to the leak during the upstream passage")
	var institution: Dictionary = world.institutions.get(&"nippur_shrine", {})
	_check(not institution.is_empty() and int(institution.get("stockpiles", {}).get(&"offerings", 0)) == 24, "Nippur's shrine offering ledger is available on arrival")

	var player := world.get_player()
	var local_opportunities := AssignmentPipelineScript.generate_opportunities(world, player)
	var opportunity: Dictionary = {}
	for candidate in local_opportunities:
		if StringName(candidate.get("source_id", "")) == &"nippur_shrine" and StringName(candidate.get("kind", "")) == &"ledger":
			opportunity = candidate
			break
	_check(not opportunity.is_empty(), "The location-aware assignment pipeline generates Nippur shrine ledger work from local world data")
	for local_opportunity in local_opportunities:
		_check(StringName(local_opportunity.get("source_id", "")) != &"roof_leak" and not local_opportunity.get("source_data", {}).has("npc_evidence"), "Uruk-only hazards and grain dockets do not leak onto Nippur's local board")
	_check(String(opportunity.get("title", "")) == "Audit Nippur Shrine Offerings", "Nippur's assignment title comes from its InstitutionDef resource")

	var audit_id := StringName(opportunity.id)
	_check(AssignmentPipelineScript.begin(world, opportunity, player), "The Nippur local audit opens through the existing assignment lifecycle")
	var written := AssignmentPipelineScript.perform_action(world, player, audit_id, &"examine_records")
	var reconciled := AssignmentPipelineScript.perform_action(world, player, audit_id, &"reconcile_accounts")
	_check(bool(written.get("success", false)) and bool(reconciled.get("success", false)), "The player can examine the offering register and reconcile its accounts")
	var assessment := AssignmentPipelineScript.resolve(world, player, audit_id, &"record")
	_check(bool(assessment.get("success", false)) and String(AssignmentPipelineScript.get_record(world, audit_id).get("status", "")) == "completed", "The Nippur offering audit can be completed and sealed")

	var downstream_periods := network.get_transit_periods(&"river_uruk_nippur", &"nippur", &"uruk")
	_check(downstream_periods == 1, "Nippur-to-Uruk downstream river passage is one period")
	_check(survey_map.configure(network, world), "The survey rebuilds from the new current location after arrival")
	await process_frame
	var uruk_index: int = survey_map.map_nodes.get(&"uruk", -1)
	var uruk_data: Variant = survey_map.graph.get_node_data(uruk_index)
	survey_map.graph.emit_signal("node_gui_input", map_click, uruk_index, uruk_data)
	_check(survey_map.get_selected_destination_id() == &"uruk" and survey_map.can_board_selected_route(), "The return journey is selectable from the Nippur survey")
	_check(survey_map.board_selected_route() and journey_results.size() == 2, "The survey's return action invokes TravelService")
	var downstream_result: Dictionary = journey_results[1]
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
	_check(StringName(last_agenda.get("intent_id", "")) == &"intent_hide_spoilage", "Ur-Nanna's LimboAI tree chooses the seeded concealment action during the journey")
	var eanna_records: Dictionary = eanna.get("stock_records", {})
	_check(bool(eanna_records.get("concealed_spoilage", false)) and String(eanna_records.get("barley_quality_declaration", "")) == "prime_seed_corn", "The return reveals Ur-Nanna falsified the barley quality record while the scribe was away")
	var return_opportunities := AssignmentPipelineScript.generate_opportunities(world, world.get_player())
	var returned_grain_docket := false
	for return_opportunity in return_opportunities:
		var source_data: Dictionary = return_opportunity.get("source_data", {})
		if source_data.has("npc_evidence"):
			returned_grain_docket = true
			_check(String(return_opportunity.get("title", "")).contains("Contradictory"), "The return docket identifies Ur-Nanna's contradictory grain records")
	_check(returned_grain_docket, "The player's return exposes the grain clerk's work generated during the absence")

	survey_map.queue_free()
	var encoded := SaveCodecScript.encode_world(world, {"survey_open": true})
	var decoded := SaveCodecScript.decode_save(encoded)
	var restored: WorldState = decoded.get("world") as WorldState
	_check(bool(decoded.get("success", false)) and restored != null and restored.current_location_id == &"uruk", "Save/load preserves the current settlement after the circuit")
	_check(bool(decoded.get("session", {}).get("survey_open", false)), "Save/load preserves survey visibility in the desk session")

	print("Nippur travel circuit: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
