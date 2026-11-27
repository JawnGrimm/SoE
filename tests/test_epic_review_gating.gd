extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := DefinitionRegistry.new()
	registry.load_defaults()
	var world := WorldState.new()
	var actor := UrukSeeder.seed_campaign(world, 771122)
	var simulator := WorldSimulator.new(registry)
	var epic_def := registry.get_epic(&"great_canal_cut")
	_check(epic_def != null, "Great Canal Cut EpicDef should load")
	simulator.advance_period(world)
	var state: Dictionary = world.epics.get(&"great_canal_cut", {})
	world.ensure_epic_review_state(&"great_canal_cut", epic_def)
	var board := AssignmentPipeline.generate_opportunities(world, actor, &"government")
	var reviews := _project_reviews(board)
	_check(reviews.size() == 1, "Initial local board should expose one Epic review")
	if not reviews.is_empty():
		world.resolve_epic_review(&"great_canal_cut", epic_def)
	board = pipeline.generate_opportunities(world, actor, &"government")
	_check(_project_reviews(board).is_empty(), "Review latch must clear immediately in the same period")

	# Old saves have no latch keys. Migration creates a single pending review,
	# then the ordinary resolution path persists the acknowledged stage.
	state = world.epics.get(&"great_canal_cut", {})
	state.erase("review_pending")
	state.erase("review_stage")
	state.erase("reviewed_stage")
	world.epics[&"great_canal_cut"] = state
	world.ensure_epic_review_state(&"great_canal_cut", epic_def)
	_check(bool(world.epics[&"great_canal_cut"].get("review_pending", false)), "Legacy active Epic state should migrate to one pending review")
	world.resolve_epic_review(&"great_canal_cut", epic_def)
	_check(not bool(world.epics[&"great_canal_cut"].get("review_pending", true)), "Migrated review should clear after acknowledgement")

	# Stage 1 is only offered after the 25% boundary is crossed.
	var progress_id := epic_def.progress_resource
	var sponsor: Dictionary = world.institutions.get(epic_def.sponsor_institution, {})
	var sponsor_stockpiles: Dictionary = sponsor.get("stockpiles", {})
	sponsor_stockpiles[&"barley"] = 1000
	sponsor_stockpiles[&"labor"] = 20
	sponsor["stockpiles"] = sponsor_stockpiles
	world.institutions[epic_def.sponsor_institution] = sponsor
	world.stockpiles[progress_id] = 24
	state = world.epics[&"great_canal_cut"]
	state["progress"] = 24
	state["review_pending"] = false
	state["reviewed_stage"] = 0
	world.epics[&"great_canal_cut"] = state
	simulator.advance_period(world)
	state = world.epics[&"great_canal_cut"]
	_check(int(state.get("review_stage", 0)) >= 1 and bool(state.get("review_pending", false)), "Crossing 25 percent should open the next stage review")

	# A new shortage opens a problem review; an unchanged shortage stays latched.
	sponsor_stockpiles[&"labor"] = 2
	sponsor["stockpiles"] = sponsor_stockpiles
	world.institutions[epic_def.sponsor_institution] = sponsor
	simulator.advance_period(world)
	state = world.epics[&"great_canal_cut"]
	_check(String(state.get("review_reason", "")) == "labor_shortage" and bool(state.get("review_pending", false)), "New labor shortage should open a problem review")
	world.resolve_epic_review(&"great_canal_cut", epic_def)
	simulator.advance_period(world)
	_check(not bool(world.epics[&"great_canal_cut"].get("review_pending", true)), "Persistent acknowledged shortage must not reopen every period")
	sponsor_stockpiles[&"labor"] = 20
	sponsor["stockpiles"] = sponsor_stockpiles
	world.institutions[epic_def.sponsor_institution] = sponsor
	simulator.advance_period(world)
	sponsor_stockpiles[&"labor"] = 2
	sponsor["stockpiles"] = sponsor_stockpiles
	world.institutions[epic_def.sponsor_institution] = sponsor
	simulator.advance_period(world)
	_check(bool(world.epics[&"great_canal_cut"].get("review_pending", false)), "A shortage relapse after recovery should open a new review")

	# Reviews belong to the sponsor's place, not the institution ID or player
	# location; traveling away hides the pending Uruk review.
	world.current_location_id = &"umma"
	board = AssignmentPipeline.generate_opportunities(world, actor, &"government")
	_check(_project_reviews(board).is_empty(), "Uruk-sponsored Epic review should be hidden while in Umma")

	if _failures.is_empty():
		print("PASS: test_epic_review_gating")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _project_reviews(opportunities: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for opportunity in opportunities:
		if StringName(opportunity.get("kind", &"")) == &"project_review":
			result.append(opportunity)
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
