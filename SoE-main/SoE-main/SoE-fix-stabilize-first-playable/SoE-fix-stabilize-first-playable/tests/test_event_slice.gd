extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner := EventRunner.new()
	var template := _make_event()

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

	complicity_world.event_history.append({"event_id": &"future_event", "year": 1205})
	assert(not complicity_world.was_event_recent(&"future_event", 1200, 10), "Future-dated events must not count as recent")

	var follow_up_event := _make_event()
	follow_up_event.once_per_world = false
	follow_up_event.conditions = [_condition(&"year_in_range", {"min": 5000, "max": 6000})]
	var follow_up_world := _make_world()
	var follow_up_ctx := _make_context(follow_up_world)
	runner.resolve_outcome(follow_up_event, follow_up_event.outcomes[0], follow_up_ctx, true)
	assert(&"complicit" in follow_up_ctx.actor.traits, "Explicit follow-up bypass should skip ordinary eligibility conditions")

	print("PASS: playable grain event, archived assessments, eligibility gates, and future-date handling")
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
