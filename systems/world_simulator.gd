class_name WorldSimulator
extends RefCounted
## Autonomous period simulation for the Uruk campaign.
## WorldState owns the calendar/deadline/hazard step; this class owns ongoing
## economy, institutional activity, and condition-driven docket generation.

const MIN_STOCK := 0
const FORM_COOLDOWN_PERIODS := 3
const GrainClerkAgendaTree = preload("res://data/behavior_trees/bt_grain_clerk_agenda.tres")
const GrainClerkAgentScript = preload("res://systems/ai/grain_clerk_agent.gd")

var definition_registry: DefinitionRegistry

func _init(registry: DefinitionRegistry = null) -> void:
	definition_registry = registry

func advance_period(world: WorldState) -> void:
	if world == null:
		return
	world.advance_period()
	_deliver_grain_clerk_dockets(world)
	_simulate_economy(world)
	_simulate_institutions(world)
	_simulate_epics(world)
	_simulate_people(world)
	_tick_grain_clerk_agenda(world)
	_generate_forms(world)

func _deliver_grain_clerk_dockets(world: WorldState) -> void:
	var institution: Dictionary = world.institutions.get(&"eanna_household", {})
	if institution.is_empty():
		return
	var queue: Array = institution.get("npc_docket_queue", []).duplicate(true)
	if queue.is_empty():
		return
	var remaining: Array = []
	var now := world.current_period_index()
	for docket in queue:
		var npc_evidence: Dictionary = docket.get("npc_evidence", {})
		if int(docket.get("due_period", now + 1)) > now:
			remaining.append(docket)
			continue
		var form_type := StringName(docket.get("form_type", &"held_barley"))
		var subject_id := StringName(docket.get("subject_id", &"north_bay"))
		world.enqueue_form({
			"id": StringName("ur_nanna_grain_docket_%d" % now),
			"form_type": form_type,
			"subject_id": subject_id,
			"urgency": int(docket.get("urgency", 4)),
			"year": world.year,
			"generated_by": &"ur_nanna",
			"generation_reason": &"autonomous_grain_clerk_action",
			"npc_intent_id": StringName(docket.get("intent_id", "")),
			"npc_evidence": npc_evidence.duplicate(true),
		})
	institution["npc_docket_queue"] = remaining
	world.institutions[&"eanna_household"] = institution

func _tick_grain_clerk_agenda(world: WorldState) -> void:
	var clerk := world.get_person(&"ur_nanna")
	if clerk == null or clerk.office_id != &"grain_clerk":
		return
	var institution: Dictionary = world.institutions.get(&"eanna_household", {})
	institution["agenda_evaluation_count"] = int(institution.get("agenda_evaluation_count", 0)) + 1
	world.institutions[&"eanna_household"] = institution
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		push_warning("WorldSimulator: cannot tick Ur-Nanna's LimboAI agenda without a SceneTree")
		return
	var scene_tree := main_loop as SceneTree
	var agent: Node = GrainClerkAgentScript.new()
	agent.set("world", world)
	agent.set("clerk", clerk)
	scene_tree.root.add_child(agent)
	var bt_player := BTPlayer.new()
	bt_player.set_active(false)
	bt_player.set_update_mode(BTPlayer.MANUAL) # Exactly one explicit update per world period.
	bt_player.set_agent_node(NodePath(".."))
	bt_player.set_scene_root_hint(agent)
	bt_player.set_behavior_tree(GrainClerkAgendaTree)
	agent.add_child(bt_player)
	bt_player.set_active(true)
	bt_player.update(0.0)
	bt_player.set_active(false)
	agent.free()

func _get_definition_registry() -> DefinitionRegistry:
	if definition_registry != null:
		return definition_registry
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var registry_node := tree.root.get_node_or_null("Registry")
		if registry_node != null:
			var candidate: Variant = registry_node.get("defs")
			if candidate is DefinitionRegistry:
				definition_registry = candidate
	return definition_registry

func _simulate_epics(world: WorldState) -> void:
	var definitions := _get_definition_registry()
	if definitions == null:
		push_warning("WorldSimulator: cannot tick Epics without a DefinitionRegistry")
		return
	var current_era := definitions.get_era_for_year(world.year)
	for definition in definitions.all_epics():
		if definition.era_id != &"" and (current_era == null or current_era.id != definition.era_id):
			continue
		if not world.epics.has(definition.id):
			world.epics[definition.id] = {
				"active": true,
				"progress": world.get_resource(definition.progress_resource),
				"progress_resource": definition.progress_resource,
				"target": definition.target,
				"title": definition.title,
				"sponsor_institution": definition.sponsor_institution,
				"era_id": definition.era_id,
				"initial_stage": definition.initial_stage,
				"stage": definition.initial_stage,
				"completed": false,
				"review_pending": true,
				"review_stage": 0,
				"reviewed_stage": -1,
				"last_reviewed_period": -1,
				"scandal_flags": [],
				"history_notes": []
			}

	for epic_id in world.epics.keys():
		var definition := definitions.get_epic(StringName(epic_id))
		if definition == null:
			push_warning("WorldSimulator: active Epic '%s' has no registered EpicDef" % epic_id)
			continue
		var state: Dictionary = world.epics[epic_id]
		var era_matches := definition.era_id == &"" or (current_era != null and current_era.id == definition.era_id)
		state["active"] = era_matches
		state["progress_resource"] = definition.progress_resource
		state["target"] = definition.target
		state["title"] = definition.title
		state["sponsor_institution"] = definition.sponsor_institution
		state["era_id"] = definition.era_id
		state["initial_stage"] = definition.initial_stage
		if not era_matches:
			world.epics[epic_id] = state
			continue
		_simulate_epic(world, definition, state)
		var latest: Dictionary = world.epics.get(epic_id, state)
		world.ensure_epic_review_state(StringName(epic_id), definition)
		latest = world.epics.get(epic_id, latest)
		if bool(latest.get("completed", false)):
			latest["review_pending"] = false
		else:
			var progress := int(latest.get("progress", world.get_resource(definition.progress_resource)))
			var stage := world.get_epic_stage_index(progress, int(latest.get("target", definition.target)), definition)
			var reviewed_stage := int(latest.get("reviewed_stage", -1))
			if stage > reviewed_stage and not bool(latest.get("review_pending", false)):
				latest["review_pending"] = true
				latest["review_stage"] = stage
		world.epics[epic_id] = latest

func _simulate_epic(world: WorldState, definition: EpicDef, state: Dictionary) -> void:
	var resource_id := definition.progress_resource
	if resource_id == &"" or definition.target <= 0:
		push_warning("WorldSimulator: Epic '%s' has no valid progress resource or target" % definition.id)
		return
	var progress := clampi(world.get_resource(resource_id), 0, definition.target)
	if bool(state.get("completed", false)):
		state["progress"] = progress
		world.epics[definition.id] = state
		return

	var now := world.current_period_index()
	var institution: Dictionary = world.institutions.get(definition.sponsor_institution, {})
	var resources: Dictionary = institution.get("stockpiles", {})
	var labor := int(resources.get(&"labor", 0))
	var barley := int(resources.get(&"barley", 0))
	var disruption := false
	var recorded_scandals: Array = state.get("scandal_flags", [])
	for flag in definition.disruption_flags:
		if world.has_flag(flag, now):
			disruption = true
			if flag not in recorded_scandals:
				recorded_scandals.append(flag)
	state["scandal_flags"] = recorded_scandals

	var previous_progress := progress
	var note := ""
	var inundation := world.period >= definition.inundation_period_min and world.period <= definition.inundation_period_max
	var work_stalled := disruption or labor < definition.regression_labor_below or barley < definition.partial_barley
	if inundation and work_stalled:
		progress = maxi(0, progress - definition.regression_amount)
		if disruption:
			note = "Inundation silt reclaimed part of the cut during a crew disruption."
		elif labor < definition.regression_labor_below:
			note = "Inundation silt reclaimed part of the cut while labor was below minimum."
		else:
			note = "Inundation silt reclaimed part of the cut while barley rations were insufficient."
	elif disruption:
		note = "Epic crews stalled by an active disruption."
	elif labor < definition.regression_labor_below:
		note = "Work crews stood down below the minimum labor threshold."
	elif labor >= definition.strong_labor and barley >= definition.strong_barley:
		if world.modify_resource(&"barley", -definition.strong_barley_cost, "institution", "", definition.sponsor_institution):
			progress += definition.strong_progress
			note = "Crews advanced the Epic on full rations."
	elif labor >= definition.partial_labor and barley >= definition.partial_barley:
		if world.modify_resource(&"barley", -definition.partial_barley_cost, "institution", "", definition.sponsor_institution):
			progress += definition.partial_progress
			note = "Crews made partial Epic progress on reduced rations."
	else:
		note = "Epic work stalled for lack of labor or barley."

	progress = clampi(progress, 0, definition.target)
	var current_progress := world.get_resource(resource_id)
	if progress != current_progress:
		world.modify_resource(resource_id, progress - current_progress, "world")
	state["progress"] = progress
	state["stage"] = "completed" if progress >= definition.target else ("approaching_completion" if progress >= definition.target * 0.75 else ("cutting" if progress >= definition.target * 0.25 else definition.initial_stage))
	state["completed"] = progress >= definition.target
	if progress != previous_progress:
		var history: Array = state.get("history_notes", [])
		history.append({"year": world.year, "period": world.period, "from": previous_progress, "to": progress, "note": note})
		while history.size() > 32:
			history.pop_front()
		state["history_notes"] = history
	world.epics[definition.id] = state
	world.stockpiles[resource_id] = progress

func _simulate_economy(world: WorldState) -> void:
	var p := world.period
	# Household consumption is continuous. Resource shortages remain visible;
	# the simulation does not quietly create replacement stock.
	_change(world, &"barley", -8)
	_change(world, &"beer", -2)
	_change(world, &"dates", -1)
	_change(world, &"fish", -2)
	_change(world, &"textiles", -1)
	_change(world, &"labor", -4)
	# Labor is available workforce, replenished each period before demand.
	# Each active institution commits a unit; one baseline unit is covered by
	# the household's ordinary work rotation. Additional institutions draw down
	# the available pool rather than letting it accumulate to the cap.
	var active_institutions := 0
	for institution in world.institutions.values():
		var members: Array = institution.get("members", [])
		for member_id in members:
			var member := world.get_person(StringName(member_id))
			if member != null and member.office_id != &"":
				active_institutions += 1
				break
	_change(world, &"labor", 6)
	_change(world, &"labor", -maxi(0, active_institutions - 1))

	# Seasonal production varies with waterworks progress and the seeded sim stream.
	# Periods are Uruk's broad agricultural cycle, not a scripted event schedule.
	if p >= 4 and p <= 7:
		var canal_bonus := floori(float(_get_active_epic_progress(world)) / 20.0)
		_change(world, &"barley", world.rng_sim.randi_range(18, 34) + canal_bonus)
	if p == 5 or p == 6:
		_change(world, &"dates", world.rng_sim.randi_range(5, 11))
	if p >= 2 and p <= 9:
		_change(world, &"fish", world.rng_sim.randi_range(2, 5))
	if p >= 4 and p <= 7:
		_change(world, &"labor", -3) # field and canal labor peak during harvest
	if p == 0 or p == 8:
		_change(world, &"labor", 2) # seasonal workforce returns to the pool
	if p == 8:
		_change(world, &"wool", world.rng_sim.randi_range(3, 7))
	# Brewing converts a small amount of barley into beer. It is a production
	# chain, so shortages in barley also constrain beer output.
	if p == 3 or p == 7 or p == 10:
		var barley_available := world.get_resource(&"barley")
		var brew_input := mini(6, maxi(0, barley_available))
		if brew_input > 0:
			_change(world, &"barley", -brew_input)
			_change(world, &"beer", brew_input * 2)

func _simulate_institutions(world: WorldState) -> void:
	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var members: Array = institution.get("members", [])
		var active_members := 0
		for member_id in members:
			var person := world.get_person(StringName(member_id))
			if person != null and person.office_id != &"":
				active_members += 1
		var previous_pressure := int(institution.get("resource_pressure", 0))
		var pressure := 0
		if world.get_resource(&"barley") < 100:
			pressure += 2
		elif world.get_resource(&"barley") < 220:
			pressure += 1
		if world.get_resource(&"labor") < 8:
			pressure += 2
		elif world.get_resource(&"labor") < 16:
			pressure += 1
		institution["resource_pressure"] = pressure
		institution["active_members"] = active_members
		institution["last_simulated_period"] = world.current_period_index()
		institution["activity_count"] = int(institution.get("activity_count", 0)) + 1
		if pressure != previous_pressure:
			institution["pressure_changed_period"] = world.current_period_index()
		world.institutions[institution_id] = institution

func _simulate_people(world: WorldState) -> void:
	# People respond to actual institutional scarcity, not random opinion jitter.
	var grain_clerk := world.get_person(&"ur_nanna")
	var foreman := world.get_person(&"enlil_kisu")
	var senior := world.get_person(&"shuruppak_ilu")
	var player_id := world.player_id
	if player_id == &"" or world.get_player() == null:
		return
	var now := world.current_period_index()
	if grain_clerk != null and foreman != null:
		var labor := world.get_resource(&"labor")
		if labor < 8 and not world.has_flag(&"sim_labor_shortage_reaction", now):
			foreman.change_opinion(player_id, -1, "The storehouse labor pool fell below the crew's workable minimum", world.year)
			grain_clerk.change_opinion(player_id, -1, "Labor shortage increased pressure on the grain office", world.year)
			world.set_flag(&"sim_labor_shortage_reaction", now + 6)
		elif labor >= 24 and world.get_resource(&"barley") >= 220 and world.has_flag(&"sim_labor_shortage_reaction", now):
			foreman.change_opinion(player_id, 1, "The stores and labor pool recovered enough to support the crew", world.year)
			world.clear_flag(&"sim_labor_shortage_reaction")
	if senior != null and world.get_resource(&"barley") < 100 and not world.has_flag(&"sim_provisioning_reaction", now):
		senior.change_opinion(player_id, -1, "The archive's provisioning concerns reached the storehouse", world.year)
		world.set_flag(&"sim_provisioning_reaction", now + 6)

func _generate_forms(world: WorldState) -> void:
	var barley := world.get_resource(&"barley")
	var labor := world.get_resource(&"labor")
	var dates := world.get_resource(&"dates")
	var wool := world.get_resource(&"wool")
	var period := world.period
	var institution_activity := 0
	for institution in world.institutions.values():
		institution_activity += int(institution.get("activity_count", 0))

	# Surplus levy is harvest/stores accounting, not scarcity pressure.
	var harvest_or_stores := period >= 4 and period <= 11
	if barley >= 390 and harvest_or_stores and institution_activity > 0:
		_offer_if_ready(world, &"grain_levy", &"south_court_storehouse", 2, &"surplus_levy")
	elif barley <= 85:
		_offer_if_ready(world, &"grain_levy", &"south_court_storehouse", 3, &"shortage_assessment")

	# Canal maintenance and field mobilization require labor tallies before
	# workforce reaches an emergency zero.
	var sowing_or_harvest := period >= 0 and period <= 7
	if sowing_or_harvest and (_get_active_epic_progress(world) < 60 or labor <= 18):
		_offer_if_ready(world, &"pension_roll", &"ditch_labor_tally", 2, &"canal_workforce_demand")

	if dates >= 100 and barley >= 180:
		_offer_if_ready(world, &"consignment_receipt", &"temple_consignment", 1, &"surplus_provisions")
	elif world.get_resource(&"fish") <= 14:
		_offer_if_ready(world, &"consignment_receipt", &"river_fish_supply", 2, &"fish_shortage")

	# The active North-Bay roof leak spoils stored barley and generates its
	# own inspection docket; this is the cause of the Held Barley case.
	if world.has_active_hazard(&"north_bay", &"roof_leak") and barley >= 100:
		_offer_if_ready(world, &"held_barley", &"north_bay", 2, &"roof_leak_inspection")

	# Textile and brewing bottlenecks are delivery/consignment issues.
	if wool >= 30 and world.get_resource(&"textiles") < 8:
		_offer_if_ready(world, &"consignment_receipt", &"textile_workshop", 2, &"wool_backlog")
	if world.get_resource(&"beer") <= 4 and barley >= 40:
		_offer_if_ready(world, &"consignment_receipt", &"brewery_delivery", 1, &"beer_shortage")

	# A load claim is generated by a real allocation conflict: the reserve is
	# under pressure while transport crews still need a shipment. This is
	# separate from beer shortage and gives Case 3 its own cause.
	if barley >= 40 and barley < 180 and labor <= 16:
		_offer_if_ready(world, &"load_claim", &"south_court_storehouse", 2, &"reserve_transport_allocation_conflict")

func _offer_if_ready(world: WorldState, form_type: StringName, subject_id: StringName, urgency: int, reason: StringName) -> void:
	if world.has_pending_form(form_type):
		return
	var flag := StringName("sim_form_cooldown_" + String(form_type))
	var now := world.current_period_index()
	if world.has_flag(flag, now):
		return
	world.enqueue_form({
		"form_type": form_type,
		"subject_id": subject_id,
		"urgency": urgency,
		"year": world.year,
		"generated_by": &"world_simulator",
		"generation_reason": reason,
		"generated_period": now,
	})
	world.set_flag(flag, now + FORM_COOLDOWN_PERIODS)

func _change(world: WorldState, resource_id: StringName, amount: int) -> void:
	if amount == 0:
		return
	if String(resource_id).ends_with("_progress"):
		world.modify_resource(resource_id, amount, "world")
		return
	var available := world.get_resource(resource_id, "institution", "", &"eanna_household")
	var applied_amount := amount
	if amount < 0:
		applied_amount = -mini(-amount, available)
	world.modify_resource(resource_id, applied_amount, "institution", "", &"eanna_household")
	var upper_bound := 40 if resource_id == &"labor" else 2147483647
	var institution: Dictionary = world.institutions.get(&"eanna_household", {})
	var resources: Dictionary = institution.get("stockpiles", {})
	resources[resource_id] = clampi(world.get_resource(resource_id, "institution", "", &"eanna_household"), MIN_STOCK, upper_bound)
	institution["stockpiles"] = resources
	world.institutions[&"eanna_household"] = institution

func _get_active_epic_progress(world: WorldState) -> int:
	for epic_id in world.epics.keys():
		var state: Dictionary = world.epics[epic_id]
		if not bool(state.get("active", false)):
			continue
		var resource_id := StringName(state.get("progress_resource", ""))
		if resource_id != &"":
			return world.get_resource(resource_id)
	return 0
