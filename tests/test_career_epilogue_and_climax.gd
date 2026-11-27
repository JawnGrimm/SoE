extends SceneTree

const Evaluator = preload("res://systems/career_evaluator.gd")
const Dedication = preload("res://systems/canal_dedication_service.gd")

func _initialize() -> void:
	_test_climax_is_terminal()
	_test_career_metrics_and_epitaphs()
	_test_export_text()
	_test_dedication_choices()
	print("Career epilogue and canal climax checks passed.")
	quit()

func _test_climax_is_terminal() -> void:
	var world := WorldState.new()
	world.year = -3160
	world.stockpiles[&"canal_progress"] = 100
	world.epics[&"great_canal_cut"] = {"active": true, "progress": 100, "target": 100, "progress_resource": &"canal_progress"}
	assert(world.get_resource(&"canal_progress") == 100)
	assert(world.is_active_epic_complete())
	assert(world.year <= -3160)

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
	assert(not Dedication.apply_choice(world, actor, &"honor_crews"))
