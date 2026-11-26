class_name WorldSimulator
extends RefCounted
## Autonomous period simulation for the Uruk campaign.
## WorldState owns the calendar/deadline/hazard step; this class owns ongoing
## economy, institutional activity, and condition-driven docket generation.

const MIN_STOCK := 0
const FORM_COOLDOWN_PERIODS := 3

func advance_period(world: WorldState) -> void:
	if world == null:
		return
	world.advance_period()
	_simulate_economy(world)
	_simulate_institutions(world)
	_simulate_people(world)
	_generate_forms(world)

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
		var canal_bonus := int(world.get_resource(&"canal_progress") / 20)
		_change(world, &"barley", world.rng_sim.randi_range(18, 34) + canal_bonus)
	if p == 5 or p == 6:
		_change(world, &"dates", world.rng_sim.randi_range(5, 11))
	if p >= 2 and p <= 9:
		_change(world, &"fish", world.rng_sim.randi_range(1, 4))
	if p >= 4 and p <= 7:
		_change(world, &"labor", -3) # field and canal labor peak during harvest
	if p == 0 or p == 8:
		_change(world, &"labor", 2) # seasonal workforce returns to the pool
	if p == 8:
		_change(world, &"wool", world.rng_sim.randi_range(3, 7))
	# Brewing converts a small amount of barley into beer. It is a production
	# chain, so shortages in barley also constrain beer output.
	if p == 3 or p == 7 or p == 10:
		var barley_available := world.get_resource(&"barley", "institution", &"", &"eanna_household")
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
		if world.get_resource(&"barley", "institution", &"", &"eanna_household") < 100:
			pressure += 2
		elif world.get_resource(&"barley", "institution", &"", &"eanna_household") < 220:
			pressure += 1
		if world.get_resource(&"labor", "institution", &"", &"eanna_household") < 8:
			pressure += 2
		elif world.get_resource(&"labor", "institution", &"", &"eanna_household") < 16:
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
	var player_id := StringName("player_apprentice")
	var now := world.current_period_index()
	if grain_clerk != null and foreman != null:
		var labor := world.get_resource(&"labor", "institution", &"", &"eanna_household")
		if labor < 8 and not world.has_flag(&"sim_labor_shortage_reaction", now):
			foreman.change_opinion(player_id, -1, "The storehouse labor pool fell below the crew's workable minimum", world.year)
			grain_clerk.change_opinion(player_id, -1, "Labor shortage increased pressure on the grain office", world.year)
			world.set_flag(&"sim_labor_shortage_reaction", now + 6)
		elif labor >= 24 and world.get_resource(&"barley", "institution", &"", &"eanna_household") >= 220 and world.has_flag(&"sim_labor_shortage_reaction", now):
			foreman.change_opinion(player_id, 1, "The stores and labor pool recovered enough to support the crew", world.year)
			world.clear_flag(&"sim_labor_shortage_reaction")
	if senior != null and world.get_resource(&"barley", "institution", &"", &"eanna_household") < 100 and not world.has_flag(&"sim_provisioning_reaction", now):
		senior.change_opinion(player_id, -1, "The archive's provisioning concerns reached the storehouse", world.year)
		world.set_flag(&"sim_provisioning_reaction", now + 6)

func _generate_forms(world: WorldState) -> void:
	var barley := world.get_resource(&"barley", "institution", &"", &"eanna_household")
	var labor := world.get_resource(&"labor", "institution", &"", &"eanna_household")
	var dates := world.get_resource(&"dates", "institution", &"", &"eanna_household")
	var wool := world.get_resource(&"wool", "institution", &"", &"eanna_household")
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
	if sowing_or_harvest and (world.get_resource(&"canal_progress") < 60 or labor <= 18):
		_offer_if_ready(world, &"pension_roll", &"ditch_labor_tally", 2, &"canal_workforce_demand")

	if dates >= 100 and barley >= 180:
		_offer_if_ready(world, &"consignment_receipt", &"temple_consignment", 1, &"surplus_provisions")
	elif world.get_resource(&"fish", "institution", &"", &"eanna_household") <= 14:
		_offer_if_ready(world, &"consignment_receipt", &"river_fish_supply", 2, &"fish_shortage")

	# The active North-Bay roof leak spoils stored barley and generates its
	# own inspection docket; this is the cause of the Held Barley case.
	if world.has_active_hazard(&"north_bay", &"roof_leak") and barley >= 100:
		_offer_if_ready(world, &"held_barley", &"north_bay", 2, &"roof_leak_inspection")

	# Textile and brewing bottlenecks are delivery/consignment issues.
	if wool >= 30 and world.get_resource(&"textiles", "institution", &"", &"eanna_household") < 8:
		_offer_if_ready(world, &"consignment_receipt", &"textile_workshop", 2, &"wool_backlog")
	if world.get_resource(&"beer", "institution", &"", &"eanna_household") <= 4 and barley >= 40:
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
	if resource_id == &"canal_progress":
		world.modify_resource(resource_id, amount, "world")
		return
	world.modify_resource(resource_id, amount, "institution", &"", &"eanna_household")
	var upper_bound := 40 if resource_id == &"labor" else 2147483647
	var current_value := world.get_resource(resource_id, "institution", &"", &"eanna_household")
	world.modify_resource(resource_id, clampi(current_value, MIN_STOCK, upper_bound) - current_value, "institution", &"", &"eanna_household")
