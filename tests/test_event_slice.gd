extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []
var registry: DefinitionRegistry
var _finished := false

const ROUTINE_CASE: EventTemplate = preload("res://data/events/routine_tally_adjustment.tres")
const ORIGIN_REPLY_CASE: EventTemplate = preload("res://data/events/origin_side_reply.tres")

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(45.0).timeout
	if not _finished:
		printerr("TEST WATCHDOG: integration test did not reach _finish()")
		quit(2)

func _run() -> void:
	_check(ResourceLoader.exists("res://assets/desk/desk_tabletop.png"), "Cedar tabletop texture should be present")
	_check(ResourceLoader.exists("res://assets/desk/clay_docket.png"), "Clay docket texture should be present")
	_check(ResourceLoader.exists("res://assets/desk/archive_stack.png"), "Archive stack texture should be present")
	_check(ResourceLoader.exists("res://assets/desk/Ancient Wrapped Wooden Stylus.png"), "Stylus prop texture should be present")
	_check(load("res://assets/desk/desk_tabletop.png") is Texture2D, "Cedar tabletop should import as a texture")
	_check(load("res://assets/desk/clay_docket.png") is Texture2D, "Clay docket should import as a texture")
	_check(load("res://assets/desk/Ancient Wrapped Wooden Stylus.png") is Texture2D, "Stylus prop should import as a texture")
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
	_check(registry.get_definitions("events").size() == 11, "Registry should expose all eleven event definitions by category")
	var prototype_events_are_era_independent := true
	for prototype_id in [&"corrupt_grain_official", &"routine_tally_adjustment", &"origin_side_reply"]:
		var prototype_event := registry.get_event(prototype_id)
		if prototype_event == null or not prototype_event.era_tags.is_empty():
			prototype_events_are_era_independent = false
	_check(prototype_events_are_era_independent, "The three prototype events should remain era-independent")
	_check(registry.get_event(&"case_15_south_court") != null, "Registry should load Case 15")
	_check(registry.get_event(&"case_01_sealed_vessel") != null, "Registry should load Case 1")
	_check(registry.get_era(&"uruk_storehouse") != null, "Registry should load the Uruk era")
	_check(registry.get_definition(&"missing_definition") == null, "Unknown definition IDs should return null")
	_check(registry.get_definition_ids("events").size() == 11, "Registry should list all eleven event IDs")
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
	_check(scheduler.pick_next_event(era_context.world, era_context.actor, [era_test_event], era_definition) == era_test_event, "Scheduler should pass the active era into its event context")
	era_test_event.era_tags = [&"medieval"]
	_check(not runner.is_eligible(era_test_event, era_context), "Event with an unrelated era tag should be ineligible")
	_check(scheduler.pick_next_event(era_context.world, era_context.actor, [era_test_event], era_definition) == null, "Scheduler should exclude events tagged for another era")
	era_context.era = null
	era_test_event.era_tags.clear()
	_check(runner.is_eligible(era_test_event, era_context), "Untagged events should remain eligible when no era covers the year")
	era_test_event.era_tags = [&"roman_republic"]
	_check(not runner.is_eligible(era_test_event, era_context), "Tagged events must fail closed when no active era covers the year")
	var era_blocked_outcome := EventOutcome.new()
	era_test_event.outcomes = [era_blocked_outcome]
	_check(runner.resolve_outcome(era_test_event, era_blocked_outcome, era_context).is_empty(), "Outcome resolution must also fail closed when a tagged event has no active era")
	_check(not era_context.world.has_event_fired(era_test_event.id), "Era-rejected outcomes must not be recorded as fired")
	_check(registry.get_definition(&"prototype_era") is EraDef, "Registry should index the prototype era definition")
	var prototype_era := registry.get_definition(&"prototype_era") as EraDef
	_check(prototype_era.start_year <= 1200 and prototype_era.end_year >= 1200, "Prototype era should cover the current 1200 test slice")
	_check(CalendarFormatter.format_year(1200) == "1200 CE", "Calendar formatter should label positive years CE")
	_check(CalendarFormatter.format_year(0) == "1 BCE", "Calendar formatter should convert year zero to 1 BCE")
	_check(CalendarFormatter.format_year(-2107) == "2108 BCE", "Calendar formatter should convert negative simulation years to BCE")
	_check(CalendarFormatter.format_date(prototype_era, 1200, 0).contains("Period 01"), "Calendar formatter should use era period labels")
	_check(CalendarFormatter.format_date(era_definition, 1200, 6).contains("Second"), "Calendar formatter should use custom period names when supplied")
	era_definition.period_names = ["Spring", "Summer", "Autumn", "Winter"]
	_check(CalendarFormatter.format_date(era_definition, 1200, 9).contains("Winter"), "Calendar formatter should support four custom seasons")
	era_definition.period_names.clear()
	_check(CalendarFormatter.format_date(era_definition, 1200, 0).contains("Month 01"), "Empty custom periods should fall back to the era period label")
	_check(CalendarFormatter.format_date(null, 1200, 0) == "Period 01 • 1200 CE", "Null era should use the generic calendar fallback")
	_check(CalendarFormatter.format_year(-2108) == "2109 BCE", "Calendar formatter should convert -2108 to 2109 BCE")

	# Uruk seed forks are repeatable and independent of narrative consumption.
	var uruk_a := WorldState.new()
	var uruk_b := WorldState.new()
	var uruk_player_a := UrukSeeder.seed_campaign(uruk_a, 987654321)
	var uruk_player_b := UrukSeeder.seed_campaign(uruk_b, 987654321)
	_check(uruk_a.master_seed == 987654321, "Uruk seeder should retain the campaign seed")
	_check(uruk_a.year == -3200 and uruk_a.period == 0, "Uruk campaign should begin at its era start")
	_check(uruk_a.people.size() == 17, "Uruk seeder should create the expanded seventeen-person roster")
	_check(uruk_a.places.size() == 9, "Uruk seed should establish nine local and connected places")
	_check(uruk_a.institutions.size() == 3, "Uruk seed should establish three institutions and exchange networks")
	_check(uruk_a.social_groups.size() == 5, "Uruk seed should establish five working and household groups")
	var seeded_tie_count := 0
	for person in uruk_a.people.values():
		seeded_tie_count += person.relationships.size()
	_check(seeded_tie_count == 34, "Uruk seed should establish thirty-four directed relationship entries, including explicit player opinions and authored social/economic ties (found %d)" % seeded_tie_count)
	_check(uruk_a.get_person(&"geme_tur").relationships.has(uruk_player_a.id), "The player's household member should have an explicit family tie")
	_check(uruk_a.get_person(&"ur_gula").relationships.has(&"nin_dada"), "Pastoral wool supply should connect to textile production")
	_check(uruk_a.places.has(&"susa") and uruk_a.places.has(&"habuba_kabira"), "Uruk seed should include both external exchange settlements")
	var world_graph_is_closed := true
	for person in uruk_a.people.values():
		for other_id in person.relationships:
			if uruk_a.get_person(other_id) == null:
				world_graph_is_closed = false
	_check(world_graph_is_closed, "Every seeded person-to-person relationship should resolve both endpoints")
	for resource_id in [&"barley", &"dates", &"sheep", &"goats", &"cattle", &"fish", &"beer", &"wool", &"textiles", &"clay", &"reeds", &"bitumen", &"timber", &"copper", &"silver"]:
		_check(uruk_a.stockpiles.has(resource_id), "Uruk seed should initialize commodity %s" % resource_id)
	_check(uruk_player_a.id == &"player_apprentice", "Uruk seeder should return the apprentice")
	_check(uruk_a.get_person(&"shuruppak_ilu").get_opinion(uruk_player_a.id) == 5, "Senior scribe should begin at +5 opinion")
	for resident_id in [&"ur_nanna", &"utu_mansum", &"enlil_kisu", &"lu_nanshe", &"nin_kasi", &"geme_inana"]:
		_check(uruk_a.get_person(resident_id).relationships.has(uruk_player_a.id) and uruk_a.get_person(resident_id).get_opinion(uruk_player_a.id) == 0, "Every other resident should store an explicit zero opinion")
	_check(uruk_a.get_person(&"shuruppak_ilu").vulnerabilities[&"patience_remaining"] == uruk_b.get_person(&"shuruppak_ilu").vulnerabilities[&"patience_remaining"], "People jitter should reproduce from the same seed")
	_check(uruk_a.stockpiles == uruk_b.stockpiles, "Simulation stockpiles should reproduce from the same seed")
	var stream_a := WorldState.new()
	var stream_b := WorldState.new()
	stream_a.set_world_seed(77)
	stream_b.set_world_seed(77)
	for narrative_roll in range(100):
		stream_a.rng_narrative.randi()
	_check(stream_a.rng_sim.randi() == stream_b.rng_sim.randi(), "Narrative rolls must not desynchronize simulation RNG")
	_check(stream_a.rng_people.randi() == stream_b.rng_people.randi(), "Narrative rolls must not desynchronize people RNG")
	_check(uruk_a.get_person(&"ur_nanna").vulnerabilities[&"granary_roof_integrity"] >= 40, "Roof integrity should use the specified jitter range")
	_check(uruk_a.get_person(&"enlil_kisu").vulnerabilities[&"crew_hunger"] in [1, 2, 3], "Crew hunger should use the specified jitter range")
	_check(CalendarFormatter.format_date(registry.get_era(&"uruk_storehouse"), -3200, 3).contains("Sowing"), "Three desk periods should map to the next Uruk season")
	_check(CalendarFormatter.format_date(registry.get_era(&"uruk_storehouse"), -3200, 9).contains("Stores"), "Periods 9-11 should map to Stores")
	var case15 := registry.get_event(&"case_15_south_court")
	if case15 == null:
		_finish()
		return
	var uruk_ctx := EventContext.new()
	uruk_ctx.world = uruk_a
	uruk_ctx.actor = uruk_player_a
	uruk_ctx.year = uruk_a.year
	uruk_ctx.era = registry.get_era(&"uruk_storehouse")
	_check(not runner.is_eligible(case15, uruk_ctx), "Case 15 should not be eligible before Harvest")
	uruk_a.period = 6
	var case15_pool: Array[EventTemplate] = [case15]
	_check(runner.is_eligible(case15, uruk_ctx), "Case 15 should be eligible during Harvest with a pending grain levy")
	_check(scheduler.pick_next_event(uruk_a, uruk_player_a, case15_pool, uruk_ctx.era, uruk_a.rng_narrative) == case15, "Case 15 should return to the desk during Harvest when a levy is pending")
	runner.resolve_outcome(case15, case15.outcomes[0], uruk_ctx)
	_check(uruk_a.get_person(&"utu_mansum").get_opinion(uruk_player_a.id) == 2, "Case 15 should shift Utu-mansum's opinion of the apprentice")
	_check(uruk_a.get_person(&"enlil_kisu").get_opinion(uruk_player_a.id) == 2, "Case 15 should shift Enlil-kisu's opinion of the apprentice")
	_check(uruk_a.get_person(&"shuruppak_ilu").get_opinion(uruk_player_a.id) == 10, "Case 15 should shift Shuruppak-ilu's opinion of the apprentice")
	_check(uruk_a.get_resource(&"barley") >= 443, "Case 15 should enter 23 measures of barley")
	_check(uruk_a.resolved_forms.size() == 1, "Case 15 should resolve the opening grain levy")


	# Case 1 may arrive from a receipt in any season, or from the Harvest/Stores desk pool.
	var sealed_case := registry.get_event(&"case_01_sealed_vessel")
	if sealed_case == null:
		_finish()
		return
	var sealed_world := WorldState.new()
	var sealed_player := UrukSeeder.seed_campaign(sealed_world, 44)
	var sealed_context := EventContext.new()
	sealed_context.world = sealed_world
	sealed_context.actor = sealed_player
	sealed_context.year = sealed_world.year
	sealed_context.era = registry.get_era(&"uruk_storehouse")
	var sealed_pool: Array[EventTemplate] = [sealed_case]
	_check(scheduler.pick_next_event(sealed_world, sealed_player, sealed_pool, sealed_context.era, sealed_world.rng_narrative) == null, "Case 1 should not arrive in Flood without a receipt")
	sealed_world.enqueue_form({"form_type": &"consignment_receipt"})
	_check(scheduler.pick_next_event(sealed_world, sealed_player, sealed_pool, sealed_context.era, sealed_world.rng_narrative) == sealed_case, "Case 1 should be eligible when a consignment receipt is pending")
	sealed_world.pending_forms.clear()
	sealed_world.period = 6
	sealed_world.enqueue_form({"form_type": &"consignment_receipt"})
	_check(scheduler.pick_next_event(sealed_world, sealed_player, sealed_pool, sealed_context.era, sealed_world.rng_narrative) == sealed_case, "Case 1 should be eligible during Harvest when a consignment receipt is pending")
	sealed_world.enqueue_form({"form_type": &"consignment_receipt"})
	var sealed_form_context := EventContext.new()
	sealed_form_context.world = sealed_world
	sealed_form_context.actor = sealed_player
	sealed_form_context.year = sealed_world.year
	sealed_form_context.era = sealed_context.era
	runner.resolve_outcome(sealed_case, sealed_case.outcomes[0], sealed_form_context)
	_check(sealed_world.get_person(&"utu_mansum").get_opinion(sealed_player.id) == 3, "Case 1 should record Utu-mansum's opinion of the apprentice")
	_check(sealed_world.get_person(&"enlil_kisu").get_opinion(sealed_player.id) == 1, "Case 1 should record Enlil-kisu's opinion of the apprentice")
	_check(sealed_world.get_resource(&"clay_reeds") >= 49, "Case 1 should consume one clay and reed unit")
	_check(sealed_world.resolved_forms.back()["disposition"] == "quarantine_cracked_vessel", "Case 1 should resolve the receipt with its authored disposition")

	var bce_clock := WorldState.new()
	bce_clock.year = -3200
	bce_clock.set_flag(&"seasonal_test", bce_clock.current_period_index() + 12)
	var bce_person := PersonEntity.new()
	bce_person.id = &"bce_person"
	bce_person.flags[&"seasonal_person_test"] = bce_clock.current_period_index() + 12
	bce_clock.people[bce_person.id] = bce_person
	_check(bce_clock.has_flag(&"seasonal_test", bce_clock.current_period_index()), "Timed world flags should work in BCE years")
	_check(bce_person.has_flag(&"seasonal_person_test", bce_clock.current_period_index()), "Timed person flags should work in BCE years")
	for period_step in range(12):
		bce_clock.advance_period()
	_check(not bce_clock.has_flag(&"seasonal_test", bce_clock.current_period_index()), "BCE world flag should expire after twelve periods")
	_check(not bce_person.has_flag(&"seasonal_person_test", bce_clock.current_period_index()), "BCE person flag should expire after twelve periods")

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
	_check(scheduler.pick_next_event(complicity_world, clerk_a, follow_up_catalog, registry.get_era_for_year(complicity_world.year)) == null, "No follow-up should remain after the routine tally is filed")

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
	_check(scheduler.pick_next_event(exposure_world, clerk_b, follow_up_catalog, registry.get_era_for_year(exposure_world.year)) == null, "Queue should be empty after the origin reply is filed")

	var year_rollover := WorldState.new()
	year_rollover.year = 1200
	year_rollover.period = 11
	year_rollover.stockpiles[&"grain"] = 17
	year_rollover.advance_period()
	_check(year_rollover.year == 1201 and year_rollover.period == 0, "Period 12 should roll into the next year")
	_check(year_rollover.get_resource(&"grain") == 17, "Year rollover must preserve stockpiles")

	complicity_world.event_history.append({"event_id": &"future_event", "year": 1205})
	_check(not complicity_world.was_event_recent(&"future_event", 1200, 10), "Future-dated events must not count as recent")

	# Period expiry and form deadlines use one absolute, zero-based period clock.
	var deadline_world := _make_world()
	var deadline_actor: PersonEntity = deadline_world.get_person(&"clerk")
	var start_period := deadline_world.current_period_index()
	deadline_world.set_flag(&"temporary_world", start_period + 2)
	deadline_actor.flags[&"temporary_person"] = start_period + 2
	deadline_world.enqueue_form({
		"form_type": &"deadline_test",
		"due_period": start_period + 1,
	})
	deadline_world.enqueue_form({"form_type": &"no_deadline"})
	_check(deadline_world.has_flag(&"temporary_world", start_period), "Timed world flag should be active before expiry")
	_check(deadline_actor.has_flag(&"temporary_person", start_period), "Timed person flag should be active before expiry")
	deadline_world.advance_period()
	_check(deadline_world.has_flag(&"temporary_world", deadline_world.current_period_index()), "Timed world flag should remain active before its expiry period")
	_check(deadline_actor.has_flag(&"temporary_person", deadline_world.current_period_index()), "Timed person flag should remain active before its expiry period")
	_check(deadline_world.get_overdue_form_count() == 0, "A form should not be overdue during its due period")
	deadline_world.advance_period()
	_check(not deadline_world.has_flag(&"temporary_world", deadline_world.current_period_index()), "World flag should expire at its expiry period")
	_check(not deadline_actor.has_flag(&"temporary_person", deadline_world.current_period_index()), "Person flag should expire at its expiry period")
	_check(not deadline_world.world_flags.has(&"temporary_world"), "Expired world flags should be removed during period processing")
	_check(not deadline_actor.flags.has(&"temporary_person"), "Expired person flags should be removed during period processing")
	_check(deadline_world.get_overdue_form_count() == 1, "A form should become overdue after its due period passes")
	_check(deadline_world.has_pending_form(&"deadline_test"), "Overdue forms must remain pending")
	_check(deadline_world.has_pending_form(&"no_deadline"), "Forms without deadlines must remain unaffected")
	_check(deadline_world.resolve_form({"form_type": &"deadline_test"}, deadline_world.year), "An overdue form should remain resolvable")
	_check(deadline_world.resolved_forms.back().get("was_overdue", false), "Resolved archive should preserve whether the form was overdue")
	_check(deadline_world.resolved_forms.back().get("status", "") == "resolved", "Resolved form should receive resolved status")

	var follow_up_event := _make_event()
	follow_up_event.once_per_world = false
	follow_up_event.conditions = [_condition(&"year_in_range", {"min": 5000, "max": 6000})]
	var follow_up_world := _make_world()
	var follow_up_ctx := _make_context(follow_up_world)
	runner.resolve_outcome(follow_up_event, follow_up_event.outcomes[0], follow_up_ctx, true)
	_check(&"complicit" in follow_up_ctx.actor.traits, "Explicit follow-up bypass should skip ordinary eligibility conditions")


	# First Season at Uruk: both catechism answers, mentor bonuses, gated cases, and canal accounting.
	var temple_world := WorldState.new()
	var temple_actor := UrukSeeder.seed_campaign(temple_world, 32003200)
	_check(UrukCatechism.choose_path(temple_world, temple_actor, &"path_temple"), "Temple path should be accepted")
	_check(temple_actor.has_flag(&"path_temple", temple_world.current_period_index()), "Temple path flag should be permanent on the apprentice")
	_check(temple_world.get_person(&"ur_nanna").get_opinion(temple_actor.id) == 5, "Temple path should grant Ur-Nanna +5")
	_check(temple_world.get_person(&"nin_kasi").get_opinion(temple_actor.id) == 3, "Temple path should grant Nin-kasi +3")
	_check(temple_world.has_pending_form(&"pension_roll"), "Temple path should open the brewery account docket")
	_check(UrukCatechism.choose_mentor(temple_world, temple_actor, &"nin_kasi"), "Nin-kasi should be a valid mentor")
	_check(temple_actor.skills.get_level(&"rhetoric") == 1, "Nin-kasi mentorship should add one Rhetoric")
	_check(&"diplomatic" in temple_actor.traits, "Nin-kasi mentorship should add diplomatic")
	_check(temple_world.get_person(&"nin_kasi").get_opinion(temple_actor.id) == 8, "Mentor choice should add +5 opinion on top of path standing")

	var brewer_case: EventTemplate = registry.get_event(&"case_02_brewers_reckoning")
	_check(brewer_case != null, "Registry should load Case 2")
	var temple_ctx := _make_context(temple_world)
	temple_ctx.actor = temple_actor
	temple_ctx.year = temple_world.year
	temple_ctx.era = registry.get_era(&"uruk_storehouse")
	_check(runner.is_eligible(brewer_case, temple_ctx), "Case 2 should pass Temple path, office, and docket conditions")
	runner.resolve_outcome(brewer_case, brewer_case.outcomes[0], temple_ctx)
	_check(temple_world.get_resource(&"canal_progress") == 5, "Honest brewery arithmetic should advance Canal Cut by five")
	_check(temple_world.get_person(&"nin_kasi").get_opinion(temple_actor.id) == 14, "Honest brewery arithmetic should improve Nin-kasi by six")
	_check(temple_world.resolved_forms.back().get("disposition", "") == "rectified_subtotal_allocation_pending", "Honest brewery arithmetic should resolve the pension docket")

	var commingled_world := WorldState.new()
	var commingled_actor := UrukSeeder.seed_campaign(commingled_world, 32003200)
	UrukCatechism.choose_path(commingled_world, commingled_actor, &"path_temple")
	UrukCatechism.choose_mentor(commingled_world, commingled_actor, &"shuruppak_ilu")
	var commingled_ctx := _make_context(commingled_world)
	commingled_ctx.actor = commingled_actor
	commingled_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(brewer_case, brewer_case.outcomes[1], commingled_ctx)
	_check(commingled_world.get_resource(&"canal_progress") == 0, "Commingled malt should leave Canal Cut progress unchanged")
	_check(&"complicit" in commingled_actor.traits, "Commingled malt should mark the apprentice complicit")
	_check(commingled_world.has_flag(&"entangled_brewery_accounts", commingled_world.current_period_index()), "Commingled malt should set the four-period account flag")

	var harsh_world := WorldState.new()
	var harsh_actor := UrukSeeder.seed_campaign(harsh_world, 32003200)
	UrukCatechism.choose_path(harsh_world, harsh_actor, &"path_temple")
	UrukCatechism.choose_mentor(harsh_world, harsh_actor, &"utu_mansum")
	var harsh_ctx := _make_context(harsh_world)
	harsh_ctx.actor = harsh_actor
	harsh_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(brewer_case, brewer_case.outcomes[2], harsh_ctx)
	_check(harsh_world.get_resource(&"canal_progress") == 0, "Harsh brewery closure should not advance Canal Cut")
	_check(harsh_world.has_flag(&"thirsty_diggers", harsh_world.current_period_index()), "Harsh brewery closure should set thirsty diggers for two periods")
	_check(&"callous" in harsh_actor.traits, "Harsh brewery closure should add callous")

	var landing_world := WorldState.new()
	var landing_actor := UrukSeeder.seed_campaign(landing_world, 32003200)
	UrukCatechism.choose_path(landing_world, landing_actor, &"path_landing")
	_check(landing_actor.has_flag(&"path_landing", landing_world.current_period_index()), "Landing path flag should be permanent on the apprentice")
	_check(landing_world.get_person(&"enlil_kisu").get_opinion(landing_actor.id) == 5, "Landing path should grant Enlil-kisu +5")
	_check(landing_world.get_person(&"geme_inana").get_opinion(landing_actor.id) == 3, "Landing path should grant Geme-Inana +3")
	_check(landing_world.has_pending_form(&"consignment_receipt"), "Landing path should open the receiving docket")
	var landing_case_context := _make_context(landing_world)
	landing_case_context.actor = landing_actor
	landing_case_context.era = registry.get_era(&"uruk_storehouse")
	var sealed_event: EventTemplate = registry.get_event(&"case_01_sealed_vessel")
	_check(sealed_event != null, "Registry should load Case 1")
	runner.resolve_outcome(sealed_event, sealed_event.outcomes[0], landing_case_context)
	_check(landing_world.get_resource(&"canal_progress") == 5, "Accepted cracked vessel should advance Canal Cut by five")
	_check(landing_world.resolved_forms.back().get("disposition", "") == "quarantine_cracked_vessel", "Accepted vessel should resolve the receiving docket")
	var rejected_world := WorldState.new()
	var rejected_actor := UrukSeeder.seed_campaign(rejected_world, 32003200)
	UrukCatechism.choose_path(rejected_world, rejected_actor, &"path_landing")
	rejected_world.modify_resource(&"canal_progress", 5)
	var rejected_context := _make_context(rejected_world)
	rejected_context.actor = rejected_actor
	rejected_context.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(sealed_event, sealed_event.outcomes[1], rejected_context)
	_check(rejected_world.get_resource(&"canal_progress") == 0, "Rejected consignment should subtract five Canal Cut progress")

	var canal_bounds := WorldState.new()
	canal_bounds.modify_resource(&"canal_progress", 150)
	_check(canal_bounds.get_resource(&"canal_progress") == 100, "Canal Cut progress should cap at 100")
	canal_bounds.modify_resource(&"canal_progress", -150)
	_check(canal_bounds.get_resource(&"canal_progress") == 0, "Canal Cut progress should not fall below zero")


	var south_case: EventTemplate = registry.get_event(&"case_15_south_court")
	var south_honest_world := WorldState.new()
	var south_honest_actor := UrukSeeder.seed_campaign(south_honest_world, 71)
	south_honest_world.period = 6
	var south_honest_ctx := _make_context(south_honest_world)
	south_honest_ctx.actor = south_honest_actor
	south_honest_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(south_case, south_case.outcomes[0], south_honest_ctx)
	_check(south_honest_world.get_resource(&"canal_progress") == 5, "Honest South Court discrepancy should add five Canal Cut progress")

	var south_forged_world := WorldState.new()
	var south_forged_actor := UrukSeeder.seed_campaign(south_forged_world, 72)
	south_forged_world.period = 6
	var south_forged_ctx := _make_context(south_forged_world)
	south_forged_ctx.actor = south_forged_actor
	south_forged_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(south_case, south_case.outcomes[1], south_forged_ctx)
	_check(south_forged_world.get_resource(&"canal_progress") == 0, "Overwriting the threshold tally should leave Canal Cut progress unchanged")

	var south_penalty_world := WorldState.new()
	var south_penalty_actor := UrukSeeder.seed_campaign(south_penalty_world, 73)
	south_penalty_world.period = 6
	var south_penalty_ctx := _make_context(south_penalty_world)
	south_penalty_ctx.actor = south_penalty_actor
	south_penalty_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(south_case, south_case.outcomes[2], south_penalty_ctx)
	_check(south_penalty_world.get_resource(&"canal_progress") == 0, "Docking the carrier crew should leave Canal Cut progress unchanged")
	_check(south_penalty_world.has_flag(&"canal_crew_slowdown", south_penalty_world.current_period_index()), "Docking the carrier crew should slow canal stone transport for two periods")

	# The four mentor records each add exactly one skill level, the named trait, and five standing.
	var mentor_cases: Array = [
		[&"shuruppak_ilu", &"arithmetic", &"exacting", 1, 5],
		[&"utu_mansum", &"law", &"stubborn", 1, 0],
		[&"enlil_kisu", &"stewardship", &"protective", 0, 0],
		[&"nin_kasi", &"rhetoric", &"diplomatic", 0, 0]
	]
	for mentor_case in mentor_cases:
		var mentor_world := WorldState.new()
		var mentor_actor := UrukSeeder.seed_campaign(mentor_world, 88)
		var mentor_id: StringName = mentor_case[0]
		var mentor_skill: StringName = mentor_case[1]
		var mentor_trait: StringName = mentor_case[2]
		var starting_level: int = mentor_case[3]
		var starting_opinion: int = mentor_case[4]
		_check(UrukCatechism.choose_mentor(mentor_world, mentor_actor, mentor_id), "Each authored mentor should be selectable")
		_check(mentor_actor.skills.get_level(mentor_skill) == starting_level + 1, "Each mentor should add exactly one level in the named skill")
		_check(mentor_trait in mentor_actor.traits, "Each mentor should grant the named trait")
		_check(mentor_world.get_person(mentor_id).get_opinion(mentor_actor.id) == starting_opinion + 5, "Each mentor should gain five opinion of the apprentice")


	# Phase 8B: Quayside Stoppage uses the live event condition/scheduler path.
	var quayside_template: EventTemplate = registry.get_event(&"challenge_quayside_stoppage")
	_check(quayside_template != null, "Registry should load the Quayside Stoppage definition")
	var quayside_world := WorldState.new()
	var quayside_actor := UrukSeeder.seed_campaign(quayside_world, 32003200)
	var quayside_ctx := _make_context(quayside_world)
	quayside_ctx.actor = quayside_actor
	quayside_ctx.year = quayside_world.year
	quayside_ctx.era = registry.get_era(&"uruk_storehouse")
	var quayside_scheduler := EventScheduler.new(runner)
	quayside_world.period = 0
	quayside_world.get_person(&"enlil_kisu").set_opinion(quayside_actor.id, -15)
	quayside_world.set_flag(&"canal_crew_slowdown", quayside_world.current_period_index() + 11)
	_check(not runner.is_eligible(quayside_template, quayside_ctx), "Quayside challenge must not be eligible in Period 0")
	_check(quayside_scheduler.pick_next_event(quayside_world, quayside_actor, [quayside_template], quayside_ctx.era) == null, "Scheduler must not select Quayside challenge before Stores Season")
	quayside_world.period = 7
	_check(not runner.is_eligible(quayside_template, quayside_ctx), "Quayside challenge must not be eligible before Period 8")
	quayside_world.period = 8
	_check(runner.is_eligible(quayside_template, quayside_ctx), "Active slowdown should make Quayside eligible during Stores Season")
	_check(quayside_scheduler.pick_next_event(quayside_world, quayside_actor, [quayside_template], quayside_ctx.era) == quayside_template, "Scheduler should select eligible Quayside event from supplied template pool")
	quayside_world.period = 11
	_check(not runner.is_eligible(quayside_template, quayside_ctx), "Quayside challenge must stop being eligible after Period 10")
	quayside_world.period = 8
	quayside_world.enqueue_form({"form_type": &"succession_claim", "subject_id": &"quayside_stoppage"})
	var silver_before := quayside_world.get_resource(&"silver")
	runner.resolve_outcome(quayside_template, quayside_template.outcomes[0], quayside_ctx)
	_check(quayside_world.get_resource(&"silver") == silver_before - 4, "Silver conciliation should cost four shekels")
	_check(quayside_world.get_resource(&"canal_progress") == 25, "Silver conciliation should add 25 canal progress")
	_check(quayside_world.get_person(&"enlil_kisu").get_opinion(quayside_actor.id) == -3, "Silver conciliation should improve Enlil-kisu's standing by twelve")
	_check(not quayside_world.world_flags.has(&"canal_crew_slowdown"), "Silver conciliation should clear the slowdown")
	_check(quayside_world.resolved_forms.back().get("disposition", "") == "strike_settled_privately", "Silver conciliation should close the challenge docket")

	var force_world := WorldState.new()
	var force_actor := UrukSeeder.seed_campaign(force_world, 32003201)
	force_world.period = 8
	force_world.set_flag(&"canal_crew_slowdown", force_world.current_period_index() + 11)
	force_world.enqueue_form({"form_type": &"succession_claim", "subject_id": &"quayside_stoppage"})
	var force_ctx := _make_context(force_world)
	force_ctx.actor = force_actor
	force_ctx.year = force_world.year
	force_ctx.era = registry.get_era(&"uruk_storehouse")
	runner.resolve_outcome(quayside_template, quayside_template.outcomes[2], force_ctx)
	_check(force_world.get_resource(&"canal_progress") == 30, "Temple Guard outcome should add 30 canal progress")
	_check(force_world.has_flag(&"blood_on_the_quays", force_world.current_period_index()), "Temple Guard outcome should leave the twelve-period blood flag")
	_check(&"severe" in force_actor.traits, "Temple Guard outcome should mark the apprentice severe")
	_check(force_world.get_person(&"enlil_kisu").get_opinion(force_actor.id) == -30, "Temple Guard outcome should create lasting carrier hatred")

	# North-Bay assignment: definition loading, fail-closed lifecycle, and a real leaking roof.
	var roof_assignment := registry.get_assignment(&"north_bay_roof")
	_check(roof_assignment != null, "Registry should load the North-Bay AssignmentDef")
	_check(roof_assignment != null and roof_assignment.is_valid(), "North-Bay AssignmentDef should pass validation")
	_check(roof_assignment != null and roof_assignment.title == "North-Bay Roof Inspection", "Assignment title should match the authored docket")
	_check(roof_assignment != null and roof_assignment.employer == &"ur_nanna", "Ur-Nanna should own the North-Bay assignment")
	_check(roof_assignment != null and roof_assignment.compensation_amount == 5 and roof_assignment.compensation_resource == &"silver", "North-Bay assignment should pay five silver")
	var malformed_assignment := AssignmentDef.new()
	malformed_assignment.id = &"malformed_roof_test"
	_check(not registry.register_assignment(malformed_assignment), "Registry should reject a malformed AssignmentDef")

	var roof_world := WorldState.new()
	var roof_actor := UrukSeeder.seed_campaign(roof_world, 32003200)
	var barley_before_leak := roof_world.get_resource(&"barley")
	_check(roof_world.has_active_hazard(&"north_bay", &"roof_leak"), "Uruk seeding should establish the active North-Bay leak")
	roof_world.advance_period()
	_check(roof_world.get_resource(&"barley") == barley_before_leak - 1, "An elapsed period should spoil one measure of barley through the roof leak")
	_check(roof_world.get_hazard_total_lost(&"north_bay", &"roof_leak") == 1, "WorldState should retain cumulative barley lost to the leak")
	_check(roof_world.offer_assignment(&"north_bay_roof", &"ur_nanna"), "WorldState should offer the North-Bay assignment to the existing steward")
	_check(not roof_world.offer_assignment(&"north_bay_roof", &"ur_nanna"), "WorldState should prevent duplicate assignment offers")
	_check(roof_world.start_assignment(&"north_bay_roof"), "Player should be able to open an offered assignment")
	_check(roof_world.record_assignment_action(&"north_bay_roof", &"consult_steward", &"ur_nanna"), "Consultation should be recorded")
	_check(not roof_world.record_assignment_action(&"north_bay_roof", &"consult_steward"), "A consultation action should not be repeatable")
	var roof_progress := roof_world.get_assignment_state(&"north_bay_roof")
	var roof_consultations: Array = roof_progress.get("consultations", [])
	_check(roof_consultations.size() == 1 and roof_consultations[0]["person_id"] == &"ur_nanna", "Consultation log should preserve the consulted NPC and period")
	var roof_silver_before := roof_world.get_resource(&"silver")
	var roof_law_xp_before := int(roof_actor.skills.xp.get(&"law", 0))
	var roof_opinion_before := int(roof_world.get_person(&"ur_nanna").get_opinion(roof_actor.id))
	_check(not roof_world.complete_assignment(roof_assignment, roof_actor.id, &"leak_confirmed_repair_required", true), "Submission should fail until the physical inspection is recorded")
	_check(roof_world.record_assignment_action(&"north_bay_roof", &"inspect_beams"), "Physical inspection should be recorded")
	_check(roof_world.complete_assignment(roof_assignment, roof_actor.id, &"leak_confirmed_repair_required", true), "Complete evidence should allow assessment submission")
	_check(roof_world.get_resource(&"silver") == roof_silver_before + 5, "Accurate assessment should pay five silver")
	_check(int(roof_actor.skills.xp.get(&"law", 0)) == roof_law_xp_before + 25, "Accurate assessment should award 25 Law XP")
	_check(int(roof_world.get_person(&"ur_nanna").get_opinion(roof_actor.id)) == roof_opinion_before + 5, "Accurate assessment should improve Ur-Nanna's opinion by five")
	_check(bool(roof_world.get_assignment_state(&"north_bay_roof").get("rewarded", false)), "Assignment settlement should record that its reward was paid")
	_check(not roof_world.complete_assignment(roof_assignment, roof_actor.id, &"leak_confirmed_repair_required", true), "Completed assignment should not be settled twice")
	_check(String(roof_world.get_assignment_state(&"north_bay_roof").get("status", "")) == "completed", "Assignment lifecycle should retain its completed state")
	_check(roof_world.has_active_hazard(&"north_bay", &"roof_leak"), "Submitting an inspection must not falsely repair the roof")
	_check(roof_world.has_pending_form(&"north_bay_roof_repair"), "Supported roof inspection should open the repair follow-up docket")

	var repair_event: EventTemplate = registry.get_event(&"case_north_bay_roof_repair")
	_check(repair_event != null, "Registry should load the North-Bay roof repair event")
	var repair_ctx := _make_context(roof_world)
	repair_ctx.actor = roof_actor
	repair_ctx.era = registry.get_era(&"uruk_storehouse")
	_check(runner.is_eligible(repair_event, repair_ctx), "Repair docket should be eligible with its form and three labor units")
	var labor_before_repair := roof_world.get_resource(&"labor")
	runner.resolve_outcome(repair_event, repair_event.outcomes[0], repair_ctx)
	_check(not roof_world.has_active_hazard(&"north_bay", &"roof_leak"), "Repair outcome should deactivate the roof leak")
	_check(roof_world.get_resource(&"labor") == labor_before_repair - 3, "Repair outcome should consume three labor units")
	_check(roof_world.resolved_forms.back().get("disposition", "") == "roof_repaired", "Repair outcome should close the repair docket")

	var sealed_definition: EventTemplate = registry.get_event(&"case_01_sealed_vessel")
	_check(sealed_definition != null and sealed_definition.once_per_world, "Case 1 should not repeat after the sealed vessel is resolved")
	for event_id in [&"case_12_labor_tally", &"case_14_held_barley", &"case_03_two_claims_one_load"]:
		var authored_case: EventTemplate = registry.get_event(event_id)
		_check(authored_case != null, "Registry should load authored Uruk case %s" % event_id)
		_check(authored_case != null and authored_case.cooldown_years >= 1, "Uruk case %s should use a cooldown" % event_id)

	# Year 1 must produce real, cause-matched work rather than a quiet desk.
	var year_one_world := WorldState.new()
	UrukSeeder.seed_campaign(year_one_world, 32003200)
	var year_one_sim := WorldSimulator.new()
	for year_one_period in range(12):
		year_one_sim.advance_period(year_one_world)
	var year_one_generated_types: Dictionary = {}
	var roof_inspection_generated := false
	for generated_form in year_one_world.pending_forms + year_one_world.resolved_forms:
		if StringName(generated_form.get("generated_by", "")) != &"world_simulator":
			continue
		var generated_type := StringName(generated_form.get("form_type", ""))
		year_one_generated_types[generated_type] = true
		if generated_type == &"held_barley" and StringName(generated_form.get("generation_reason", "")) == &"roof_leak_inspection":
			roof_inspection_generated = true
	_check(year_one_generated_types.size() >= 2, "Year 1 simulation should generate at least two distinct form types")
	_check(roof_inspection_generated, "Active North-Bay roof leak should generate its matching Held Barley inspection in Year 1")
	_check(year_one_world.get_resource(&"labor") < 40, "Labor should not pin at its stockpile cap during Year 1")
	_check(year_one_world.get_resource(&"labor") <= 25, "Seasonal and institutional demand should bring labor into the intended working range by Year 1 end")

	# A low reserve with constrained workforce creates the competing transport/
	# storehouse allocation that Case 3 actually describes.
	var load_claim_world := WorldState.new()
	UrukSeeder.seed_campaign(load_claim_world, 98765)
	load_claim_world.pending_forms.clear()
	load_claim_world.stockpiles[&"barley"] = 100
	load_claim_world.stockpiles[&"labor"] = 12
	var load_claim_sim := WorldSimulator.new()
	load_claim_sim._generate_forms(load_claim_world)
	var load_claim_generated := false
	for generated_form in load_claim_world.pending_forms:
		if StringName(generated_form.get("form_type", "")) == &"load_claim" and StringName(generated_form.get("generation_reason", "")) == &"reserve_transport_allocation_conflict":
			load_claim_generated = true
	_check(load_claim_generated, "Reserve/transport allocation conflict should generate the Case 3 load_claim form")

	# -- World simulation: same seed, same world history; narrative RNG stays independent.
	var sim_world_a := WorldState.new()
	var sim_world_b := WorldState.new()
	UrukSeeder.seed_campaign(sim_world_a, 24680)
	UrukSeeder.seed_campaign(sim_world_b, 24680)
	var initial_sim_barley := sim_world_a.get_resource(&"barley")
	var sim_a := WorldSimulator.new()
	var sim_b := WorldSimulator.new()
	for sim_period in range(48):
		sim_world_a.rng_narrative.randi()
		sim_a.advance_period(sim_world_a)
		sim_b.advance_period(sim_world_b)
	_check(sim_world_a.year == -3196 and sim_world_a.period == 0, "WorldSimulator should advance the calendar exactly once per period")
	_check(sim_world_a.stockpiles == sim_world_b.stockpiles, "Narrative RNG consumption must not alter autonomous economy results")
	_check(int(sim_world_a.institutions[&"eanna_household"].get("activity_count", 0)) == 48, "Institutions should execute autonomous activity every period")
	_check(sim_world_a.get_resource(&"barley") != initial_sim_barley, "World simulation should materially change seeded barley over several years")
	var generated_sim_form := false
	for sim_form in sim_world_a.pending_forms:
		if StringName(sim_form.get("generated_by", "")) == &"world_simulator":
			generated_sim_form = true
	for sim_form in sim_world_a.resolved_forms:
		if StringName(sim_form.get("generated_by", "")) == &"world_simulator":
			generated_sim_form = true
	_check(generated_sim_form, "World simulation should generate forms from observed resource conditions")

	_finish()

func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_failures.append(msg)
		push_error("FAIL: %s" % msg)
	return cond

func _finish() -> void:
	_finished = true
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
