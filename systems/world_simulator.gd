class_name WorldSimulator
extends RefCounted

const CANAL_LAUNCH_YEAR := -3199
const CANAL_CASES_REQUIRED := 8
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
	_simulate_personal_upkeep(world)
	_tick_audit_reprimands(world)
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
				"active": definition.id != &"great_canal_cut",
				"progress": world.get_resource(definition.progress_resource),
				"progress_resource": definition.progress_resource,
				"target": definition.target,
				"title": definition.title,
				"sponsor_institution": definition.sponsor_institution,
				"era_id": definition.era_id,
				"initial_stage": definition.initial_stage,
				"stage": definition.initial_stage,
				"completed": false,
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
		state["progress_resource"] = definition.progress_resource
		state["target"] = definition.target
		state["title"] = definition.title
		state["sponsor_institution"] = definition.sponsor_institution
		state["era_id"] = definition.era_id
		state["initial_stage"] = definition.initial_stage
		if not bool(state.get("active", false)):
			var earned_canal := StringName(epic_id) == &"great_canal_cut" and world.year >= CANAL_LAUNCH_YEAR and world.cases_settled >= CANAL_CASES_REQUIRED
			var summoned_canal := StringName(epic_id) == &"great_canal_cut" and world.epic_summon_issued
			if earned_canal or summoned_canal:
				state["active"] = true
				state["review_initialized"] = false
				state["review_pending"] = true
				state["review_reason"] = "summons" if summoned_canal else "earned_life"
				state["review_summary"] = "A summons from the canal administration requires the apprentice's first formal project account."
				world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "SUMMONS: THE GREAT CANAL CUT", "summary": "The apprentice has settled %d cases. The canal administration now requires a formal account of the Great Canal Cut." % world.cases_settled, "epic_id": String(epic_id)})
			else:
				world.epics[epic_id] = state
				continue
		if not era_matches:
			state["active"] = false
			world.epics[epic_id] = state
			continue
		_simulate_epic(world, definition, state)

func _simulate_epic(world: WorldState, definition: EpicDef, state: Dictionary) -> void:
	var resource_id := definition.progress_resource
	if resource_id == &"" or definition.target <= 0:
		push_warning("WorldSimulator: Epic '%s' has no valid progress resource or target" % definition.id)
		return
	var progress := clampi(world.get_resource(resource_id), 0, definition.target)
	if bool(state.get("completed", false)):
		state["progress"] = progress
		state["stalled"] = false
		state["active_problem"] = ""
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
	state["stalled"] = work_stalled
	state["active_problem"] = "disruption" if disruption else ("labor_shortage" if labor < definition.regression_labor_below else ("barley_shortage" if barley < definition.partial_barley else ""))
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
	world.ensure_epic_review_state(definition.id)

func _simulate_personal_upkeep(world: WorldState) -> void:
	if world.total_periods <= 0 or world.total_periods % 3 != 0:
		return
	var player := world.get_player()
	if player == null:
		return
	var silver := int(player.resources.get(&"silver", 0))
	if silver >= 2:
		player.resources[&"silver"] = silver - 2
		player.flags[&"unpaid_upkeep"] = 0
		world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "HOUSEHOLD UPKEEP", "summary": "Two silver paid for seasonal lodging and meals."})
	else:
		player.flags[&"unpaid_upkeep"] = int(player.flags.get(&"unpaid_upkeep", 0)) + 2 - silver
		player.resources[&"silver"] = 0
		var senior := world.get_person(&"shuruppak_ilu")
		if senior != null:
			senior.change_opinion(player.id, -1, "The apprentice's household account fell into arrears.", world.year)
		world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "UPKEEP IN ARREARS", "summary": "The household could not pay its two-silver seasonal account. Debt is recorded; work remains available."})

func _tick_audit_reprimands(world: WorldState) -> void:
	if world.total_periods <= 0 or world.total_periods % 6 != 0:
		return
	var player := world.get_player()
	if player == null:
		return
	var exposure := int(player.flags.get(&"audit_exposure", 0))
	if exposure <= 0:
		return
	player.flags[&"audit_exposure"] = exposure - 1
	var silver := int(player.resources.get(&"silver", 0))
	if silver >= 2:
		player.resources[&"silver"] = silver - 2
	else:
		player.flags[&"audit_debt"] = int(player.flags.get(&"audit_debt", 0)) + 2 - silver
		player.resources[&"silver"] = 0
	var archivist := world.get_person(&"shuruppak_ilu")
	if archivist != null:
		archivist.change_opinion(player.id, -2, "A concealed account was found in the archive audit.", world.year)
	world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "ARCHIVE REPRIMAND", "summary": "Shuruppak-ilu found a concealed account. Two silver were fined or entered as debt."})

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
		if not _place_is_uruk(world, StringName(institution.get("place_id", ""))):
			continue
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
	_apply_institution_periodic_deltas(world)

func _apply_institution_periodic_deltas(world: WorldState) -> void:
	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var deltas: Dictionary = institution.get("periodic_deltas", {}).duplicate(true)
		if world.period >= 4 and world.period <= 7:
			for resource_id in institution.get("harvest_deltas", {}).keys():
				deltas[resource_id] = int(deltas.get(resource_id, 0)) + int(institution.harvest_deltas[resource_id])
		var resources: Dictionary = institution.get("stockpiles", {}).duplicate(true)
		for resource_key in deltas.keys():
			var resource_id := StringName(resource_key)
			resources[resource_id] = maxi(0, int(resources.get(resource_id, 0)) + int(deltas[resource_key]))
		institution["stockpiles"] = resources
		world.institutions[institution_id] = institution

func _place_is_uruk(world: WorldState, place_id: StringName) -> bool:
	var cursor := place_id
	var visited: Dictionary = {}
	while cursor != &"" and not visited.has(cursor):
		if cursor == &"uruk":
			return true
		visited[cursor] = true
		cursor = StringName(world.places.get(cursor, {}).get("parent", ""))
	return false

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
		var resources: Dictionary = institution.get("stockpiles", {})
		var thresholds: Dictionary = institution.get("pressure_thresholds", {})
		var barley_warn := int(thresholds.get(&"barley_warn", 220))
		var barley_crit := int(thresholds.get(&"barley_crit", 100))
		var labor_warn := int(thresholds.get(&"labor_warn", 16))
		var labor_crit := int(thresholds.get(&"labor_crit", 8))
		var textiles_warn := int(thresholds.get(&"textiles_warn", 4))
		if resources.has(&"barley"):
			if int(resources.get(&"barley", 0)) < barley_crit:
				pressure += 2
			elif int(resources.get(&"barley", 0)) < barley_warn:
				pressure += 1
		if resources.has(&"labor"):
			if int(resources.get(&"labor", 0)) < labor_crit:
				pressure += 2
			elif int(resources.get(&"labor", 0)) < labor_warn:
				pressure += 1
		var interests: Array = institution.get("interests", [])
		if resources.has(&"textiles") and &"textiles" in interests and int(resources.get(&"textiles", 0)) < textiles_warn:
			pressure += 1
		if resources.has(&"offerings") and &"offerings" in interests and int(resources.get(&"offerings", 0)) < 15:
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

	for institution_id in world.institutions.keys():
		var institution: Dictionary = world.institutions[institution_id]
		var place_id := StringName(institution.get("place_id", ""))
		if place_id == &"" or _place_is_uruk(world, place_id):
			continue
		var stock: Dictionary = institution.get("stockpiles", {})
		var thresholds: Dictionary = institution.get("pressure_thresholds", {})
		var barley_warn := int(thresholds.get(&"barley_warn", 105))
		var labor_warn := int(thresholds.get(&"labor_warn", 8))
		var textiles_warn := int(thresholds.get(&"textiles_warn", 3))
		var shortage := (stock.has(&"barley") and int(stock.get(&"barley", 0)) < barley_warn) or (stock.has(&"labor") and int(stock.get(&"labor", 0)) < labor_warn) or (stock.has(&"textiles") and int(stock.get(&"textiles", 0)) < textiles_warn)
		if shortage:
			_offer_if_ready(world, &"bailiff_requisition", place_id, 2, &"local_institution_shortage", StringName(institution_id))

func _offer_if_ready(world: WorldState, form_type: StringName, subject_id: StringName, urgency: int, reason: StringName, institution_id: StringName = &"") -> void:
	if world.has_pending_form(form_type, subject_id):
		return
	var flag := StringName("sim_form_cooldown_%s_%s" % [form_type, subject_id])
	var now := world.current_period_index()
	if world.has_flag(flag, now):
		return
	var form := {"form_type": form_type, "subject_id": subject_id, "urgency": urgency, "year": world.year, "generated_by": &"world_simulator", "generation_reason": reason, "generated_period": now}
	if institution_id != &"":
		form["institution_id"] = institution_id
	world.enqueue_form(form)
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
