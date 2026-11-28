extends SceneTree

const Visibility = preload("res://systems/consequence_visibility.gd")
const Pipeline = preload("res://systems/assignment_pipeline.gd")
const DocketGenerator = preload("res://systems/assignment_generator.gd")
const SaveCodec = preload("res://systems/save_codec.gd")

func _initialize() -> void:
	_test_ledger_formatting()
	_test_pipeline_payload_and_level_up()
	_test_procedural_opinion_names()
	_test_remote_courier()
	_test_remote_review_gate()
	_test_transient_view_does_not_mutate_save_data()
	print("Consequence visibility checks passed.")
	quit()

func _test_ledger_formatting() -> void:
	var consequences: Array[Dictionary] = [
		{"type": "opinion", "target_name": "Ur-Mes", "target_title": "Canal Bailiff", "delta": -2, "reason": "Ruled against conscription roll"},
		{"type": "xp", "skill": "law", "delta": 12},
		{"type": "level_up", "skill": "law", "new_level": 2},
		{"type": "silver", "delta": 2},
		{"type": "debt", "delta": 1},
		{"type": "exposure", "delta": 1},
		{"type": "trait", "name": "Pliable"},
		{"type": "flag", "name": "thirsty_diggers"}
	]
	var text := Visibility.format_ledger("The ruling is entered.", consequences)
	assert(text.begins_with("The ruling is entered.\n\nCONSEQUENCES RECORDED"), "Narrative must lead the ledger")
	assert(text.contains("Ur-Mes (Canal Bailiff): -2 Opinion"), "Named opinion delta must be visible")
	assert(text.contains("Law: +12 XP"), "XP must be visible in the consequence ledger: %s" % text)
	assert(text.contains("PROMOTION: LAW INCREASED TO LEVEL 2"), "Level-up must be visible in the consequence ledger: %s" % text)
	assert(text.contains("Purse: +2 Silver") and text.contains("Debt: +1 shekels"), "Silver and debt must be visible")
	assert(text.contains("Audit Exposure: +1") and text.contains("Acquired Trait: Pliable"), "Exposure and trait must be visible")
	assert(text.contains("Thirsty diggers"), "World flags must be humanized")


func _test_pipeline_payload_and_level_up() -> void:
	var world := WorldState.new()
	world.year = -3199
	world.current_location_id = &"uruk"
	var actor := PersonEntity.new()
	actor.id = &"consequence_scribe"
	actor.display_name = "Consequence Scribe"
	actor.resources[&"silver"] = 0
	actor.skills.xp[&"law"] = 95
	world.set_player(actor)
	var official := PersonEntity.new()
	official.id = &"consequence_official"
	official.display_name = "Ur-Mes"
	official.office_id = &"canal_bailiff"
	official.location_id = &"uruk"
	world.people[official.id] = official
	world.institutions[&"test_office"] = {"name": "Test Office", "place_id": &"uruk", "members": [official.id], "stockpiles": {}}
	var opportunity := {
		"id": &"test_consequence_assignment", "kind": &"ledger", "source_id": &"test_office",
		"title": "Test Account", "employer_id": official.id,
		"source_data": {"institution_id": &"test_office", "place_id": &"uruk"}
	}
	assert(Pipeline.begin(world, opportunity, actor), "Assignment fixture should begin")
	assert(Pipeline.perform_action(world, actor, opportunity.id, &"examine_records").get("success", false), "First inquiry should record")
	assert(Pipeline.perform_action(world, actor, opportunity.id, &"reconcile_accounts").get("success", false), "Second inquiry should record")
	var result := Pipeline.resolve(world, actor, opportunity.id, &"record")
	assert(result.get("success", false), "Ledger assessment should resolve")
	var consequences: Array = result.get("consequences", [])
	var saw_silver := false
	var saw_xp := false
	var saw_level := false
	var saw_opinion := false
	for item in consequences:
		match StringName(item.get("type", "")):
			&"silver":
				saw_silver = int(item.get("delta", 0)) == 2
			&"xp":
				saw_xp = StringName(item.get("skill", "")) == &"law" and int(item.get("delta", 0)) == 12
			&"level_up":
				saw_level = StringName(item.get("skill", "")) == &"law" and int(item.get("new_level", 0)) == 2
			&"opinion":
				saw_opinion = String(item.get("target_name", "")) == "Ur-Mes" and int(item.get("delta", 0)) == 1 and not String(item.get("reason", "")).is_empty()
	assert(saw_silver and saw_xp and saw_level and saw_opinion, "Resolve must return typed purse, XP, level-up, and named opinion consequences")

func _test_procedural_opinion_names() -> void:
	var left := PersonEntity.new()
	left.display_name = "Nin-Enlil"
	left.office_id = &"grain_clerk"
	var right := PersonEntity.new()
	right.display_name = "Ur-Mes"
	right.office_id = &"canal_bailiff"
	var left_entry := DocketGenerator.make_opinion_consequence(left, 3, "Protected storehouse exemption")
	var right_entry := DocketGenerator.make_opinion_consequence(right, -2, "Ruled against conscription roll")
	assert(left_entry.get("target_name", "") == "Nin-Enlil" and left_entry.get("delta", 0) == 3, "Procedural left opinion must name NPC and positive sign")
	assert(right_entry.get("target_name", "") == "Ur-Mes" and right_entry.get("delta", 0) == -2, "Procedural right opinion must name NPC and negative sign")

func _test_remote_courier() -> void:
	var epic := {"stalled": true, "active_problem": "labor_shortage", "review_pending": true}
	var courier := Visibility.remote_courier_text(epic, 13, 100)
	assert(courier.contains("URGENT DISPATCH FROM URUK"), "Stalled canal must trigger capital courier")
	assert(courier.contains("13 / 100") and courier.contains("Crews have struck"), "Courier must include progress and authored disruption prose")
	assert(Visibility.remote_courier_text({"stalled": false, "active_problem": "", "review_pending": false}, 13, 100).is_empty(), "Healthy project should not create urgent dispatch")

func _test_remote_review_gate() -> void:
	assert(Visibility.remote_review_required(&"uruk", &"umma", true), "Umma must require travel for pending Uruk review")
	assert(Visibility.remote_review_required(&"uruk", &"nippur", true), "Nippur must require travel for pending Uruk review")
	assert(not Visibility.remote_review_required(&"uruk", &"uruk", true), "Local Uruk review must remain openable")
	assert(not Visibility.remote_review_required(&"uruk", &"umma", false), "Acknowledged review must not be dispatched")
	var world := WorldState.new()
	world.current_location_id = &"umma"
	world.places[&"uruk"] = {"name": "Uruk", "parent": &""}
	world.places[&"umma"] = {"name": "Umma", "parent": &""}
	var actor := PersonEntity.new()
	actor.id = &"remote_review_scribe"
	actor.display_name = "Remote Scribe"
	world.set_player(actor)
	world.institutions[&"eanna_household"] = {"name": "Eanna", "place_id": &"uruk", "members": [], "stockpiles": {}}
	world.epics[&"great_canal_cut"] = {"active": true, "completed": false, "review_initialized": false, "review_pending": true, "review_stage": 1, "review_cycle": 0, "review_reason": "stage_reached", "progress": 13, "progress_resource": &"canal_progress", "target": 100, "sponsor_institution": &"eanna_household", "title": "Great Canal Cut"}
	var opportunities := Pipeline.generate_opportunities(world, actor)
	var found_remote := false
	for opportunity in opportunities:
		if StringName(opportunity.get("kind", "")) == &"project_review" and StringName(opportunity.get("source_id", "")) == &"great_canal_cut":
			found_remote = bool(opportunity.get("requires_travel", false)) and Array(opportunity.get("tags", [])).has("REQUIRES TRAVEL TO URUK")
	assert(found_remote, "Remote pending Great Canal Cut review must be exposed with travel gate and tag")


func _test_transient_view_does_not_mutate_save_data() -> void:
	var save_fixture := {"schema_version": 7, "world": {"period": 3}, "session": {"phase": "result"}}
	var before := save_fixture.duplicate(true)
	Visibility.format_ledger("Result", [{"type": "silver", "delta": 2}])
	Visibility.remote_courier_text({"stalled": true}, 13, 100)
	assert(save_fixture == before, "Consequence views must not mutate save payloads or schema")
	var world := WorldState.new()
	var actor := PersonEntity.new()
	actor.id = &"save_schema_scribe"
	actor.display_name = "Save Schema Scribe"
	world.set_player(actor)
	world.last_period_deltas.append({"category": "audit", "text": "Archive notice fixture"})
	var decoded := SaveCodec.decode_save(SaveCodec.encode_world(world))
	assert(bool(decoded.get("success", false)) and (decoded.get("world") as WorldState).last_period_deltas.size() == 1, "SaveCodec must round-trip period delta notices without schema changes")
