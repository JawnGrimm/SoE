extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []
var registry: DefinitionRegistry

const ROUTINE_CASE: EventTemplate = preload("res://data/events/routine_tally_adjustment.tres")
const ORIGIN_REPLY_CASE: EventTemplate = preload("res://data/events/origin_side_reply.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner := EventRunner.new()
	var template := _make_event()
	var scheduler := EventScheduler.new(runner)
	var follow_up_catalog: Array[EventTemplate] = [ROUTINE_CASE, ORIGIN_REPLY_CASE]

	# --script does not inject project autoloads. Exercise the standalone registry directly.
	registry = DefinitionRegistry.new()
	registry.load_defaults()
	_check(registry.has_definition(&"corrupt_grain_official"), "Registry should index the initial grain event")
	_check(registry.has_definition(&"routine_tally_adjustment"), "Registry should index the routine tally event")
	_check(registry.has_definition(&"origin_side_reply"), "Registry should index the origin reply event")
	_check(registry.get_definition(&"corrupt_grain_official") is EventTemplate, "Registry lookup should return the loaded event Resource")
	_check(registry.get_definitions("events").size() == 3, "Registry should expose all three event definitions by category")
	var prototype_events_are_era_independent := true
	for prototype_event in registry.all_events():
		if not prototype_event.era_tags.is_empty():
			prototype_events_are_era_independent = false
	_check(prototype_events_are_era_independent, "All three prototype events should remain era-independent")
	_check(registry.get_definition(&"missing_definition") == null, "Unknown definition IDs should return null")
	_check(registry.get_definition_ids("events").size() == 3, "Registry should list event IDs")
	_check(registry.get_event(&"corrupt_grain_official") != null, "Typed event lookup should return an event")
	_check(registry.get_era_for_year(1200) == registry.get_era(&"prototype_era"), "Registry should resolve the era covering a year")
	_check(registry.get_era_for_year(99999) == null, "Unknown years should resolve to no era")
	var missing_folder_count := registry.load_folder("res://data/does_not_exist")
	_check(missing_folder_count == 0, "Missing definition folders should load zero resources")
	_check(not registry.warnings.is_empty(), "Registry should retain warnings for missing folders")

	var duplicate_first := EventTemplate.new()
	duplicate_first.id = &"dup_test"
	var duplicate_second := EventTemplate.new()
	duplicate_second.id = &"dup_test"
	_check(registry.register_event(duplicate_first), "Registry should accept the first registration for an ID")
	_check(not registry.register_event(duplicate_second), "Registry should reject a duplicate ID")
	_check(registry.get_event(&"dup_test") == duplicate_first, "Duplicate registration should preserve the first definition")
	_check(registry.warnings.back().contains("duplicate definition id"), "Duplicate registration should record a warning")

	var era_definition := EraDef.new()
	era_definition.id = &"test_era"
	era_definition.display_name = "Test Era"
	era_definition.start_year = 100
	era_definition.end_year = 199
	era_definition.calendar_name = "Test calendar"
	era_definition.period_label = "Month"
	era_definition.period_names = ["First", "Second"]
	_check(era_definition.id == &"test_era", "EraDef should expose a stable definition ID")
	_check(era_definition.start_year <= era_definition.end_year, "EraDef should hold an inclusive chronology range")
	_check(era_definition.period_names.size() == 2, "EraDef should hold optional era-specific period names")

	era_definition.era_tags.append(&"bronze_age")
	_check(era_definition.era_tags.has(&"bronze_age"), "EraDef should expose era tags for event matching")

	# Era eligibility: exact era ID and shared era tags match; unknown eras fail closed.
	var era_context := _make_context(_make_world())
	era_context.era = era_definition
	var era_test_event := EventTemplate.new()
	era_test_event.id = &"era_tag_test"
	_check(runner.is_eligible(era_test_event, era_context), "Untagged events should remain eligible in a known era")
	era_test_event.era_tags = [&"test_era"]
	_check(runner.is_eligible(era_test_event, era_context), "Event tag matching the era ID should be eligible")
	era_test_event.era_tags = [&"bronze_age"]
	_check(runner.is_eligible(era_test_event, era_context), "Event tag matching an era tag should be eligible")
	era_test_event.era_tags = [&"medieval"]
	_check(not runner.is_eligible(era_test_event, era_context), "Event with an unrelated era tag should be ineligible")
	era_context.era = null
	era_test_event.era_tags.clear()
	_check(runner.is_eligible(era_test_event, era_context), "Untagged events should remain eligible when no era covers the year")
	era_test_event.era_tags = [&"roman_republic"]
	_check(not runner.is_eligible(era_test_event, era_context), "Tagged events must fail closed when no active era covers the year")
	_check(registry.get_definition(&"prototype_era") is EraDef, "Registry should index the prototype era definition")
	var prototype_era := registry.get_definition(&"prototype_era") as EraDef
	_check(prototype_era.start_year <= 1200 and prototype_era.end_year >= 1200, "Prototype era should cover the current 1200 test slice")
	_check(CalendarFormatter.format_year(1200) == "1200 CE", "Calendar formatter should label positive years CE")
	_check(CalendarFormatter.format_year(0) == "1 BCE", "Calendar formatter should convert year zero to 1 BCE")
	_check(CalendarFormatter.format_year(-2107) == "2108 BCE", "Calendar formatter should convert negative simulation years to BCE")
	_check(CalendarFormatter.format_date(prototype_era, 1200, 0).contains("Period 01"), "Calendar formatter should use era period labels")
	_check(CalendarFormatter.format_date(era_definition, 1200, 1).contains("Second"), "Calendar formatter should use custom period names when supplied")
	era_definition.period_names = ["Spring", "Summer", "Autumn", "Winter"]
	_check(CalendarFormatter.format_date(era_definition, 1200, 3).contains("Winter"), "Calendar formatter should support four custom seasons")
	era_definition.period_names.clear()
	_check(CalendarFormatter.format_date(era_definition, 1200, 0).contains("Month 01"), "Empty custom periods should fall back to the era period label")
	_check(CalendarFormatter.format_date(null, 1200, 0) == "Period 01 • 1200 CE", "Null era should use the generic calendar fallback")
	_check(CalendarFormatter.format_year(-2108) == "2109 BCE", "Calendar formatter should convert -2108 to 2109 BCE")

	var complicity_world := _make_world()
	var complicity_ctx := _make_context(complicity_world)
	var complicity_form_id: StringName = complicity_world.pending_forms[0]["id"]
	_check(runner.is_eligible(template, complicity_ctx), "Grain event should be eligible")
	_check(complicity_world.record_form_assessment(complicity_form_id, "No individual responsibility assigned"), "Assessment should attach to pending form")

	runner.resolve_outcome(template, template.outcomes[0], complicity_ctx)
	var clerk_a: PersonEntity = complicity_world.get_person(&"clerk")
	_check(&"complicit" in clerk_a.traits, "Look-away outcome should add complicit")
	_check(complicity_world.get_resource(&"grain") == 12, "Look-away should add 2 grain")
	_check(clerk_a.memory.size() == 1, "Look-away should add a dated memory")
	_check(complicity_world.pending_forms.is_empty(), "Look-away should close the grain levy")
	_check(complicity_world.resolved_forms.size() == 1, "Look-away should archive the grain levy")
	_check(complicity_world.resolved_forms[0]["assessment"] == "No individual responsibility assigned", "Archived form should preserve assessment")
	_check(complicity_world.resolved_forms[0]["disposition"] == "certified", "Archived form should preserve disposition")
	_check(not runner.is_eligible(template, complicity_ctx), "Once-per-world event should no longer be eligible")
	var grain_after_resolution := complicity_world.get_resource(&"grain")
	runner.resolve_outcome(template, template.outcomes[0], complicity_ctx)
	_check(complicity_world.get_resource(&"grain") == grain_after_resolution, "Once-only gate must prevent duplicate effects")

	complicity_world.advance_period()
	_check(complicity_world.period == 1 and complicity_world.year == 1200, "First period advance should remain in year 1200")
	_check(complicity_world.get_resource(&"grain") == 12, "Period advance must preserve stockpiles")
	_check(complicity_world.resolved_forms.size() == 1, "Period advance must preserve the archive")
	_check(&"complicit" in clerk_a.traits, "Period advance must preserve traits")
	var routine_case := scheduler.pick_next_event(complicity_world, clerk_a, follow_up_catalog, registry.get_era_for_year(complicity_world.year))
	if not _check(routine_case != null, "Complicit trait should schedule the routine tally case"):
		_finish()
		return
	_check(routine_case.id == &"routine_tally_adjustment", "Scheduled routine case should have the expected ID")
	var routine_ctx := _make_context(complicity_world)
	_check(runner.is_eligible(routine_case, routine_ctx), "Routine tally should still pass normal conditions")
	runner.resolve_outcome(routine_case, routine_case.outcomes[0], routine_ctx)
	_check(scheduler.pick_next_event(complicity_world, clerk_a, follow_up_catalog) == null, "No follow-up should remain after the routine tally is filed")

	var exposure_world := _make_world()
	var exposure_ctx := _make_context(exposure_world)
	var exposure_form_id: StringName = exposure_world.pending_forms[0]["id"]
	_check(exposure_world.record_form_assessment(exposure_form_id, "Origin-side dispatch count or handling requires verification"), "Alternate assessment should attach")
	runner.resolve_outcome(template, template.outcomes[1], exposure_ctx)
	var clerk_b: PersonEntity = exposure_world.get_person(&"clerk")
	_check(&"whistleblower" in clerk_b.traits, "Expose outcome should add whistleblower")
	_check(exposure_world.has_pending_form(&"inquiry"), "Expose should leave inquiry form pending")
	_check(exposure_world.resolved_forms.size() == 1, "Expose should archive the original levy")
	_check(exposure_world.resolved_forms[0]["assessment"] == "Origin-side dispatch count or handling requires verification", "Inquiry archive should preserve assessment")
	_check(exposure_world.resolved_forms[0]["disposition"] == "referred_for_inquiry", "Inquiry archive should preserve disposition")
	_check(exposure_world.has_flag(&"grain_scandal", 1200), "Expose should set scandal flag")

	exposure_world.advance_period()
	var origin_case := scheduler.pick_next_event(exposure_world, clerk_b, follow_up_catalog, registry.get_era_for_year(exposure_world.year))
	if not _check(origin_case != null, "Scandal flag plus pending inquiry should schedule the origin reply"):
		_finish()
		return
	_check(origin_case.id == &"origin_side_reply", "Scheduled origin case should have the expected ID")
	var archived_levy := exposure_world.get_latest_resolved_form(&"grain_levy")
	if not _check(not archived_levy.is_empty(), "Resolved grain levy should remain available to the origin reply"):
		_finish()
		return
	_check(archived_levy.get("assessment", "") == "Origin-side dispatch count or handling requires verification", "Origin reply must be able to read the archived assessment")
	var origin_ctx := _make_context(exposure_world)
	runner.resolve_outcome(origin_case, origin_case.outcomes[0], origin_ctx)
	_check(not exposure_world.has_pending_form(&"inquiry"), "Origin reply should close the inquiry form")
	_check(scheduler.pick_next_event(exposure_world, clerk_b, follow_up_catalog) == null, "Queue should be empty after the origin reply is filed")

	var year_rollover := WorldState.new()
	year_rollover.year = 1200
	year_rollover.period = 11
	year_rollover.stockpiles[&"grain"] = 17
	year_rollover.advance_period()
	_check(year_rollover.year == 1201 and year_rollover.period == 0, "Period 12 should roll into the next year")
	_check(year_rollover.get_resource(&"grain") == 17, "Year rollover must preserve stockpiles")

	complicity_world.event_history.append({"event_id": &"future_event", "year": 1205})
	_check(not complicity_world.was_event_recent(&"future_event", 1200, 10), "Future-dated events must not count as recent")

	var follow_up_event := _make_event()
	follow_up_event.once_per_world = false
	follow_up_event.conditions = [_condition(&"year_in_range", {"min": 5000, "max": 6000})]
	var follow_up_world := _make_world()
	var follow_up_ctx := _make_context(follow_up_world)
	runner.resolve_outcome(follow_up_event, follow_up_event.outcomes[0], follow_up_ctx, true)
	_check(&"complicit" in follow_up_ctx.actor.traits, "Explicit follow-up bypass should skip ordinary eligibility conditions")

	_finish()

func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures.append(msg)
		push_error("FAIL: %s" % msg)
	return cond

func _finish() -> void:
	if _failures.is_empty():
		print("PASS: %d/%d checks passed" % [_checks, _checks])
		quit(0)
	else:
		printerr("FAIL: %d/%d checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			printerr(" - %s" % failure)
		quit(1)

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
	ctx.era = registry.get_era_for_year(world.year)
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
