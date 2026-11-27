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

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := RegistryScript.new()
	registry.load_defaults()
	var world := WorldState.new()
	UrukSeederScript.seed_campaign(world, 32003200, true, registry)
	_check(registry.validate_world_references(), "All authored settlement, parent-place, and institution references resolve")
	_check(registry.all_places().size() == 20 and registry.all_institutions().size() == 5, "The registry loads authored regional geography and institution definitions")
	_check(world.places.get(&"north_bay", {}).get("parent", &"") == &"eanna_precinct" and world.places.get(&"eanna_precinct", {}).get("parent", &"") == &"uruk", "Work-area geography preserves its authored settlement hierarchy")
	var simulator := WorldSimulatorScript.new(registry)
	var network := RouteNetworkScript.new()
	var travel := TravelServiceScript.new()
	_check(world.current_location_id == &"uruk", "A new campaign begins in Uruk")
	_check(network.configure(world, registry.all_places(), registry.all_routes(), &"uruk_storehouse") and network.places.size() == 20 and network.routes.size() == 2, "The route network configures from the complete registered regional data set")
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
	var invalid_places: Array[PlaceDef] = []
	for place_value in network.places.values():
		var place_copy: PlaceDef = (place_value as PlaceDef).duplicate(true)
		if place_copy.id == &"uruk":
			place_copy.survey_position = Vector2.ZERO
		invalid_places.append(place_copy)
	var invalid_routes: Array[RouteDef] = []
	for route_value in network.routes.values():
		invalid_routes.append(route_value as RouteDef)
	var invalid_network := RouteNetworkScript.new()
	_check(invalid_network.configure(world, invalid_places, invalid_routes, &"uruk_storehouse"), "A route network can be constructed with a town missing its survey position")
	_check(not survey_map.configure(invalid_network, world, false) and survey_map.get_map_node_count() == 0, "The survey fails closed with a warning instead of building a graph from a zero-position town")
	_check(survey_map.configure(network, world, false), "The survey recovers cleanly when configured with valid authored positions")
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
	var river_route := network.get_route(&"river_uruk_nippur")
	_check(river_route != null and river_route.downstream_destination_id == &"uruk", "The river definition identifies Uruk as the downstream destination")
	var route_traveler := world.get_player()
	route_traveler.resources[&"silver"] = 0 # Route debt must not strand the player.
	var unpaid_route_fees_before := int(route_traveler.flags.get(&"unpaid_route_fees", 0))
	var upstream_periods := network.get_transit_periods(&"river_uruk_nippur", &"uruk", &"nippur")
	_check(upstream_periods == 2, "Uruk-to-Nippur river passage applies the one-period upstream penalty")
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
	_check(int(route_traveler.flags.get(&"unpaid_route_fees", 0)) == unpaid_route_fees_before + 1, "A broke traveler records the one-silver route debt but is not soft-locked")
	_check(world.current_location_id == &"nippur", "Arrival updates the persistent current location to Nippur")
	var nippur_save := SaveCodecScript.decode_save(SaveCodecScript.encode_world(world, {"survey_open": true}))
	var nippur_saved_world: WorldState = nippur_save.get("world") as WorldState
	_check(bool(nippur_save.get("success", false)) and nippur_saved_world != null and nippur_saved_world.current_location_id == &"nippur", "Save/load preserves the player's location while away in Nippur")
	_check(nippur_saved_world.periods_elapsed == world.periods_elapsed and world.periods_elapsed == 2, "Save/load preserves elapsed campaign periods independently of BCE calendar index")
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
	var eanna_records: Dictionary = eanna.get("stock_records", {})
	_check(bool(eanna_records.get("concealed_spoilage", false)) and String(eanna_records.get("barley_quality_declaration", "")) == "prime_seed_corn", "The return reveals Ur-Nanna falsified the barley quality record while the scribe was away")
	var ur_nanna := world.get_person(&"ur_nanna")
	var cover_up_memory_found := false
	for memory in ur_nanna.memory:
		if StringName(memory.get("memory_id", "")) == &"grain_clerk_cover_up":
			cover_up_memory_found = true
	_check(cover_up_memory_found, "Ur-Nanna's own chronicle records the cover-up decision made during the journey")
	var cover_up_memory_count := 0
	for memory in ur_nanna.memory:
		if StringName(memory.get("memory_id", "")) == &"grain_clerk_cover_up":
			cover_up_memory_count += 1
	_check(cover_up_memory_count == 1, "Repeated LimboAI evaluations do not duplicate an already-recorded cover-up")
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

	# Provincial dispatch acceptance: the aged requisition survives the trip, and
	# the player can open it only after the journey has actually elapsed.
	var dispatch_registry := RegistryScript.new()
	dispatch_registry.load_defaults()
	var dispatch_world := WorldState.new()
	UrukSeederScript.seed_campaign(dispatch_world, 32003200, true, dispatch_registry)
	var dispatch_actor := dispatch_world.get_player()
	dispatch_actor.resources[&"silver"] = 1
	var dispatch_form_id := dispatch_world.enqueue_form({
		"id": &"form_000005",
		"form_type": &"bailiff_requisition",
		"subject_id": &"umma",
		"place_id": &"umma",
		"institution_id": &"umma_canal_bailiff",
		"urgency": 3,
		"created_period": dispatch_world.current_period_index() - 5
	})
	var dispatch_simulator := WorldSimulatorScript.new(dispatch_registry)
	var dispatch_network := RouteNetworkScript.new()
	_check(dispatch_network.configure(dispatch_world, dispatch_registry.all_places(), dispatch_registry.all_routes(), &"uruk_storehouse"), "The Umma dispatch fixture configures the authored regional route graph")
	var dispatch_travel := TravelServiceScript.new()
	_check(dispatch_travel.configure(dispatch_network, dispatch_simulator), "The dispatch journey uses the authoritative travel service")
	var dispatch_board := AssignmentPipelineScript.generate_opportunities(dispatch_world, dispatch_actor)
	var dispatch_opportunity: Dictionary = {}
	for candidate in dispatch_board:
		if StringName(candidate.get("source_id", "")) == dispatch_form_id:
			dispatch_opportunity = candidate
			break
	_check(not dispatch_opportunity.is_empty() and bool(dispatch_opportunity.get("dispatch", false)), "The aged Umma requisition appears as a provincial dispatch in Uruk")
	_check(not AssignmentPipelineScript.begin(dispatch_world, dispatch_opportunity, dispatch_actor), "The provincial requisition cannot be opened before travel")
	var departure_index := dispatch_world.current_period_index()
	var departure_silver := int(dispatch_actor.resources.get(&"silver", 0))
	var journey := dispatch_travel.execute_journey(dispatch_world, dispatch_actor, &"umma")
	_check(bool(journey.get("success", false)) and int(journey.get("elapsed_periods", 0)) == 1, "Uruk-to-Umma journey completes in one simulation period")
	_check(dispatch_world.current_period_index() == departure_index + 1 and dispatch_world.current_location_id == &"umma", "The journey advances the calendar before setting the player's arrival location")
	_check(int(journey.get("fare_paid", 0)) == 1 and int(dispatch_actor.resources.get(&"silver", 0)) == departure_silver - 1, "The journey deducts the one-silver passage fare from the traveler")
	_check(String(journey.get("origin", "")) == "Uruk" and String(journey.get("destination", "")) == "Umma" and not String(journey.get("log_entry", "")).is_empty(), "The journey returns named endpoints and a chronicle-ready travel line")
	var arrived_board := AssignmentPipelineScript.generate_opportunities(dispatch_world, dispatch_actor)
	var arrived_dispatch: Dictionary = {}
	for candidate in arrived_board:
		if StringName(candidate.get("source_id", "")) == dispatch_form_id:
			arrived_dispatch = candidate
			break
	_check(not arrived_dispatch.is_empty() and not bool(arrived_dispatch.get("requires_travel", true)), "The Umma requisition becomes a local assignment after arrival")
	_check(AssignmentPipelineScript.begin(dispatch_world, arrived_dispatch, dispatch_actor), "The player can open form_000005 after disembarking in Umma")

	print("Nippur and Umma travel circuits: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append("FAIL: " + description)
