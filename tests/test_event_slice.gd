extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var runner := EventRunner.new()
    var template := _make_event()

    var complicity_world := _make_world()
    var complicity_ctx := _make_context(complicity_world)
    assert(runner.is_eligible(template, complicity_ctx), "Grain event should be eligible")

    runner.resolve_outcome(template, template.outcomes[0], complicity_ctx)
    var clerk_a: PersonEntity = complicity_world.get_person(&"clerk")
    assert(&"complicit" in clerk_a.traits, "Look-away outcome should add complicit")
    assert(complicity_world.get_resource(&"grain") == 12, "Look-away should add 2 grain")
    assert(clerk_a.memory.size() == 1, "Look-away should add a dated memory")

    var exposure_world := _make_world()
    var exposure_ctx := _make_context(exposure_world)
    runner.resolve_outcome(template, template.outcomes[1], exposure_ctx)
    var clerk_b: PersonEntity = exposure_world.get_person(&"clerk")
    assert(&"whistleblower" in clerk_b.traits, "Expose outcome should add whistleblower")
    assert(exposure_world.has_pending_form(&"inquiry"), "Expose should create inquiry form")
    assert(exposure_world.has_flag(&"grain_scandal", 1200), "Expose should set scandal flag")

    print("PASS: corrupt grain official eligibility and both isolated outcomes")
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
    ]

    var expose := EventOutcome.new()
    expose.label = "Expose the clerk"
    expose.effects = [
        _effect(&"add_trait", {"trait_id": &"whistleblower"}),
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
