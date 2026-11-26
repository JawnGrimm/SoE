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
		if template == null or not runner.is_eligible(template, ctx):
			continue
		var weight := maxf(template.weight, 0.0)
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
