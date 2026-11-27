extends SceneTree

const Header = preload("res://ui/cedar_desk_header.gd")
const Docket = preload("res://ui/clay_docket_prop.gd")
const Archive = preload("res://ui/archive_stack_prop.gd")
const DeskLayout = preload("res://ui/cedar_desk_layout.gd")
const SaveCodec = preload("res://systems/save_codec.gd")

func _initialize() -> void:
	_test_header_formatting()
	_test_cuneiform_punches()
	_test_archive_badge()
	_test_workspace_rules_and_keyboard_equivalent()
	_test_transient_prop_state()
	print("Cedar Desk Overhaul checks passed.")
	quit()

func _test_header_formatting() -> void:
	assert(Header.format_purse(17, "silver") == "PURSE: 17 SILVER")
	assert(Header.format_arrears(3, 0) == "ARREARS: 3 DEBT")
	assert(Header.format_arrears(0, 2) == "ARREARS: 0 DEBT · UPKEEP 2")
	assert(Header.format_exposure(4) == "EXPOSURE: 4")
	assert(Header.format_exposure(0) == "EXPOSURE: 0")

func _test_cuneiform_punches() -> void:
	assert(Docket.ACTION_GLYPHS[&"examine_records"].glyph == "𒁾")
	assert(Docket.ACTION_GLYPHS[&"inspect_source"].glyph == "𒆠")
	assert(Docket.ACTION_GLYPHS[&"reconcile_accounts"].glyph == "𒂍")
	assert(Docket.ACTION_GLYPHS[&"consult_official"].glyph == "𒇽")
	assert(FileAccess.file_exists("res://assets/fonts/NotoSansCuneiform-Regular.ttf"))
	var prop := Docket.new()
	prop.reduced_motion = true
	root.add_child(prop)
	assert(prop.stamp_inquiry(&"examine_records"))
	assert(prop.impressions.size() == 1 and prop.impressions[0].glyph == "𒁾")
	assert(prop.stamp_inquiry(&"inspect_source"))
	assert(prop.impressions.size() == 2 and prop.impressions[1].glyph == "𒆠")
	prop.seal_verdict()
	assert(prop.verdict_is_sealed and prop.impressions.back().glyph == "𒁹")
	assert(not prop.stamp_inquiry(&"consult_official"), "A sealed docket must reject further inquiry stamps.")
	prop.queue_free()

func _test_archive_badge() -> void:
	assert(Archive.format_inbox(4, "dispatch") == "INBOX: 4 [DISPATCH]")
	assert(Archive.format_inbox(3) == "INBOX: 3")
	assert(Archive.format_inbox(0, "summons") == "INBOX: 0 [SUMMONS]")

func _test_workspace_rules_and_keyboard_equivalent() -> void:
	assert(DeskLayout.UPPER_WORKSPACE_RATIO == 58.0)
	assert(DeskLayout.LOWER_WORKSPACE_RATIO == 42.0)
	assert(DeskLayout.ACTION_BOX_RATIO == 62.0)
	assert(DeskLayout.CLAY_DOCKET_RATIO == 22.0)
	assert(DeskLayout.ARCHIVE_STACK_RATIO == 16.0)
	assert(not DeskLayout.evidence_visible("character_creation", false))
	assert(not DeskLayout.evidence_visible("case", true))
	assert(DeskLayout.evidence_visible("case", false))
	var queue_button := Button.new()
	queue_button.text = "Open Work Queue"
	queue_button.focus_mode = Control.FOCUS_ALL
	assert(queue_button.focus_mode == Control.FOCUS_ALL)
	queue_button.free()

func _test_transient_prop_state() -> void:
	var world := WorldState.new()
	world.year = -3199
	world.current_location_id = &"uruk"
	var actor := PersonEntity.new()
	actor.id = &"cedar_desk_test_scribe"
	actor.resources[&"silver"] = 5
	world.set_player(actor)
	var save_data: Dictionary = SaveCodec.encode_world(world)
	assert(not save_data.has("clay_docket") and not save_data.has("archive_stack_open"))
	var prop := Docket.new()
	prop.reduced_motion = true
	root.add_child(prop)
	prop.stamp_inquiry(&"examine_records")
	prop.seal_verdict()
	var after_ui_actions: Dictionary = SaveCodec.encode_world(world)
	assert(save_data == after_ui_actions, "Transient desk props must not alter the save payload.")
	prop.queue_free()
