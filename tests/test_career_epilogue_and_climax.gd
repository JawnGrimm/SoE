extends SceneTree

const Evaluator = preload("res://systems/career_evaluator.gd")
const Dedication = preload("res://systems/canal_dedication_service.gd")
const DedicationEvent = preload("res://data/events/epic_canal_dedication.tres")

func _initialize() -> void:
	_test_climax_is_terminal()
	_test_career_metrics_and_epitaphs()
	_test_export_text()
	_test_dedication_choices()
	_test_event_definition_and_fresh_world()
	print("Career epilogue and canal climax checks passed.")
	quit()

func _test_climax_is_terminal() -> void:
	var world := WorldState.new()
	world.year = -3200
	world.stockpiles[&"canal_progress"] = 0
	world.epics[&"great_canal_cut"] = {"active": true, "progress": 0, "target": 100, "progress_resource": &"canal_progress"}
	assert(not Dedication.is_climax_due(world), "The boundary must not fire at the start of 3200 BCE.")
	world.year = -3160
	assert(Dedication.is_climax_due(world), "The BCE boundary should fire at 3160 BCE.")
	world.year = -3190
	world.stockpiles[&"canal_progress"] = 100
	world.epics[&"great_canal_cut"] = {"active": true, "progress": 100, "target": 100, "progress_resource": &"canal_progress"}
	assert(world.get_resource(&"canal_progress") == 100)
	assert(world.is_active_epic_complete())
	assert(Dedication.is_climax_due(world))

func _test_career_metrics_and_epitaphs() -> void:
	var world := WorldState.new()
	world.year = -3160
	world.cases_settled = 12
	world.silver_earned = 19
	world.world_flags[&"audit_exposure"] = 4
	world.world_flags[&"phantom_barley_measure"] = 1
	world.faction_standings[&"provincial_frontier"] = 5
	var actor := PersonEntity.new()
	actor.display_name = "Test Scribe"
	actor.resources[&"silver"] = 1
	actor.resources[&"debt"] = 12
	actor.flags[&"unpaid_upkeep"] = 3
	actor.traits.append(&"pliable")
	var corrupt := Evaluator.evaluate(world, actor)
	assert(int(corrupt.net_worth) == -14)
	assert(int(corrupt.total_cases_settled) == 12)
	assert(String(corrupt.epitaph).contains("Indentured") or String(corrupt.epitaph).contains("Silver-Handed"))
	actor.resources[&"debt"] = 0
	actor.flags[&"unpaid_upkeep"] = 0
	actor.traits.clear()
	actor.skills.levels[&"law"] = 2
	actor.relationships[&"shuruppak_ilu"] = {"trust": 10}
	world.world_flags.clear()
	world.world_flags[&"honest_corrections"] = 5
	var honest := Evaluator.evaluate(world, actor)
	assert(String(honest.epitaph).contains("Incorruptible"))
	assert(int(honest.integrity_score) > int(honest.corruption_score))

func _test_export_text() -> void:
	var world := WorldState.new()
	var actor := PersonEntity.new()
	actor.display_name = "Enlil-barni"
	var summary := Evaluator.evaluate(world, actor)
	var text := Evaluator.generate_export_text(summary)
	assert(text.contains("Enlil-barni"))
	assert(text.contains("years"))
	assert(text.contains(String(summary.epitaph)))
	assert(text.contains("Net worth"))

func _test_dedication_choices() -> void:
	var world := WorldState.new()
	var actor := PersonEntity.new()
	actor.skills.levels[&"law"] = 2
	actor.skills.levels[&"literacy"] = 2
	assert(Dedication.can_personal_seal(actor))
	assert(Dedication.apply_choice(world, actor, &"personal_seal"))
	assert(world.world_flags.has(&"canal_dedication_concluded"))
	assert(world.world_flags.has(&"official_seal_on_monument"))
	assert(not world.world_flags.has(&"canal_dedication_ready"))
	world.stockpiles[&"canal_progress"] = 100
	world.reset_active_epics()
	assert(world.get_resource(&"canal_progress") == 100, "Era reset must preserve dedicated canal progress.")
	assert(not bool(world.epics[&"great_canal_cut"].get("active", true)), "A dedicated canal must remain inactive.")
	assert(not Dedication.apply_choice(world, actor, &"honor_crews"))

func _test_event_definition_and_fresh_world() -> void:
	assert(DedicationEvent.id == &"epic_canal_dedication")
	assert(DedicationEvent.once_per_world)
	assert(DedicationEvent.outcomes.size() == 3)
	assert(DedicationEvent.conditions.size() == 1)
	var first_world := WorldState.new()
	first_world.world_flags[&"canal_dedication_concluded"] = 1
	var next_world := WorldState.new()
	assert(not next_world.world_flags.has(&"canal_dedication_concluded"), "A new career must not inherit the prior world's terminal flag.")
	assert(next_world.get_resource(&"canal_progress") == 0)
