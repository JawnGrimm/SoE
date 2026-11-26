class_name EventScheduler
extends RefCounted

var runner: EventRunner

func _init(event_runner: EventRunner = null) -> void:
	runner = event_runner if event_runner != null else EventRunner.new()

func pick_next_event(
	world: WorldState,
	actor: PersonEntity,
	templates: Array[EventTemplate],
	active_era: EraDef = null,
	narrative_rng: RandomNumberGenerator = null
) -> EventTemplate:
	if world == null or actor == null:
		return null
	var rng := narrative_rng if narrative_rng != null else world.rng_narrative
	var eligible: Array[EventTemplate] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	var ctx := EventContext.new()
	ctx.world = world
	ctx.era = active_era
	ctx.actor = actor
	ctx.year = world.year
	for template in templates:
		if template == null:
			continue
		var eligible_now := runner.is_eligible(template, ctx)
		if template.id == &"challenge_quayside_stoppage":
			eligible_now = _quayside_challenge_is_eligible(world, actor, active_era)
		if not eligible_now:
			continue
		if template.id == &"case_01_sealed_vessel":
			var has_receipt := world.has_pending_form(&"consignment_receipt")
			var is_harvest_or_stores := int(world.period / 3) >= 2
			if not has_receipt and not is_harvest_or_stores:
				continue
		var weight := maxf(template.weight, 0.0)
		if template.id == &"case_15_south_court":
			if int(world.period / 3) != 2 or not world.has_pending_form(&"grain_levy"):
				continue
			weight *= 3.0
		if template.id == &"case_01_sealed_vessel":
			var season := int(world.period / 3)
			if world.has_flag(&"carrier_distrust", world.current_period_index()):
				weight *= 5.0
			elif season == 2 or season == 3:
				weight *= 2.0
			else:
				weight *= 0.25
		if weight <= 0.0:
			continue
		eligible.append(template)
		weights.append(weight)
		total_weight += weight
	if eligible.is_empty() or total_weight <= 0.0:
		return null
	var roll := rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for index in range(eligible.size()):
		accumulated += weights[index]
		if roll < accumulated:
			return eligible[index]
	return eligible.back()


## The stoppage is a consequence, not a random encounter. Either the carrier
## foreman still distrusts the apprentice, or the crew slowdown remains active.
func _quayside_challenge_is_eligible(world: WorldState, actor: PersonEntity, era: EraDef) -> bool:
	if world == null or actor == null or era == null:
		return false
	if world.period < 8 or world.period > 10:
		return false
	if world.year < -3200 or world.year > -3100:
		return false
	if actor.office_id != &"apprentice_scribe":
		return false
	if world.has_event_fired(&"challenge_quayside_stoppage"):
		return false
	var foreman := world.get_person(&"enlil_kisu")
	var hostile_standing := foreman != null and int(foreman.opinions.get(actor.id, 0)) <= 0
	var crew_slowdown := world.has_flag(&"canal_crew_slowdown", world.current_period_index())
	return hostile_standing or crew_slowdown
