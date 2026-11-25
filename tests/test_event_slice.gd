extends SceneTree

const ROUTINE_CASE: EventTemplate = preload("res://data/events/routine_tally_adjustment.tres")
const ORIGIN_REPLY_CASE: EventTemplate = preload("res://data/events/origin_side_reply.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner := EventRunner.new()
	var template := _make_event()
	var scheduler := EventScheduler.new(runner)
	var follow_up_catalog: Array[EventTemplate] = [ROUTINE_CASE, ORIGIN_REPLY_CASE]

	var complicity_world := _make_world()
	var complicity_ctx := _make_context(complicity_world)
	var complicity_form_id: StringName = complicity_world.pending_forms[0]["id"]
	assert(runner.is_eligible(template, complicity_ctx), "Grain event should be eligible")
	assert(complicity_world.record_form_assessment(complicity_form_id, "No individual responsibility assigned"), "Assessment should attach to pending form")

	runner.resolve_outcome(template, template.outcomes[0], complicity_ctx)
	var clerk_a: PersonEntity = complicity_world.get_person(&"clerk")
	assert(&"complicit" in clerk_a.traits, "Look-away outcome should add complicit")
	assert(complicity_world.get_resource(&"grain") == 12, "Look-away should add 2 grain")
	assert(clerk_a.memory.size() == 1, "Look-away should add a dated memory")
	assert(complicity_world.pending_forms.is_empty(), "Look-away should close the grain levy")
	assert(complicity_world.resolved_forms.size() == 1, "Look-away should archive the grain levy")
	assert(complicity_world.resolved_forms[0]["assessment"] == "No individual responsibility assigned", "Archived form should preserve assessment")
	assert(complicity_world.resolved_forms[0]["disposition"] == "certified", "Archived form should preserve disposition")
	assert(not runner.is_eligible(template, complicity_ctx), "Once-per-world event should no longer be eligible")
	var grain_after_resolution := complicity_world.get_resource(&"grain")
	runner.resolve_outcome(template, template.outcomes[0], complicity_ctx)
	assert(complicity_world.get_resource(&"grain") == grain_after_resolution, "Once-only gate must prevent duplicate effects")

	complicity_world.advance_period()
	assert(complicity_world.period == 1 and complicity_world.year == 1200, "First period advance should remain in year 1200")
	assert(complicity_world.get_resource(&"grain") == 12, "Period advance must preserve stockpiles")
	assert(complicity_world.resolved_forms.size() == 1, "Period advance must preserve the archive")
	assert(&"complicit" in clerk_a.traits, "Period advance must preserve traits")
	var routine_case := scheduler.pick_next_event(complicity_world, clerk_a, follow_up_catalog)
	assert(routine_case != null and routine_case.id == &"routine_tally_adjustment", "Complicit trait should schedule the routine tally case")
	var routine_ctx := _make_context(complicity_world)
	assert(runner.is_eligible(routine_case, routine_ctx), "Routine tally should still pass normal conditions")
	runner.resolve_outcome(routine_case, routine_case.outcomes[0], routine_ctx)
	assert(scheduler.pick_next_event(complicity_world, clerk_a, follow_up_catalog) == null, "No follow-up should remain after the routine tally is filed")

	var exposure_world := _make_world()
	var exposure_ctx := _make_context(exposure_world)
	var exposure_form_id: StringName = exposure_world.pending_forms[0]["id"]
	assert(exposure_world.record_form_assessment(exposure_form_id, "Origin-side dispatch count or handling requires verification"), "Alternate assessment should attach")
	runner.resolve_outcome(template, template.outcomes[1], exposure_ctx)
	var clerk_b: PersonEntity = exposure_world.get_person(&"clerk")
	assert(&"whistleblower" in clerk_b.traits, "Expose outcome should add whistleblower")
	assert(exposure_world.has_pending_form(&"inquiry"), "Expose should leave inquiry form pending")
	assert(exposure_world.resolved_forms.size() == 1, "Expose should archive the original levy")
	assert(exposure_world.resolved_forms[0]["assessment"] == "Origin-side dispatch count or handling requires verification", "Inquiry archive should preserve assessment")
	assert(exposure_world.resolved_forms[0]["disposition"] == "referred_for_inquiry", "Inquiry archive should preserve disposition")
	assert(exposure_world.has_flag(&"grain_scandal", 1200), "Expose should set scandal flag")

	exposure_world.advance_period()
	var origin_case := scheduler.pick_next_event(exposure_world, clerk_b, follow_up_catalog)
	assert(origin_case != null and origin_case.id == &"origin_side_reply", "Scandal flag plus pending inquiry should schedule the origin reply")
	var archived_levy := exposure_world.get_latest_resolved_form(&"grain_levy")
	assert(archived_levy.get("assessment", "") == "Origin-side dispatch count or handling requires verification", "Origin reply must be able to read the archived assessment")
	var origin_ctx := _make_context(exposure_world)
	runner.resolve_outcome(origin_case, origin_case.outcomes[0], origin_ctx)
	assert(not exposure_world.has_pending_form(&"inquiry"), "Origin reply should close the inquiry form")
	assert(scheduler.pick_next_event(exposure_world, clerk_b, follow_up_catalog) == null, "Queue should be empty after the origin reply is filed")

	var year_rollover := WorldState.new()
	year_rollover.year = 1200
	year_rollover.period = 11
	year_rollover.stockpiles[&"grain"] = 17
	year_rollover.advance_period()
	assert(year_rollover.year == 1201 and year_rollover.period == 0, "Period 12 should roll into the next year")
	assert(year_rollover.get_resource(&"grain") == 17, "Year rollover must preserve stockpiles")

	complicity_world.event_history.append({"event_id": &"future_event", "year": 1205})
	assert(not complicity_world.was_event_recent(&"future_event", 1200, 10), "Future-dated events must not count as recent")

	var follow_up_event := _make_event()
	follow_up_event.once_per_world = false
	follow_up_event.conditions = [_condition(&"year_in_range", {"min": 5000, "max": 6000})]
	var follow_up_world := _make_world()
	var follow_up_ctx := _make_context(follow_up_world)
	runner.resolve_outcome(follow_up_event, follow_up_event.outcomes[0], follow_up_ctx, true)
	assert(&"complicit" in follow_up_ctx.actor.traits, "Explicit follow-up bypass should skip ordinary eligibility conditions")

	print("PASS: event outcomes, persistent period clock, reactive scheduler branches, and empty queue")
	quit(0)

func _make_world() -> WorldState:
	var world := WorldState.new()
	world.year = 1200
	world.stockpiles[&"grain"] = 10
	var clerk := PersonEntity.new()
	clerk.id = &"clerk"
	clerk.office_id = &"grain_clerk"
	clerk.skills.levels[&"arithmetic"] = 2
	world.people[clerk.id] = clerk
	world.enqueue_form({"form_type": &"grain_levy", "subject_id": &"village"})
	return world

func _make_context(world: WorldState) -> EventContext:
	var ctx := EventContext.new()
	ctx.world = world
	ctx.actor = world.get_person(&"clerk")
	ctx.year = world.year
	return ctx

func _make_event() -> EventTemplate:
	var event := EventTemplate.new()
	event.id = &"corrupt_grain_official"
	event.title = "The Missing Measures"
	event.once_per_world = true
	event.conditions = [
		_condition(&"in_office", {"office_id": &"grain_clerk"}),
		_condition(&"skill_at_least", {"skill": &"arithmetic", "level": 2}),
		_condition(&"has_pending_form", {"form_type": &"grain_levy"}),
		_condition(&"year_in_range", {"min": 1100, "max": 1300}),
	]

	var look_away := EventOutcome.new()
	look_away.label = "Look away"
	look_away.effects = [
		_effect(&"add_trait", {"trait_id": &"complicit"}),
		_effect(&"modify_resource", {"resource": &"grain", "amount": 2, "scope": "world"}),
		_effect(&"add_memory", {"memory_id": &"grain_complicity", "text": "I let the figures stand.", "involved": []}),
		_effect(&"resolve_form", {"form_type": &"grain_levy", "disposition": "certified"}),
	]

	var expose := EventOutcome.new()
	expose.label = "Expose the clerk"
	expose.effects = [
		_effect(&"add_trait", {"trait_id": &"whistleblower"}),
		_effect(&"resolve_form", {"form_type": &"grain_levy", "disposition": "referred_for_inquiry"}),
		_effect(&"create_form", {"form_type": &"inquiry", "subject_id": &"clerk", "urgency": 2}),
		_effect(&"set_flag", {"flag": &"grain_scandal", "scope": "world"}),
	]
	event.outcomes = [look_away, expose]
	return event

func _condition(kind: StringName, parameters: Dictionary) -> EventCondition:
	var condition := EventCondition.new()
	condition.condition_type = kind
	condition.parameters = parameters
	return condition

func _effect(kind: StringName, parameters: Dictionary) -> EventEffect:
	var effect := EventEffect.new()
	effect.effect_type = kind
	effect.parameters = parameters
	return effect
