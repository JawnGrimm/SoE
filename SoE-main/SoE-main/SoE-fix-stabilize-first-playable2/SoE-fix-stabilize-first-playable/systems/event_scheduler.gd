class_name EventScheduler
extends RefCounted

var runner: EventRunner
var rng := RandomNumberGenerator.new()

func _init(event_runner: EventRunner = null) -> void:
	runner = event_runner if event_runner != null else EventRunner.new()
	rng.randomize()

func pick_next_event(
	world: WorldState,
	actor: PersonEntity,
	templates: Array[EventTemplate]
) -> EventTemplate:
	if world == null or actor == null:
		return null

	var eligible: Array[EventTemplate] = []
	var total_weight := 0.0
	var ctx := EventContext.new()
	ctx.world = world
	ctx.actor = actor
	ctx.year = world.year

	for template in templates:
		if template == null or not runner.is_eligible(template, ctx):
			continue
		var weight := maxf(template.weight, 0.0)
		if weight <= 0.0:
			continue
		eligible.append(template)
		total_weight += weight

	if eligible.is_empty() or total_weight <= 0.0:
		return null

	var roll := rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for template in eligible:
		accumulated += maxf(template.weight, 0.0)
		if roll < accumulated:
			return template
	return eligible.back()
