class_name EventRunner
extends RefCounted

var conditions := ConditionEvaluator.new()
var effects := EffectExecutor.new()

func _passes_once_gates(template: EventTemplate, ctx: EventContext) -> bool:
	if template.once_per_world and ctx.world.has_event_fired(template.id):
		return false
	if template.once_per_character and ctx.actor != null and ctx.world.has_character_fired(template.id, ctx.actor.id):
		return false
	return true

func is_eligible(template: EventTemplate, ctx: EventContext) -> bool:
	if template == null or ctx == null or ctx.world == null:
		return false
	if not _passes_once_gates(template, ctx):
		return false
	if template.cooldown_years > 0 and ctx.world.was_event_recent(template.id, ctx.year, template.cooldown_years):
		return false
	return conditions.evaluate_all(template.conditions, ctx)

func resolve_outcome(
	template: EventTemplate,
	outcome: EventOutcome,
	ctx: EventContext,
	skip_eligibility: bool = false
) -> StringName:
	if template == null or outcome == null or ctx == null or ctx.world == null:
		push_warning("EventRunner: resolve_outcome called with invalid arguments")
		return &""
	if not template.outcomes.has(outcome):
		push_warning("EventRunner: outcome does not belong to event '%s'" % template.id)
		return &""
	if not _passes_once_gates(template, ctx):
		push_warning("EventRunner: once-only gate rejected event '%s'" % template.id)
		return &""
	if not skip_eligibility:
		if template.cooldown_years > 0 and ctx.world.was_event_recent(template.id, ctx.year, template.cooldown_years):
			push_warning("EventRunner: cooldown rejected event '%s'" % template.id)
			return &""
		if not conditions.evaluate_all(template.conditions, ctx):
			push_warning("EventRunner: conditions rejected event '%s'" % template.id)
			return &""

	effects.execute_all(outcome.effects, ctx)
	ctx.world.record_event(template.id, ctx.actor.id if ctx.actor != null else &"", ctx.year)
	return outcome.follow_up_event

func pick_weighted_outcome(template: EventTemplate, rng: RandomNumberGenerator) -> EventOutcome:
	if template == null or template.outcomes.is_empty():
		return null
	var total := 0.0
	for outcome in template.outcomes:
		total += maxf(outcome.weight, 0.0)
	if total <= 0.0:
		push_warning("EventRunner: event '%s' has no positive outcome weight" % template.id)
		return null
	var roll := rng.randf_range(0.0, total)
	var accumulated := 0.0
	for outcome in template.outcomes:
		accumulated += maxf(outcome.weight, 0.0)
		if roll < accumulated:
			return outcome
	return template.outcomes.back()
