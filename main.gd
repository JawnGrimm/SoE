extends Control

const CompoundContextScript = preload("res://systems/compound_context.gd")
const ConsequenceVisibilityScript = preload("res://systems/consequence_visibility.gd")

const AssignmentGeneratorScript = preload("res://systems/assignment_generator.gd")
const AssignmentNarratorScript = preload("res://systems/assignment_narrator.gd")
const DevCommandRouterScript = preload("res://systems/dev_command_router.gd")
const RouteNetworkScript = preload("res://systems/route_network.gd")
const TravelServiceScript = preload("res://systems/travel_service.gd")
const RegionalSurveyMapScript = preload("res://components/regional_survey_map.gd")
const WorkQueueOverlayScript = preload("res://ui/work_queue_overlay.gd")
const CedarDeskHeaderScript = preload("res://ui/cedar_desk_header.gd")
const ClayDocketPropScript = preload("res://ui/clay_docket_prop.gd")
const ArchiveStackPropScript = preload("res://ui/archive_stack_prop.gd")
const CedarDeskLayoutScript = preload("res://ui/cedar_desk_layout.gd")
const CUNEIFORM_FONT = preload("res://assets/Noto_Sans_Cuneiform,Noto_Sans_Egyptian_Hieroglyphs/Noto_Sans_Cuneiform/NotoSansCuneiform-Regular.ttf")
const CAMPAIGN_SEED: int = 32003200
const ROSTER_CAST: Array[StringName] = [&"shuruppak_ilu", &"utu_mansum", &"enlil_kisu", &"ur_nanna", &"nin_kasi", &"geme_inana", &"lu_nanshe"]
const FACTION_LABELS := {
	&"boatmens_guild": "⛵ Landing Boatmen",
	&"weavers_guild": "🧵 Weaver Guild",
	&"council_of_elders": "📜 City Elders"
}

class CylinderSealProp extends Control:
	func _draw() -> void:
		# Small illustrated seal prop until a dedicated seal texture is added.
		draw_rect(Rect2(9, 20, 42, 28), Color("#9a7747"))
		draw_rect(Rect2(9, 20, 42, 6), Color("#c5a16a"))
		draw_rect(Rect2(9, 42, 42, 6), Color("#6f512e"))
		draw_circle(Vector2(9, 34), 7, Color("#b58c55"))
		draw_circle(Vector2(51, 34), 7, Color("#6f512e"))
		draw_line(Vector2(18, 27), Vector2(43, 27), Color("#e0c28a"), 2.0)
		draw_line(Vector2(18, 40), Vector2(43, 40), Color("#5b4228"), 2.0)

class CanalJourneyTableau extends Control:
	var route_type: StringName = &"river"

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#d7bd8d"))
		draw_circle(Vector2(w * 0.82, h * 0.22), 23.0, Color("#d99c4d"))
		draw_rect(Rect2(0, h * 0.48, w, h * 0.52), Color("#87978a") if route_type == &"river" else Color("#b69a6b"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.48), Vector2(w * 0.22, h * 0.37), Vector2(w * 0.46, h * 0.5), Vector2(w * 0.7, h * 0.39), Vector2(w, h * 0.48), Vector2(w, h * 0.6), Vector2(0, h * 0.6)]), Color("#9a895f"))
		for reed_x in [w * 0.08, w * 0.15, w * 0.91, w * 0.96]:
			draw_line(Vector2(reed_x, h * 0.76), Vector2(reed_x - 5.0, h * 0.35), Color("#52664b"), 3.0)
			draw_line(Vector2(reed_x, h * 0.76), Vector2(reed_x + 7.0, h * 0.42), Color("#68734a"), 2.0)
		if route_type == &"river":
			draw_rect(Rect2(0, h * 0.64, w, h * 0.36), Color("#667f80"))
			for wave_x in range(25, int(w), 78):
				draw_line(Vector2(wave_x, h * 0.82), Vector2(wave_x + 36, h * 0.82), Color("#b7c2a8"), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.34, h * 0.7), Vector2(w * 0.68, h * 0.7), Vector2(w * 0.61, h * 0.84), Vector2(w * 0.4, h * 0.84)]), Color("#5b3824"))
			draw_line(Vector2(w * 0.51, h * 0.7), Vector2(w * 0.51, h * 0.28), Color("#4b3524"), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, h * 0.31), Vector2(w * 0.5, h * 0.64), Vector2(w * 0.64, h * 0.64)]), Color("#e4d2a6"))
			draw_circle(Vector2(w * 0.5, h * 0.62), 5.0, Color("#3d2a1c"))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.34, h * 0.76), Vector2(w * 0.72, h * 0.76), Vector2(w * 0.64, h * 0.86), Vector2(w * 0.4, h * 0.86)]), Color("#65452c"))
			draw_circle(Vector2(w * 0.43, h * 0.87), 10.0, Color("#3c2b1f"))
			draw_circle(Vector2(w * 0.65, h * 0.87), 10.0, Color("#3c2b1f"))
			draw_line(Vector2(w * 0.34, h * 0.75), Vector2(w * 0.7, h * 0.75), Color("#d6b783"), 4.0)

var runner: EventRunner
var scheduler: EventScheduler
var world_simulator: WorldSimulator
var route_network: RouteNetwork
var travel_service: TravelService
var survey_map: Variant
var journey_overlay: Control
var journey_tableau: CanalJourneyTableau
var journey_heading: Label
var journey_route_label: Label
var journey_narrative: Label
var journey_cost_label: Label
var journey_disembark_button: Button
var survey_button: Button
var world: WorldState
var actor: PersonEntity
var active_event: EventTemplate
var procedural_assignment: Dictionary = {}
var assignment_opportunities: Array[Dictionary] = []
var active_world_assignment_id: StringName = &""
var latest_investigation_scene: Dictionary = {}
var context: EventContext
var current_era: EraDef
var last_resolved_outcome: EventOutcome
var selected_path: StringName = &""
var creation_catalog: Dictionary = {}
var creation_selections := CharacterCreationSelections.new()
var creation_screen: int = 0
var phase := "case"
var last_opinion_deltas: Dictionary[StringName, int] = {}
var active_left_speaker_id: StringName = &""
var active_right_speaker_id: StringName = &""
var dev_command_router

var year_label: Label
var location_label: Label
var case_heading: Label
var dossier: RichTextLabel
var prompt_label: Label
var consequence_panel: PanelContainer
var archive_notice_active := false
var choices: VBoxContainer
var stamp_history_row: HFlowContainer
var dossier_label: Label
var canal_label: Label
var roster_box: VBoxContainer
var status_label: Label
var header_resource_label: Label
var local_stock_label: Label
var period_delta_label: Label
var work_queue_overlay: Control
var work_queue_button: Button
var evidence_workspace: Control
var period_delta_feed: Array[String] = []
var last_stock_snapshot: Dictionary = {}
var last_delta_period: int = -1
var docket_overlay: PanelContainer
var docket_motion_layer: Control
var archive_prop: Control
var cedar_header: CedarDeskHeader
var clay_docket: ClayDocketProp
var archive_stack: ArchiveStackProp
var upper_workspace_control: VBoxContainer
var stylus_prop: TextureRect
var heirloom_label: Label
var secret_toggle: Button
var secret_cavity: PanelContainer
var docket_home_position := Vector2.ZERO
var docket_home_set := false
var evidence_left: PanelContainer
var evidence_right: PanelContainer
var evidence_left_title: Label
var evidence_right_title: Label
var evidence_left_quote: Label
var evidence_right_quote: Label
var evidence_left_speaker: Label
var evidence_right_speaker: Label
var evidence_left_facts: RichTextLabel
var evidence_right_facts: RichTextLabel
var evidence_left_portrait: TextureRect
var evidence_right_portrait: TextureRect
var portrait_cache: Dictionary = {}
var choice_buttons: Array[Button] = []
var choice_stamp_labels: Dictionary = {}
var choice_locked := false

func _ready() -> void:
	_build_interface()
	_start_world()
	_register_dev_commands()
	if SaveManager.consume_load_on_start():
		var load_result := load_game()
		if not bool(load_result.get("success", false)):
			status_label.text = "LOAD FAILED / " + String(load_result.get("error", "Unknown error"))
	MusicDirector.play_for_phase(phase)


func _exit_tree() -> void:
	if dev_command_router != null:
		dev_command_router.unregister()

func _open_pause_menu() -> void:
	var pause_controller := get_node_or_null("PauseMenuController")
	if pause_controller != null and pause_controller.has_method("pause"):
		pause_controller.call("pause")

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	if upper_workspace_control != null:
		_set_evidence_visible(CedarDeskLayoutScript.evidence_visible(phase, survey_map != null and survey_map.visible))
	MusicDirector.play_for_phase(phase)


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = load("res://assets/desk/desk_tabletop.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)
	cedar_header = CedarDeskHeaderScript.new()
	cedar_header.custom_minimum_size.y = 42
	cedar_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cedar_header)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SCRIBE OF ERAS  /  REGIONAL COMPOUND"
	location_label = title
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#e5d2a8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	year_label = Label.new()
	year_label.add_theme_font_size_override("font_size", 14)
	year_label.add_theme_color_override("font_color", Color("#c4ad7c"))
	header.add_child(year_label)
	header_resource_label = Label.new()
	header_resource_label.visible = false
	header_resource_label.add_theme_font_size_override("font_size", 12)
	header_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_resource_label.add_theme_color_override("font_color", Color("#e5d2a8"))
	header_resource_label.tooltip_text = "Purse, debt, and current audit exposure. Values are live character/world state."
	root.add_child(header_resource_label)
	work_queue_button = Button.new()
	work_queue_button.text = "ARCHIVE / QUEUE"
	work_queue_button.tooltip_text = "Open Epics, Challenges, and Assignments. Keyboard: focus and press Enter."
	work_queue_button.custom_minimum_size = Vector2(142, 44)
	work_queue_button.add_theme_font_size_override("font_size", 12)
	work_queue_button.add_theme_stylebox_override("focus", _panel_style("#3a2b1d", "#f5e6d0"))
	work_queue_button.pressed.connect(_toggle_work_queue)
	header.add_child(work_queue_button)
	var menu_button := Button.new()
	menu_button.text = "☰  MENU"
	menu_button.tooltip_text = "Open the in-game menu (Esc)"
	menu_button.custom_minimum_size = Vector2(104, 44)
	menu_button.add_theme_font_size_override("font_size", 13)
	menu_button.add_theme_color_override("font_color", Color("#e5d2a8"))
	menu_button.add_theme_stylebox_override("normal", _panel_style("#3a2b1d", "#80653b"))
	menu_button.add_theme_stylebox_override("hover", _panel_style("#604326", "#d0ad70"))
	menu_button.add_theme_stylebox_override("pressed", _panel_style("#21170f", "#5b4228"))
	menu_button.pressed.connect(_open_pause_menu)
	header.add_child(menu_button)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = Color("#80653b")
	root.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var mat := PanelContainer.new()
	mat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mat.size_flags_stretch_ratio = 2.2
	mat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mat.add_theme_stylebox_override("panel", _panel_style("#00000000", "#00000000"))
	body.add_child(mat)
	var desk_box := VBoxContainer.new()
	desk_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_box.add_theme_constant_override("separation", 3)
	mat.add_child(desk_box)
	var desk_toolbar := HBoxContainer.new()
	desk_toolbar.add_theme_constant_override("separation", 8)
	desk_box.add_child(desk_toolbar)
	var desk_caption := Label.new()
	desk_caption.text = "THE DESK  /  CEDAR AND REED"
	desk_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk_caption.add_theme_font_size_override("font_size", 12)
	desk_caption.add_theme_color_override("font_color", Color("#a99570"))
	desk_toolbar.add_child(desk_caption)
	survey_button = Button.new()
	survey_button.text = "UNROLL SURVEY MAP"
	survey_button.tooltip_text = "Unroll the regional river-and-road survey on the cedar desk."
	survey_button.add_theme_font_size_override("font_size", 12)
	survey_button.add_theme_stylebox_override("normal", _panel_style("#3a2b1d", "#80653b"))
	survey_button.add_theme_stylebox_override("hover", _panel_style("#604326", "#d0ad70"))
	survey_button.pressed.connect(_toggle_regional_survey)
	desk_toolbar.add_child(survey_button)
	var upper_workspace := VBoxContainer.new()
	upper_workspace_control = upper_workspace
	upper_workspace.custom_minimum_size.y = 0
	upper_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper_workspace.size_flags_stretch_ratio = CedarDeskLayoutScript.UPPER_WORKSPACE_RATIO
	upper_workspace.add_theme_constant_override("separation", 6)
	desk_box.add_child(upper_workspace)
	var evidence_row := HBoxContainer.new()
	evidence_workspace = evidence_row
	evidence_row.custom_minimum_size.y = 0
	evidence_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_row.add_theme_constant_override("separation", 12)
	upper_workspace.add_child(evidence_row)
	evidence_left = _make_evidence_panel(evidence_row, "GRANARY TERRACES  /  TEMPLE", "Ur-Nanna", "The temple cellars are cold, dry, and exact. The gods demand honest measures.", &"ur_nanna")
	evidence_right = _make_evidence_panel(evidence_row, "RIVER QUAYS  /  LANDING", "Enlil-kisu", "The river road is dangerous and hungry. We respect the scribe who knows what a boatman endures.", &"enlil_kisu")
	var lower_workspace := HBoxContainer.new()
	lower_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_workspace.size_flags_stretch_ratio = CedarDeskLayoutScript.LOWER_WORKSPACE_RATIO
	lower_workspace.add_theme_constant_override("separation", 8)
	desk_box.add_child(lower_workspace)
	docket_motion_layer = Control.new()
	docket_motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	docket_motion_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docket_motion_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docket_motion_layer.size_flags_stretch_ratio = CedarDeskLayoutScript.ACTION_BOX_RATIO
	lower_workspace.add_child(docket_motion_layer)
	docket_overlay = PanelContainer.new()
	docket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tablet_style := StyleBoxTexture.new()
	tablet_style.texture = load("res://assets/desk/clay_docket.png")
	tablet_style.texture_margin_left = 96.0
	tablet_style.texture_margin_right = 96.0
	tablet_style.texture_margin_top = 82.0
	tablet_style.texture_margin_bottom = 82.0
	# Extend the clay surface beyond the control bounds so the visible tablet
	# fills the docket bay instead of leaving a dark halo around the asset.
	tablet_style.expand_margin_left = 14.0
	tablet_style.expand_margin_right = 14.0
	tablet_style.expand_margin_top = 12.0
	tablet_style.expand_margin_bottom = 12.0
	tablet_style.content_margin_left = 0.0
	tablet_style.content_margin_right = 0.0
	tablet_style.content_margin_top = 0.0
	tablet_style.content_margin_bottom = 0.0
	docket_overlay.add_theme_stylebox_override("panel", tablet_style)
	docket_motion_layer.add_child(docket_overlay)
	clay_docket = ClayDocketPropScript.new()
	clay_docket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clay_docket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clay_docket.size_flags_stretch_ratio = CedarDeskLayoutScript.CLAY_DOCKET_RATIO
	clay_docket.impression_added.connect(_on_clay_impression_added)
	lower_workspace.add_child(clay_docket)
	archive_stack = ArchiveStackPropScript.new()
	archive_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archive_stack.size_flags_stretch_ratio = CedarDeskLayoutScript.ARCHIVE_STACK_RATIO
	archive_stack.pressed.connect(_toggle_work_queue)
	lower_workspace.add_child(archive_stack)
	survey_map = RegionalSurveyMapScript.new()
	survey_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	survey_map.visible = false
	survey_map.travel_requested.connect(_on_survey_travel_requested)
	survey_map.close_requested.connect(_close_regional_survey)
	docket_motion_layer.add_child(survey_map)
	_build_journey_overlay()
	var tablet_content := MarginContainer.new()
	tablet_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tablet_content.add_theme_constant_override("margin_left", 74)
	tablet_content.add_theme_constant_override("margin_right", 74)
	tablet_content.add_theme_constant_override("margin_top", 48)
	tablet_content.add_theme_constant_override("margin_bottom", 48)
	docket_overlay.add_child(tablet_content)
	var tablet_scroll := ScrollContainer.new()
	tablet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tablet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tablet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tablet_content.add_child(tablet_scroll)
	var mat_box := VBoxContainer.new()
	mat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fill the scroll viewport when content fits; ScrollContainer still scrolls when its minimum height exceeds it.
	mat_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mat_box.add_theme_constant_override("separation", 7)
	tablet_scroll.add_child(mat_box)
	case_heading = Label.new()
	var title_font := FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 0.65
	case_heading.add_theme_font_override("font", title_font)
	case_heading.add_theme_font_size_override("font_size", 20)
	_apply_incised_text(case_heading)
	case_heading.visible = false
	mat_box.add_child(case_heading)
	dossier = RichTextLabel.new()
	dossier.bbcode_enabled = true
	dossier.fit_content = false
	dossier.scroll_active = false
	dossier.custom_minimum_size.y = 0
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.add_theme_font_size_override("normal_font_size", 15)
	_apply_incised_text(dossier)
	dossier.visible = false
	mat_box.add_child(dossier)
	consequence_panel = PanelContainer.new()
	consequence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consequence_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mat_box.add_child(consequence_panel)
	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.custom_minimum_size.y = 22
	_apply_incised_text(prompt_label)
	consequence_panel.add_child(prompt_label)
	stamp_history_row = HFlowContainer.new()
	stamp_history_row.custom_minimum_size.y = 0
	stamp_history_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamp_history_row.visible = false
	stamp_history_row.add_theme_constant_override("h_separation", 8)
	stamp_history_row.add_theme_constant_override("v_separation", 4)
	mat_box.add_child(stamp_history_row)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 5)
	mat_box.add_child(choices)

	# Clay docket and archive stack are now physical controls in the lower workspace.

	var compound := PanelContainer.new()
	compound.custom_minimum_size.x = 280
	compound.size_flags_horizontal = Control.SIZE_SHRINK_END
	compound.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compound.add_theme_stylebox_override("panel", _panel_style("#211d17", "#665238"))
	body.add_child(compound)
	var compound_scroll := ScrollContainer.new()
	compound_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compound_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compound_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	compound.add_child(compound_scroll)
	var compound_box := VBoxContainer.new()
	compound_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compound_box.add_theme_constant_override("separation", 10)
	compound_scroll.add_child(compound_box)
	var compound_title := Label.new()
	compound_title.text = "THE COMPOUND"
	compound_title.add_theme_font_size_override("font_size", 17)
	compound_title.add_theme_color_override("font_color", Color("#d6bd8b"))
	compound_box.add_child(compound_title)
	period_delta_label = Label.new()
	period_delta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	period_delta_label.add_theme_font_size_override("font_size", 12)
	period_delta_label.add_theme_color_override("font_color", Color("#c4ad7c"))
	compound_box.add_child(period_delta_label)
	var stores_title := Label.new()
	stores_title.text = "SCRIBE DOSSIER  /  IDENTITY & PURSE"
	stores_title.add_theme_font_size_override("font_size", 11)
	stores_title.add_theme_color_override("font_color", Color("#a99570"))
	compound_box.add_child(stores_title)
	dossier_label = Label.new()
	dossier_label.add_theme_font_size_override("font_size", 14)
	dossier_label.add_theme_color_override("font_color", Color("#e5d2a8"))
	compound_box.add_child(dossier_label)
	canal_label = Label.new()
	canal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canal_label.add_theme_font_size_override("font_size", 13)
	canal_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	compound_box.add_child(canal_label)
	local_stock_label = Label.new()
	local_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_stock_label.add_theme_font_size_override("font_size", 13)
	local_stock_label.add_theme_color_override("font_color", Color("#e5d2a8"))
	compound_box.add_child(local_stock_label)
	var roster_title := Label.new()
	roster_title.text = "FACTION STANDINGS  /  OPINION OF YOU"
	roster_title.add_theme_font_size_override("font_size", 11)
	roster_title.add_theme_color_override("font_color", Color("#a99570"))
	compound_box.add_child(roster_title)
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 5)
	compound_box.add_child(roster_box)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#a99570"))
	compound_box.add_child(status_label)

	var rim := PanelContainer.new()
	rim.custom_minimum_size.y = 48
	rim.size_flags_vertical = Control.SIZE_SHRINK_END
	rim.add_theme_stylebox_override("panel", _panel_style("#3a2b1d", "#9a7545"))
	root.add_child(rim)
	var rim_box := VBoxContainer.new()
	rim_box.add_theme_constant_override("separation", 5)
	rim.add_child(rim_box)
	var rim_row := HBoxContainer.new()
	rim_box.add_child(rim_row)
	heirloom_label = Label.new()
	heirloom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heirloom_label.add_theme_font_size_override("font_size", 12)
	heirloom_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	rim_row.add_child(heirloom_label)
	secret_toggle = Button.new()
	secret_toggle.text = "FALSE BOTTOM  ▾"
	secret_toggle.add_theme_font_size_override("font_size", 11)
	secret_toggle.add_theme_stylebox_override("normal", _panel_style("#604326", "#b18a52"))
	secret_toggle.add_theme_stylebox_override("hover", _panel_style("#795633", "#d0ad70"))
	secret_toggle.pressed.connect(_toggle_secret_cavity)
	rim_row.add_child(secret_toggle)
	secret_cavity = PanelContainer.new()
	secret_cavity.visible = false
	secret_cavity.scale = Vector2(1.0, 0.05)
	secret_cavity.pivot_offset = Vector2(0.0, 0.0)
	secret_cavity.add_theme_stylebox_override("panel", _panel_style("#171512", "#80653b"))
	rim_box.add_child(secret_cavity)
	var cavity_label := Label.new()
	cavity_label.text = "FALSE BOTTOM  /  No private reserve has been issued."
	cavity_label.add_theme_color_override("font_color", Color("#c6b99f"))
	secret_cavity.add_child(cavity_label)
	work_queue_overlay = WorkQueueOverlayScript.new()
	work_queue_overlay.connect("opportunity_selected", _on_queue_opportunity_selected)
	add_child(work_queue_overlay)

func _make_evidence_panel(parent: HBoxContainer, heading: String, speaker: String, quote: String, character_id: StringName = &"") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style("#2a2118", "#705b3a"))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _load_character_portrait(character_id)
	header.add_child(portrait)
	var title := Label.new()
	title.text = heading
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#d6bd8b"))
	header.add_child(title)
	var speaker_label := Label.new()
	speaker_label.text = speaker.to_upper()
	speaker_label.add_theme_font_size_override("font_size", 12)
	speaker_label.add_theme_color_override("font_color", Color("#a99570"))
	box.add_child(speaker_label)
	var quote_label := Label.new()
	quote_label.text = "“%s”" % quote
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	quote_label.add_theme_font_size_override("font_size", 15)
	quote_label.add_theme_color_override("font_color", Color("#e0d4bd"))
	box.add_child(quote_label)
	# Evidence can contain a complete resource ledger. Keep it inside the card's
	# allocated space and let the facts control scroll instead of growing the desk.
	var facts_label := RichTextLabel.new()
	facts_label.bbcode_enabled = false
	facts_label.fit_content = false
	facts_label.scroll_active = true
	facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts_label.custom_minimum_size.y = 0
	facts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	facts_label.add_theme_font_size_override("normal_font_size", 13)
	facts_label.add_theme_color_override("default_color", Color("#c7ad7e"))
	box.add_child(facts_label)
	if heading.begins_with("GRANARY"):
		evidence_left_title = title
		evidence_left_quote = quote_label
		evidence_left_speaker = speaker_label
		evidence_left_facts = facts_label
		evidence_left_portrait = portrait
	else:
		evidence_right_title = title
		evidence_right_quote = quote_label
		evidence_right_speaker = speaker_label
		evidence_right_facts = facts_label
		evidence_right_portrait = portrait
	return panel

func _load_character_portrait(character_id: StringName) -> Texture2D:
	if character_id == &"":
		return _make_seal_placeholder()
	if portrait_cache.has(character_id):
		return portrait_cache[character_id] as Texture2D

	var portrait_path := "res://assets/characters/%s_portrait.png" % String(character_id).to_lower()
	if ResourceLoader.exists(portrait_path):
		var source_texture := load(portrait_path) as Texture2D
		if source_texture != null:
			var portrait_image := source_texture.get_image()
			if portrait_image != null and not portrait_image.is_empty():
				# Center-crop and downsample once for the 64px evidence portrait.
				var source_size := portrait_image.get_size()
				var crop_size := mini(source_size.x, source_size.y)
				var crop_origin := Vector2i(
					floori(float(source_size.x - crop_size) / 2.0),
					floori(float(source_size.y - crop_size) / 2.0)
				)
				portrait_image = portrait_image.get_region(
					Rect2i(crop_origin, Vector2i(crop_size, crop_size))
				)
				portrait_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
				var badge_texture := ImageTexture.create_from_image(portrait_image)
				portrait_cache[character_id] = badge_texture
				return badge_texture

	var fallback := _make_seal_placeholder()
	portrait_cache[character_id] = fallback
	return fallback

func _make_seal_placeholder() -> Texture2D:
	var image := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	var center := Vector2(21.5, 21.5)
	for y in range(44):
		for x in range(44):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= 19.0:
				var color := Color("#b58c55") if distance >= 15.5 else Color("#70512f")
				if distance < 12.5:
					color = Color("#c9a66d")
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _set_evidence_portrait(left_id: StringName, right_id: StringName) -> void:
	if evidence_left_portrait != null:
		evidence_left_portrait.texture = _load_character_portrait(left_id)
	if evidence_right_portrait != null:
		evidence_right_portrait.texture = _load_character_portrait(right_id)

func _set_evidence_facts(left_text: String, right_text: String) -> void:
	if evidence_left_facts != null:
		evidence_left_facts.text = left_text
	if evidence_right_facts != null:
		evidence_right_facts.text = right_text

func _set_evidence_tension(left_delta: int, right_delta: int) -> void:
	_set_evidence_style(evidence_left, left_delta)
	_set_evidence_style(evidence_right, right_delta)

func _set_evidence_style(panel: PanelContainer, delta: int) -> void:
	if panel == null:
		return
	var border := "#705b3a"
	var fill := "#2a2118"
	if delta > 0:
		border = "#6f9b63"
		fill = "#293323"
	elif delta < 0:
		border = "#b76558"
		fill = "#35231f"
	panel.add_theme_stylebox_override("panel", _panel_style(fill, border))

func _toggle_secret_cavity() -> void:
	var opening := not secret_cavity.visible
	secret_toggle.text = "FALSE BOTTOM  ▴" if opening else "FALSE BOTTOM  ▾"
	if opening:
		secret_cavity.visible = true
		secret_cavity.modulate.a = 0.0
		secret_cavity.scale.y = 0.05
		AudioManager.play_docket_slide()
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(secret_cavity, "scale:y", 1.0, 0.22)
		tween.tween_property(secret_cavity, "modulate:a", 1.0, 0.22)
	else:
		AudioManager.play_docket_slide()
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(secret_cavity, "scale:y", 0.05, 0.16)
		tween.tween_property(secret_cavity, "modulate:a", 0.0, 0.16)
		tween.finished.connect(func() -> void: secret_cavity.visible = false)

func _animate_docket_in() -> void:
	if docket_overlay == null:
		return
	if not docket_home_set:
		docket_home_position = Vector2.ZERO
		docket_home_set = true
	docket_overlay.position = docket_home_position
	docket_overlay.pivot_offset = docket_overlay.size * 0.5
	docket_overlay.scale = Vector2.ONE
	docket_overlay.rotation_degrees = randf_range(-0.8, 0.8)
	docket_overlay.modulate.a = 0.0
	var target_position := docket_home_position
	docket_overlay.position = target_position + Vector2(-24.0, 5.0)
	AudioManager.play_book_open()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(docket_overlay, "position", target_position, 0.2)
	tween.tween_property(docket_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(docket_overlay, "rotation_degrees", 0.0, 0.2)

func _archive_docket() -> void:
	if docket_overlay == null:
		return
	AudioManager.play_book_close()
	var archive_target := Vector2(34.0, -8.0)
	if archive_prop != null:
		archive_target = archive_prop.global_position + archive_prop.size * 0.5
		archive_target -= docket_motion_layer.global_position + docket_overlay.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(docket_overlay, "position", archive_target, 0.24)
	tween.tween_property(docket_overlay, "scale", Vector2(0.18, 0.18), 0.24)
	tween.tween_property(docket_overlay, "modulate:a", 0.0, 0.24)
	tween.tween_property(docket_overlay, "rotation_degrees", -2.0, 0.24)
	await tween.finished
	docket_overlay.position = docket_home_position
	docket_overlay.scale = Vector2.ONE
	docket_overlay.rotation_degrees = 0.0

func _apply_incised_text(control: Control) -> void:
	var silt := Color("#392719")
	var recessed_shadow := Color("#1b120b", 0.62)
	control.add_theme_color_override("font_color", silt)
	control.add_theme_color_override("default_color", silt)
	control.add_theme_color_override("font_shadow_color", recessed_shadow)
	control.add_theme_color_override("font_outline_color", Color("#6f512e", 0.42))
	control.add_theme_constant_override("outline_size", 1)
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 1)

func _panel_style(fill: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _start_world() -> void:
	runner = EventRunner.new()
	scheduler = EventScheduler.new(runner)
	world_simulator = WorldSimulator.new()
	world = WorldState.new()
	actor = UrukSeeder.seed_campaign(world, CAMPAIGN_SEED, false, Registry.defs)
	_configure_route_network()
	creation_catalog = CharacterCreationResolver.load_catalog("res://data/character_creation/era_1_uruk.json")
	current_era = Registry.get_era(&"uruk_storehouse")
	context = EventContext.new()
	context.world = world
	context.actor = actor
	context.era = current_era
	context.year = world.year
	_refresh_compound()
	_show_character_creation_screen(0)

func can_save_game() -> bool:
	return world != null and world.get_player() != null and phase in ["case", "opportunity_board", "world_engagement"] and (active_event != null or not procedural_assignment.is_empty() or not assignment_opportunities.is_empty() or active_world_assignment_id != &"")

func save_game() -> Dictionary:
	if not can_save_game():
		return {"success": false, "error": "Save is available while the desk, an engagement, or an event is open."}
	var session := {
		"phase": phase,
		"active_event_id": String(active_event.id) if active_event != null else "",
		"procedural_assignment": procedural_assignment.duplicate(true),
		"assignment_opportunities": assignment_opportunities.duplicate(true),
		"active_world_assignment_id": String(active_world_assignment_id),
		"selected_path": String(selected_path),
		"survey_open": survey_map != null and survey_map.visible,
	}
	var result := SaveManager.save_game(world, session)
	status_label.text = "SAVE SEALED / CAMPAIGN RECORDED" if bool(result.get("success", false)) else "SAVE FAILED / " + String(result.get("error", "Unknown error"))
	return result

func load_game() -> Dictionary:
	var result := SaveManager.load_game()
	if not bool(result.get("success", false)):
		status_label.text = "LOAD FAILED / " + String(result.get("error", "Unknown error"))
		return result
	var restored_world: WorldState = result.world
	var restored_actor := restored_world.get_player()
	if restored_actor == null:
		return {"success": false, "error": "The save has no current player."}
	world = restored_world
	actor = restored_actor
	# Saves made before the intake mentor beat are already past the first workday.
	if not world.world_flags.has(&"first_workday_mentor_seen"):
		world.world_flags[&"first_workday_mentor_seen"] = -1
	_configure_route_network()
	current_era = Registry.get_era_for_year(world.year)
	context = EventContext.new()
	context.world = world
	context.actor = actor
	context.era = current_era
	context.year = world.year
	active_event = null
	procedural_assignment.clear()
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	last_resolved_outcome = null
	last_opinion_deltas.clear()
	var session: Dictionary = result.get("session", {})
	var saved_event_id := StringName(session.get("active_event_id", ""))
	if saved_event_id != &"":
		active_event = Registry.get_event(saved_event_id)
	var saved_assignment: Variant = session.get("procedural_assignment", {})
	if saved_assignment is Dictionary:
		procedural_assignment = saved_assignment.duplicate(true)
	var saved_opportunities: Variant = session.get("assignment_opportunities", [])
	if saved_opportunities is Array:
		for opportunity in saved_opportunities:
			if opportunity is Dictionary:
				assignment_opportunities.append(opportunity.duplicate(true))
	active_world_assignment_id = StringName(session.get("active_world_assignment_id", ""))
	selected_path = StringName(session.get("selected_path", ""))
	if active_world_assignment_id != &"":
		_show_world_engagement()
	elif String(session.get("phase", "")) == "opportunity_board" and not assignment_opportunities.is_empty():
		_show_assignment_board()
	elif active_event == null and procedural_assignment.is_empty():
		_schedule_next_case()
	else:
		_show_case()
	_refresh_compound()
	if bool(session.get("survey_open", false)):
		_open_regional_survey()
	status_label.text = "CAMPAIGN RESTORED / RECORD RESUMED"
	return {"success": true}

func _schedule_next_case() -> void:
	archive_notice_active = false
	_clear_stamp_history()
	var current_player := world.get_player()
	if current_player != null:
		actor = current_player
	context.actor = actor
	context.year = world.year
	current_era = Registry.get_era_for_year(world.year)
	context.era = current_era
	var active_era_id := current_era.id if current_era != null else &""
	if route_network == null or route_network.era_id != active_era_id:
		_configure_route_network()
	if not world.world_flags.has(&"first_workday_mentor_seen"):
		_show_first_workday_mentor()
		return
	_show_archive_notices()
	if world.epic_summon_pending and not world.epic_summon_issued:
		active_event = null
		procedural_assignment = AssignmentGeneratorScript.create_epic_summons()
		world.epic_summon_pending = false
		world.epic_summon_issued = true
		_refresh_compound()
		_show_case()
		return
	var event_templates: Array[EventTemplate] = []
	for definition in Registry.get_definitions("events"):
		if definition is EventTemplate:
			event_templates.append(definition as EventTemplate)
	active_event = scheduler.pick_next_event(world, actor, event_templates, current_era) if world.current_location_id == &"uruk" else null
	procedural_assignment.clear()
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	_refresh_compound()
	assignment_opportunities = AssignmentPipeline.generate_opportunities(world, actor, selected_path)
	if active_event != null:
		var is_challenge := String(active_event.id).begins_with("challenge_")
		assignment_opportunities.push_front({
			"id": StringName("work_event_%s_%d" % [active_event.id, world.current_period_index()]),
			"kind": &"challenge" if is_challenge else &"event",
			"source_id": active_event.id,
			"title": active_event.title,
			"summary": active_event.description,
			"priority": 90 if is_challenge else 100
		})
		while assignment_opportunities.size() > AssignmentPipeline.BOARD_SIZE:
			var remove_index := -1
			var lowest_priority := 2147483647
			for candidate_index in range(1, assignment_opportunities.size()):
				var candidate: Dictionary = assignment_opportunities[candidate_index]
				if StringName(candidate.get("kind", "")) in [&"event", &"challenge", &"project_review"]:
					continue
				var candidate_priority := int(candidate.get("priority", 0))
				if candidate_priority <= lowest_priority:
					lowest_priority = candidate_priority
					remove_index = candidate_index
			if remove_index < 0:
				break
			assignment_opportunities.remove_at(remove_index)
	if not assignment_opportunities.is_empty():
		_show_assignment_board()
	else:
		_show_end_of_queue()

func _show_first_workday_mentor() -> void:
	_clear_stamp_history()
	_clear_choices()
	_set_phase("first_workday_mentor")
	case_heading.text = "THE FIRST WORKDAY"
	prompt_label.text = "The mentor sets a tablet before you. No time passes. No assignment is issued."
	var mentor_id := creation_selections.get_answer(&"instruction_mentor")
	var lines: Dictionary = creation_catalog.get("first_workday_mentor_lines", {})
	dossier.text = String(lines.get(String(mentor_id), "The mentor places a blank tablet before you. “Make your mark.”"))
	_add_choice("Take the reed / begin work", _finish_first_workday_mentor)

func _finish_first_workday_mentor() -> void:
	if phase != "first_workday_mentor":
		return
	world.world_flags[&"first_workday_mentor_seen"] = -1
	_schedule_next_case()

func _show_character_creation_screen(screen: int) -> void:
	_set_evidence_visible(false)
	creation_screen = clampi(screen, 0, 8)
	_clear_stamp_history()
	_clear_choices()
	_set_phase("character_creation")
	case_heading.text = "𒂍  A LIFE IN THE MAKING  /  %02d" % creation_screen
	case_heading.add_theme_font_size_override("font_size", 20)
	dossier.visible = true
	dossier.text = ""
	_set_evidence_facts("", "")
	_set_evidence_tension(0, 0)

	var nav := HFlowContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_theme_constant_override("h_separation", 3)
	nav.add_theme_constant_override("v_separation", 3)
	choices.add_child(nav)
	var nav_labels := ["Origins", "Responsibilities", "Formative", "Entry", "Instruction", "Path", "Identity", "Biography"]
	for stage in range(8):
		var stage_screen := stage + 1
		var button := Button.new()
		button.text = "%d %s%s" % [stage_screen, nav_labels[stage], " ✓" if _creation_step_complete(stage_screen) else ""]
		button.disabled = creation_screen == stage_screen
		button.pressed.connect(_show_character_creation_screen.bind(stage_screen))
		button.add_theme_font_size_override("font_size", 10)
		nav.add_child(button)

	if creation_screen == 0:
		prompt_label.text = "BEFORE THE REGISTER"
		dossier.text = "Before dawn in the cool storehouse yard. Wet clay, spilled barley, sour beer. The clerk presses a reed into damp clay beside a tablet that concerns you.\n\nChoose how you are referred to before the intake begins."
		var pronoun_row := HBoxContainer.new()
		choices.add_child(pronoun_row)
		for pronoun in CharacterCreationSelections.PRONOUNS:
			var pronoun_button := Button.new()
			pronoun_button.text = String(pronoun).capitalize() + (" ✓" if creation_selections.pronouns == pronoun else "")
			pronoun_button.pressed.connect(_set_creation_pronouns.bind(pronoun))
			pronoun_row.add_child(pronoun_button)
		_add_choice("Begin the intake", _show_character_creation_screen.bind(1), creation_selections.pronouns == &"")
		return

	var stage_questions: Dictionary = {
		1: [&"origin"],
		2: [&"responsibility"],
		3: [&"formative_experience", &"formative_vulnerability"],
		4: [&"entry_into_scribal_work"],
		5: [&"instruction_mentor"],
		6: [&"professional_orientation"],
		7: [&"identity_response"]
	}
	if creation_screen >= 1 and creation_screen <= 7:
		for question_id in stage_questions[creation_screen]:
			var question := _creation_question(question_id)
			if question.is_empty():
				continue
			prompt_label.text = String(question.get("prompt", ""))
			dossier.text += (String(question.get("title", "")) + "\n\n")
			for answer in question.get("answers", []):
				var answer_id := StringName(answer.get("id", ""))
				var label := String(answer.get("title", ""))
				if creation_selections.get_answer(question_id) == answer_id:
					label = "✓  " + label
				label += "\n" + String(answer.get("description", ""))
				_add_choice(label, _select_creation_answer.bind(question_id, answer_id))
		if creation_screen == 7:
			prompt_label.text = "The carrier drops wet, rotten, short-count grain. “Write it sound,” the carrier says. The clerk turns to you. “Well?”"
			var name_input := LineEdit.new()
			name_input.placeholder_text = "Your name"
			name_input.text = creation_selections.character_name
			name_input.text_changed.connect(_set_creation_name)
			name_input.custom_minimum_size.y = 38
			choices.add_child(name_input)
			var designation := String(creation_catalog.get("designation_by_origin", {}).get(String(creation_selections.get_answer(&"origin")), "compound entrant"))
			dossier.text += "\nREGISTER ENTRY\n" + creation_selections.character_name + " · " + designation
		_add_creation_back_next()
		return

	if creation_screen == 8:
		prompt_label.text = "The clerk reads the biography from memory, not from the tablet."
		var validation := CharacterCreationResolver.validate(creation_catalog, creation_selections)
		dossier.text = CharacterCreationResolver.build_biography(creation_catalog, creation_selections)
		var identity_answer := CharacterCreationResolver._find_answer(_creation_question(&"identity_response"), creation_selections.get_answer(&"identity_response"))
		var trait_fragment := String(identity_answer.get("biography", ""))
		if not trait_fragment.is_empty():
			dossier.text += "\n\nIDENTITY\n" + trait_fragment
		var clerk_comments := CharacterCreationResolver.build_collision_comments(creation_catalog, creation_selections)
		if not clerk_comments.is_empty():
			dossier.text += "\n\nCLERK'S NOTES\n" + "\n".join(clerk_comments)
		dossier.text += "\n\n" + String(creation_catalog.get("creation_narration", ""))
		if not bool(validation.get("valid", false)):
			dossier.text += "\n\nBEFORE CONFIRMING\n" + "\n".join(validation.get("errors", []))
		else:
			_add_choice("CONFIRM  /  BEGIN CAREER", _confirm_character_creation)
		_add_creation_back_next()

func _creation_question(question_id: StringName) -> Dictionary:
	for question in creation_catalog.get("questions", []):
		if StringName(question.get("id", "")) == question_id:
			return question
	return {}

func _creation_step_complete(screen: int) -> bool:
	match screen:
		1:
			return creation_selections.get_answer(&"origin") != &""
		2:
			return creation_selections.get_answer(&"responsibility") != &""
		3:
			return creation_selections.get_answer(&"formative_experience") != &"" and creation_selections.get_answer(&"formative_vulnerability") != &""
		4:
			return creation_selections.get_answer(&"entry_into_scribal_work") != &""
		5:
			return creation_selections.get_answer(&"instruction_mentor") != &""
		6:
			return creation_selections.get_answer(&"professional_orientation") != &""
		7:
			return not creation_selections.character_name.strip_edges().is_empty() and creation_selections.pronouns != &"" and creation_selections.get_answer(&"identity_response") != &""
	return false

func _add_creation_back_next() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(row)
	if creation_screen > 0:
		var back := Button.new()
		back.text = "← BACK"
		back.pressed.connect(_show_character_creation_screen.bind(creation_screen - 1))
		row.add_child(back)
	if creation_screen < 8:
		var next := Button.new()
		next.text = "CONTINUE →"
		next.disabled = creation_screen < 7 and not _creation_step_complete(creation_screen)
		next.pressed.connect(_show_character_creation_screen.bind(creation_screen + 1))
		row.add_child(next)

func _select_creation_answer(question_id: StringName, answer_id: StringName) -> void:
	if phase != "character_creation":
		return
	if not creation_selections.select_answer(question_id, answer_id):
		return
	_show_character_creation_screen(creation_screen)

func _set_creation_name(value: String) -> void:
	creation_selections.set_character_name(value)

func _set_creation_pronouns(value: StringName) -> void:
	if creation_selections.set_pronouns(value):
		_show_character_creation_screen(creation_screen)

func _confirm_character_creation() -> void:
	if phase != "character_creation":
		return
	var result := CharacterCreationResolver.commit(creation_catalog, creation_selections, world, actor, current_era, runner.effects)
	if not bool(result.get("committed", false)):
		push_warning("Main: character creation could not commit: %s" % str(result.get("errors", [])))
		_show_character_creation_screen(8)
		return
	selected_path = creation_selections.get_answer(&"professional_orientation")
	world.local_path_dockets_settled = 0
	world.epic_summon_pending = false
	world.epic_summon_issued = false
	if String(creation_catalog.get("era_id", "")) == "uruk_storehouse":
		UrukSeeder.attach_player(world, actor)
	_refresh_compound()
	_schedule_next_case()

func _active_docket_payload() -> Dictionary:
	if not procedural_assignment.is_empty():
		return procedural_assignment
	if active_event == null:
		return {}
	var left_facts := ""
	var right_facts := ""
	for record in active_event.records:
		var line := "%s: %s" % [String(record.get("label", "RECORD")), String(record.get("value", ""))]
		if not String(record.get("note", "")).is_empty():
			line += " — " + String(record.get("note", ""))
		left_facts += line + "\n"
	return {
		"title": active_event.title,
		"left_card": {"title": active_event.evidence_left_title, "speaker_id": active_event.evidence_left_portrait, "quote": active_event.evidence_left_quote if not active_event.evidence_left_quote.is_empty() else active_event.description, "facts": left_facts.strip_edges()},
		"right_card": {"title": active_event.evidence_right_title, "speaker_id": active_event.evidence_right_portrait, "quote": active_event.evidence_right_quote if not active_event.evidence_right_quote.is_empty() else active_event.description, "facts": right_facts},
		"prompt": active_event.description + "\n\nWhat mark will you leave?",
		"choices": _authored_choices_payload()
	}

static func _is_outcome_disabled_for_actor(event_id: StringName, outcome: EventOutcome, personal_silver: int) -> bool:
	return OutcomeAffordability.is_outcome_disabled_for_actor(event_id, outcome, personal_silver)

func _authored_choices_payload() -> Array:
	var result: Array = []
	if active_event == null:
		return result
	for outcome in active_event.outcomes:
		var disabled := _is_outcome_disabled_for_actor(active_event.id, outcome, int(actor.resources.get(&"silver", 0)))
		result.append({"label": outcome.label, "result_title": outcome.title_override, "result_text": outcome.description_override, "effects": outcome.effects, "disabled": disabled})
	return result

func _show_assignment_board() -> void:
	_clear_stamp_history()
	_clear_choices()
	_set_phase("opportunity_board")
	var choices_payload: Array = []
	var callbacks: Array[Callable] = []
	var summaries := PackedStringArray()
	for index in range(assignment_opportunities.size()):
		var opportunity: Dictionary = AssignmentNarratorScript.translate_opportunity(assignment_opportunities[index])
		var label := "%s\n%s" % [String(opportunity.get("title", "Work")), String(opportunity.get("summary", "A matter requires attention."))]
		choices_payload.append({"label": label})
		callbacks.append(_select_assignment_opportunity.bind(index))
		summaries.append("%d. %s / %s" % [index + 1, String(opportunity.get("kind", "work")).replace("_", " ").to_upper(), String(opportunity.get("title", "Work"))])
	var payload := {
		"title": "THE SCRIBE'S DESK / %d OPPORTUNITIES" % assignment_opportunities.size(),
		"left_card": {"title": "THE LIVING WORLD", "speaker_id": &"", "quote": "The city has continued its business while you were away from the desk.", "facts": "YEAR: %s\nPERIOD: %d / 12\nPENDING FORMS: %d\nACTIVE HAZARDS: %d" % [CalendarFormatter.format_year(world.year), world.period + 1, world.pending_forms.size(), world.hazards.filter(func(h: Dictionary) -> bool: return bool(h.get("active", false))).size()]},
		"right_card": {"title": "AVAILABLE WORK", "speaker_id": &"shuruppak_ilu", "quote": "Choose the matter you will take responsibility for this period. The others remain in the world, whether you attend to them or not.", "facts": "\n".join(summaries)},
		"prompt": "%d matters have reached your desk. Select one engagement, or pass without penalty." % assignment_opportunities.size(),
		"choices": choices_payload
	}
	_render_docket_payload(payload, callbacks)
	_add_choice("Pass / End Period", _decline_opportunities)
	_refresh_compound()

func _select_assignment_opportunity(index: int) -> void:
	if phase != "opportunity_board" or index < 0 or index >= assignment_opportunities.size():
		return
	var opportunity := assignment_opportunities[index]
	if StringName(opportunity.get("kind", "")) == &"procedural_docket":
		procedural_assignment = (opportunity.get("source_data", {}) as Dictionary).duplicate(true)
		AssignmentGeneratorScript.record_selection(world, procedural_assignment)
		active_event = null
		AudioManager.play_docket_slide()
		_show_case()
		return
	if StringName(opportunity.get("kind", "")) in [&"event", &"challenge"]:
		active_event = Registry.get_event(StringName(opportunity.get("source_id", "")))
		if active_event == null:
			status_label.text = "EVENT COULD NOT BE OPENED / SOURCE MAY HAVE CHANGED"
			return
		AudioManager.play_docket_slide()
		_show_case()
		return
	active_event = null
	if bool(opportunity.get("requires_travel", false)) and StringName(opportunity.get("kind", "")) == &"project_review":
		status_label.text = "CAPITAL REVIEW / %s. [REQUIRES TRAVEL TO URUK] Open the regional survey map and book passage to convene the Stage Review." % String(opportunity.get("title", "Great Canal Cut"))
		return
	if not AssignmentPipeline.begin(world, opportunity, actor):
		if bool(opportunity.get("requires_travel", false)):
			var dispatch_place := StringName(opportunity.get("dispatch_destination_id", opportunity.get("place_id", "")))
			var dispatch_place_name := String(world.places.get(dispatch_place, {}).get("name", dispatch_place))
			status_label.text = "PROVINCIAL DISPATCH / TRAVEL TO %s TO ANSWER THE SUMMONS" % dispatch_place_name.to_upper()
		else:
			status_label.text = "WORK COULD NOT BE OPENED / SOURCE MAY HAVE CHANGED"
		return
	active_world_assignment_id = StringName(opportunity.get("id", ""))
	latest_investigation_scene.clear()
	AudioManager.play_docket_slide()
	_show_world_engagement()

func _show_world_engagement() -> void:
	var record := AssignmentPipeline.get_record(world, active_world_assignment_id)
	if record.is_empty():
		active_world_assignment_id = &""
		_show_assignment_board()
		return
	record = AssignmentNarratorScript.translate_record(record)
	if clay_docket != null:
		clay_docket.set_case_title(String(record.get("title", "Active case")))
	_clear_choices()
	_set_phase("world_engagement")
	var actions: Dictionary = record.get("actions", {})
	var evidence: Dictionary = record.get("evidence", {})
	if latest_investigation_scene.is_empty() and evidence.has(&"examine_records"):
		latest_investigation_scene = AssignmentNarratorScript.narrate_record_examination(record, actor, world, evidence[&"examine_records"])
	var evidence_lines := PackedStringArray()
	for action in AssignmentPipeline.INVESTIGATION_ACTIONS:
		var action_id: StringName = action.id
		if not evidence.has(action_id):
			continue
		var entry: Dictionary = evidence[action_id]
		var finding := String(entry.get("summary", "Finding recorded."))
		var facts := String(entry.get("facts", ""))
		evidence_lines.append("%s\n%s\n%s" % [String(action.label).to_upper(), finding, facts])
	var left_quote := String(record.get("summary", "A matter requires professional attention."))
	var employer := world.get_person(StringName(record.get("employer_id", "")))
	var right_quote := "The record is incomplete. Read it, reconcile the figures, hear the responsible official, and inspect the source before making your assessment."
	if not latest_investigation_scene.is_empty():
		right_quote = "The seal preserves the entry. It does not preserve the truth."
	var payload := {
		"title": String(record.get("title", "ASSIGNMENT")),
		"left_card": {"title": "WORLD SITUATION / %s" % String(record.get("kind", "work")).to_upper(), "speaker_id": &"", "quote": left_quote, "facts": "OPENED: %s / PERIOD %d" % [CalendarFormatter.format_year(world.year), world.period + 1]},
		"right_card": {"title": "RESPONSIBLE OFFICE", "speaker_id": employer.id if employer != null else &"", "quote": right_quote, "facts": "%d / %d inquiries spent%s\n\n%s" % [actions.size(), AssignmentPipeline.MAX_INVESTIGATION_ACTIONS, " — enter judgment" if actions.size() >= AssignmentPipeline.MAX_INVESTIGATION_ACTIONS else "", "\n\n".join(evidence_lines)]},
		"prompt": "Investigate the situation. Your skills affect what you can establish; your judgment determines what is entered.",
		"choices": []
	}
	var callbacks: Array[Callable] = []
	for action in AssignmentPipeline.INVESTIGATION_ACTIONS:
		var action_id: StringName = action.id
		var done := actions.has(action_id)
		payload.choices.append({"label": String(action.label)})
		callbacks.append(_world_assignment_action.bind(action_id))
		payload.choices.back()["disabled"] = done or actions.size() >= AssignmentPipeline.MAX_INVESTIGATION_ACTIONS
	_render_docket_payload(payload, callbacks)
	if not latest_investigation_scene.is_empty():
		dossier.visible = true
		dossier.scroll_active = true
		dossier.text = _format_investigation_scene(latest_investigation_scene)
		dossier.custom_minimum_size.y = 132
	if actions.size() >= 2:
		match StringName(record.get("kind", "")):
			&"form":
				_add_choice("Certify and close the form", _resolve_world_assignment.bind(&"certify"))
				_add_choice("Refer the matter for senior review", _resolve_world_assignment.bind(&"refer"))
				_add_choice("Defer the assessment", _resolve_world_assignment.bind(&"defer"))
			&"hazard":
				_add_choice("Allocate three labor and repair", _resolve_world_assignment.bind(&"repair"), world.get_resource(&"labor", "institution", "", &"eanna_household") < 3)
				_add_choice("Record the loss and defer repair", _resolve_world_assignment.bind(&"defer"))
			&"project_review":
				var sponsor_id := StringName(record.get("sponsor_institution", record.get("source_data", {}).get("sponsor_institution", &"eanna_household")))
				var has_emergency_stock := world.get_resource(&"barley", "institution", "", sponsor_id) >= 20 and world.get_resource(&"labor", "institution", "", sponsor_id) >= 2
				_add_choice("Authorize emergency rations and advance the cut (20 barley, 2 labor)", _resolve_world_assignment.bind(&"epic_emergency"), not has_emergency_stock)
				_add_choice("Halt work for audit; challenge the foreman's roll", _resolve_world_assignment.bind(&"epic_audit"))
				_add_choice("Certify the milestone uninspected / accept crew estimates", _resolve_world_assignment.bind(&"epic_certify"))
			&"pressure":
				var pressure_institution_id := StringName(record.get("source_data", {}).get("institution_id", record.get("source_id", &"")))
				var has_reserves := world.get_resource(&"barley", "institution", "", pressure_institution_id) >= 15 and world.get_resource(&"labor", "institution", "", pressure_institution_id) >= 15
				_add_choice("Authorize emergency drawdown from temple reserves (15 barley, 15 labor)", _resolve_world_assignment.bind(&"pressure_drawdown"), not has_reserves)
				_add_choice("Enforce strict rationing; reject extra requisitions", _resolve_world_assignment.bind(&"pressure_ration"))
				_add_choice("Falsify tally balance to conceal the deficit", _resolve_world_assignment.bind(&"pressure_falsify"))
			_:
				_add_choice("File the verified account", _resolve_world_assignment.bind(&"record"))
	_add_choice("Set this work aside", _abandon_world_assignment)
	_refresh_compound()

func _world_assignment_action(action_id: StringName) -> void:
	if phase != "world_engagement":
		return
	var result := AssignmentPipeline.perform_action(world, actor, active_world_assignment_id, action_id)
	if not bool(result.get("success", false)):
		status_label.text = String(result.get("message", "Action could not be recorded."))
		return
	AudioManager.play_stylus_mark()
	if clay_docket != null:
		clay_docket.stamp_inquiry(action_id)
	if action_id == &"examine_records":
		var record := AssignmentPipeline.get_record(world, active_world_assignment_id)
		var evidence: Dictionary = result.get("evidence", {})
		latest_investigation_scene = AssignmentNarratorScript.narrate_record_examination(record, actor, world, evidence)
	_show_world_engagement()

func _format_investigation_scene(scene: Dictionary) -> String:
	var lines := PackedStringArray()
	var heading := String(scene.get("heading", "A moment at the desk"))
	if not heading.is_empty():
		lines.append("— %s —" % heading)
	for beat in scene.get("beats", []):
		if not beat is Dictionary:
			continue
		var speaker := String(beat.get("speaker", ""))
		var text := String(beat.get("text", ""))
		if text.is_empty():
			continue
		match String(beat.get("kind", "")):
			"dialogue":
				lines.append("%s: “%s”" % [speaker, text])
			"internal_monologue":
				lines.append("THOUGHT — %s: %s" % [speaker, text])
			"document":
				lines.append("%s: %s" % [speaker, text])
			_:
				lines.append(text)
	var closing := String(scene.get("closing", ""))
	if not closing.is_empty():
		lines.append(closing)
	return "\n\n".join(lines)

func _resolve_world_assignment(verdict: StringName) -> void:
	if phase != "world_engagement":
		return
	var result := AssignmentPipeline.resolve(world, actor, active_world_assignment_id, verdict)
	if not bool(result.get("success", false)):
		status_label.text = String(result.get("message", "Assessment could not be filed."))
		_show_world_engagement()
		return
	active_world_assignment_id = &""
	procedural_assignment.clear()
	if clay_docket != null:
		clay_docket.seal_verdict()
	_seal_clay_docket()
	_show_procedural_result("ASSESSMENT SEALED", String(result.get("message", "The work is entered into the record.")), result.get("consequences", []))

func _abandon_world_assignment() -> void:
	if active_world_assignment_id == &"" or not world.assignments.has(active_world_assignment_id):
		return
	var record: Dictionary = world.assignments[active_world_assignment_id]
	record["status"] = "abandoned"
	world.assignments[active_world_assignment_id] = record
	active_world_assignment_id = &""
	_show_procedural_result("WORK SET ASIDE", "The matter remains in the world. No penalty is recorded for declining it.")

func _decline_opportunities() -> void:
	if phase != "opportunity_board":
		return
	_show_procedural_result("THE DESK IS PASSED", "No work is accepted this period. The world continues without waiting for your seal.")

func _show_case() -> void:
	_clear_stamp_history()
	_clear_choices()
	_set_phase("case")
	_render_docket_payload(AssignmentNarratorScript.translate_payload(_active_docket_payload()))

func _render_docket_payload(payload: Dictionary, callbacks: Array = []) -> void:
	if consequence_panel != null:
		consequence_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		prompt_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	_set_evidence_visible(true)
	case_heading.add_theme_font_size_override("font_size", 20)
	case_heading.text = "𒂍  " + String(payload.get("title", "Docket")).to_upper()
	dossier.visible = false
	dossier.text = ""
	_set_evidence_tension(0, 0)
	var left: Dictionary = payload.get("left_card", {})
	var right: Dictionary = payload.get("right_card", {})
	evidence_left_title.text = String(payload.get("client_name", left.get("title", "RECORD")))
	evidence_right_title.text = String(payload.get("opposing_name", right.get("title", "CLAIM")))
	var left_id := StringName(left.get("speaker_id", ""))
	var right_id := StringName(right.get("speaker_id", ""))
	active_left_speaker_id = left_id
	active_right_speaker_id = right_id
	var left_person := world.get_person(left_id)
	var right_person := world.get_person(right_id)
	evidence_left_speaker.text = left_person.display_name.to_upper() if left_person != null else String(left_id).to_upper()
	evidence_right_speaker.text = right_person.display_name.to_upper() if right_person != null else String(right_id).to_upper()
	evidence_left_quote.text = "“%s”" % String(left.get("quote", ""))
	evidence_right_quote.text = "“%s”" % String(right.get("quote", ""))
	evidence_left_facts.text = String(left.get("facts", ""))
	evidence_right_facts.text = String(right.get("facts", ""))
	_set_evidence_portrait(left_id, right_id)
	prompt_label.text = String(payload.get("prompt", "What mark will you leave?"))
	var docket_choices: Array = payload.get("choices", [])
	for index in range(docket_choices.size()):
		var callback: Callable = callbacks[index] if index < callbacks.size() else _resolve_choice.bind(index)
		_add_choice(String(docket_choices[index].get("label", "Record")), callback, bool(docket_choices[index].get("disabled", false)))
func _resolve_choice(index: int) -> void:
	if phase != "case":
		return
	var payload := _active_docket_payload()
	var docket_choices: Array = payload.get("choices", [])
	if index < 0 or index >= docket_choices.size():
		return
	if not procedural_assignment.is_empty():
		_resolve_procedural_choice(index, docket_choices[index])
		return
	if active_event == null:
		return
	var silver_before := int(actor.resources.get(&"silver", 0))
	var traits_before: Array[StringName] = actor.traits.duplicate()
	var before: Dictionary[StringName, int] = {}
	for person_id in _get_roster_person_ids():
		var person := world.get_person(person_id)
		if person != null:
			before[person_id] = int(person.get_opinion(actor.id))
	context.year = world.year
	context.era = Registry.get_era_for_year(world.year)
	last_resolved_outcome = active_event.outcomes[index]
	runner.resolve_outcome(active_event, active_event.outcomes[index], context)
	last_opinion_deltas.clear()
	for person_id in before:
		var person := world.get_person(person_id)
		var delta := person.get_opinion(actor.id) - before[person_id]
		if delta != 0:
			last_opinion_deltas[person_id] = delta
	_record_case_settlement(silver_before, traits_before)
	_seal_clay_docket()
	_show_result(active_event.outcomes[index])

func _resolve_procedural_choice(_index: int, choice: Dictionary) -> void:
	var effects: Dictionary = choice.get("effects", {})
	var pair_parts := String(procedural_assignment.get("npc_pair", "")).split("|")
	var left := world.get_person(StringName(pair_parts[0])) if pair_parts.size() > 0 else null
	var right := world.get_person(StringName(pair_parts[1])) if pair_parts.size() > 1 else null
	var silver_before := int(actor.resources.get(&"silver", 0))
	var traits_before: Array[StringName] = actor.traits.duplicate()
	var debt_before := int(actor.resources.get(&"debt", 0))
	var exposure_before := int(actor.flags.get(&"audit_exposure", 0))
	var skill_level_before := actor.skills.get_level(StringName(effects.get("skill", ""))) if StringName(effects.get("skill", "")) != &"" else 0
	var opinion_before: Dictionary[StringName, int] = {}
	for person_value in world.people.values():
		if person_value != null and person_value.id != actor.id:
			opinion_before[person_value.id] = person_value.get_opinion(actor.id)
	var actor_flags_before: Dictionary = actor.flags.duplicate(true)
	var world_flags_before: Dictionary = world.world_flags.duplicate(true)
	last_opinion_deltas.clear()
	var left_delta := int(effects.get("opinion_left", 0))
	var right_delta := int(effects.get("opinion_right", 0))
	var docket_kind := String(procedural_assignment.get("docket_kind", ""))
	var opinion_reason := String(choice.get("opinion_reason", choice.get("result_text", "Procedural docket: %s" % String(procedural_assignment.get("title", "")))))
	if docket_kind in ["local_path", "epic_summons"]:
		_apply_faction_opinion(StringName(procedural_assignment.get("client_faction", "")), left_delta, opinion_reason)
		_apply_faction_opinion(StringName(procedural_assignment.get("opposing_faction", "")), right_delta, opinion_reason)
	else:
		if left != null:
			left.change_opinion(actor.id, left_delta, opinion_reason, world.year)
			last_opinion_deltas[left.id] = left_delta
		if right != null:
			right.change_opinion(actor.id, right_delta, opinion_reason, world.year)
			last_opinion_deltas[right.id] = right_delta
	var resource_id := StringName(effects.get("resource", ""))
	var resource_delta := int(effects.get("resource_amount", 0))
	var resource_scope := String(effects.get("resource_scope", "institution"))
	var resource_institution := StringName(effects.get("resource_institution", "eanna_household"))
	var result_text := String(choice.get("result_text", "The entry is sealed."))
	var allocation_paid := resource_delta >= 0
	if resource_id != &"" and resource_delta != 0:
		var institutional_available := world.get_resource(resource_id, resource_scope, String(actor.id), resource_institution)
		if resource_delta < 0 and institutional_available < absi(resource_delta):
			allocation_paid = false
			result_text += " The allocation was not made: Eanna's stores cannot cover the cost."
			if bool(effects.get("repair_hazard", false)):
				result_text += " The hazard remains active."
		else:
			allocation_paid = world.modify_resource(resource_id, resource_delta, resource_scope, String(actor.id), resource_institution)
			if not allocation_paid:
				result_text += " The allocation was not made: the institutional ledger rejected it."
	if bool(effects.get("repair_hazard", false)) and allocation_paid:
		var repair_place := StringName(procedural_assignment.get("place_id", ""))
		var repair_id := StringName(procedural_assignment.get("hazard_id", ""))
		if world.has_active_hazard(repair_place, repair_id):
			world.repair_hazard(repair_place, repair_id)
	var skill_id := StringName(effects.get("skill", ""))
	var xp_amount := int(effects.get("xp", 0))
	if skill_id != &"":
		actor.skills.add_xp(skill_id, xp_amount)
	var trait_id := StringName(effects.get("trait", ""))
	if trait_id != &"" and trait_id not in actor.traits:
		actor.traits.append(trait_id)
	var epic_progress := int(effects.get("epic_progress", 0))
	if epic_progress != 0 and allocation_paid:
		var active_epic_id := world.get_active_epic_id()
		var active_epic_def := Registry.get_epic(active_epic_id)
		if active_epic_def == null and current_era != null:
			for epic_definition in Registry.all_epics():
				if epic_definition.era_id == current_era.id:
					active_epic_def = epic_definition
					break
		if active_epic_def != null:
			world.modify_resource(active_epic_def.progress_resource, epic_progress, "world")
	actor.memory.append({"memory_id": &"procedural_docket", "text": String(procedural_assignment.get("title", "")) + ": " + result_text, "year": world.year, "involved": pair_parts})
	_record_case_settlement(silver_before, traits_before)
	if docket_kind == "local_path":
		if world.record_local_path_docket():
			result_text += " Three local docket seals have brought an emergency requisition from the canal administration."
	var consequences: Array[Dictionary] = []
	if skill_id != &"" and xp_amount > 0:
		consequences.append({"type": "xp", "skill": skill_id, "delta": xp_amount})
		var level_after := actor.skills.get_level(skill_id)
		if level_after > skill_level_before:
			consequences.append({"type": "level_up", "skill": skill_id, "new_level": level_after})
	for person_value in world.people.values():
		if person_value == null or person_value.id == actor.id:
			continue
		var opinion_change := person_value.get_opinion(actor.id) - int(opinion_before.get(person_value.id, person_value.get_opinion(actor.id)))
		if opinion_change != 0:
			consequences.append(AssignmentGeneratorScript.make_opinion_consequence(person_value, opinion_change, opinion_reason))
	var silver_change := int(actor.resources.get(&"silver", 0)) - silver_before
	if silver_change != 0:
		consequences.append({"type": "silver", "delta": silver_change})
	var debt_change := int(actor.resources.get(&"debt", 0)) - debt_before
	if debt_change != 0:
		consequences.append({"type": "debt", "delta": debt_change})
	var exposure_change := int(actor.flags.get(&"audit_exposure", 0)) - exposure_before
	if exposure_change != 0:
		consequences.append({"type": "exposure", "delta": exposure_change})
	for new_trait in actor.traits:
		if new_trait not in traits_before:
			consequences.append({"type": "trait", "name": String(new_trait).capitalize()})
	for flag_key in actor.flags:
		if not actor_flags_before.has(flag_key) or actor_flags_before[flag_key] != actor.flags[flag_key]:
			consequences.append({"type": "flag", "name": String(flag_key)})
	for flag_key in world.world_flags:
		if not world_flags_before.has(flag_key) or world_flags_before[flag_key] != world.world_flags[flag_key]:
			consequences.append({"type": "flag", "name": String(flag_key)})
	_seal_clay_docket()
	var result_title := String(choice.get("result_title", "MARK MADE"))
	_show_procedural_result(result_title, result_text, consequences)

func _record_case_settlement(silver_before: int, traits_before: Array[StringName]) -> void:
	world.record_case_settlement(actor, silver_before, traits_before)

func _play_outcome_foley(index: int) -> void:
	match index:
		0:
			AudioManager.play_stylus_mark()
		1:
			AudioManager.play_seal_press()
		_:
			AudioManager.play_tablet_snap()

func _show_result(outcome: EventOutcome) -> void:
	if consequence_panel != null:
		consequence_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		prompt_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	last_resolved_outcome = outcome
	_clear_choices()
	_set_phase("result")
	case_heading.add_theme_font_size_override("font_size", 20)
	case_heading.text = "𒂍  MARK MADE"
	dossier.visible = false
	dossier.text = ""
	_set_evidence_facts("", "")
	_set_evidence_tension(0, 0)
	prompt_label.text = outcome.title_override + " — " + outcome.description_override
	_add_choice("End Period", _advance_period)
	_refresh_compound()

func _advance_period() -> void:
	if phase != "result" and phase != "end_of_queue":
		return
	_advance_period_once()


func _advance_period_once() -> bool:
	if world == null or world_simulator == null:
		return false
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	if clay_docket != null:
		clay_docket.impressions.clear()
		clay_docket.verdict_is_sealed = false
		clay_docket._refresh_grid()
		clay_docket.set_case_title("New period")
	_clear_stamp_history()
	world_simulator.advance_period(world)
	last_opinion_deltas.clear()
	if world.is_active_epic_complete() and not world.era_completion_started:
		_show_era_completion()
		return false
	_schedule_next_case()
	return true


func _register_dev_commands() -> void:
	if not OS.is_debug_build():
		return
	dev_command_router = DevCommandRouterScript.new()
	var callbacks := {
		"advance_periods": Callable(self, "_debug_advance_periods"),
		"inspect_world": Callable(self, "_debug_inspect_world"),
		"inspect_person": Callable(self, "_debug_inspect_person"),
		"adjust_resource": Callable(self, "_debug_adjust_resource"),
		"person_ids": Callable(self, "_debug_person_ids"),
		"resource_ids": Callable(self, "_debug_resource_ids"),
	}
	if not dev_command_router.register(LimboConsole, callbacks):
		push_warning("Main: SoE developer commands could not be registered.")


func _debug_advance_periods(count: int) -> Dictionary:
	if not OS.is_debug_build():
		return {"success": false, "error": "Developer commands are unavailable in release builds."}
	if world == null or world.get_player() == null:
		return {"success": false, "error": "Finish character creation before advancing the world from the console."}
	if phase == "era_complete":
		return {"success": false, "error": "Begin the next era before advancing the world again."}
	if phase not in ["result", "end_of_queue"]:
		return {"success": false, "error": "Advance from a result or an empty desk queue; finish the current case or engagement first."}
	if count < 1 or count > 120:
		return {"success": false, "error": "Period count must be between 1 and 120."}

	var advanced := 0
	for _index in range(count):
		var can_continue := _advance_period_once()
		advanced += 1
		if not can_continue:
			break
	var fast_forward_note := " Intervening desk offers were superseded without player resolution." if advanced > 1 else ""
	return {
		"success": true,
		"message": "Advanced %d period(s). Now %s, period %d / 12.%s%s" % [
			advanced,
			CalendarFormatter.format_year(world.year),
			world.period + 1,
			" Era Epic completed; advancement stopped." if world.era_completion_started else "",
			fast_forward_note
		]
	}


func _debug_inspect_world() -> Dictionary:
	if world == null:
		return {"success": false, "error": "WorldState is not initialized."}
	var active_hazards := 0
	for hazard in world.hazards:
		if bool(hazard.get("active", false)):
			active_hazards += 1
	var player := world.get_player()
	var active_epic := String(world.get_active_epic_id())
	return {
		"success": true,
		"message": "WORLD / %s period %d of 12 | player=%s | people=%d | institutions=%d | forms=%d pending / %d resolved | active_hazards=%d | active_epic=%s | world_stockpiles=%s" % [
			CalendarFormatter.format_year(world.year),
			world.period + 1,
			String(player.id) if player != null else "none",
			world.people.size(),
			world.institutions.size(),
			world.pending_forms.size(),
			world.resolved_forms.size(),
			active_hazards,
			active_epic if active_epic != "" else "none",
			str(world.stockpiles)
		]
	}


func _debug_inspect_person(person_id: String) -> Dictionary:
	if world == null:
		return {"success": false, "error": "WorldState is not initialized."}
	var person := world.get_person(StringName(person_id))
	if person == null:
		return {"success": false, "error": "No person has ID '%s'." % person_id}
	var skill_parts: Array[String] = []
	for skill_id in [&"literacy", &"arithmetic", &"law", &"rhetoric", &"intrigue", &"stewardship"]:
		skill_parts.append("%s:%d" % [String(skill_id), person.skills.get_level(skill_id)])
	return {
		"success": true,
		"message": "PERSON / %s (%s) | office=%s | traits=%s | skills=[%s] | resources=%s | relationships=%d | memories=%d" % [
			person.display_name,
			String(person.id),
			String(person.office_id) if person.office_id != &"" else "none",
			str(person.traits),
			", ".join(skill_parts),
			str(person.resources),
			person.relationships.size(),
			person.memory.size()
		]
	}


func _debug_adjust_resource(resource_id: String, amount: int, scope: String = "world", owner_id: String = "", institution_id: String = "") -> Dictionary:
	if world == null:
		return {"success": false, "error": "WorldState is not initialized."}
	if resource_id.strip_edges().is_empty():
		return {"success": false, "error": "Resource ID cannot be empty."}
	var resource_key := StringName(resource_id)
	var institution_key := StringName(institution_id)
	var before := world.get_resource(resource_key, scope, owner_id, institution_key)
	if not world.modify_resource(resource_key, amount, scope, owner_id, institution_key):
		return {"success": false, "error": "Resource adjustment was rejected. Check the scope, owner, institution, and available balance."}
	var after := world.get_resource(resource_key, scope, owner_id, institution_key)
	return {
		"success": true,
		"message": "RESOURCE / %s | scope=%s | %d -> %d (%+d)" % [resource_id, scope, before, after, amount]
	}


func _debug_person_ids() -> Array[String]:
	var ids: Array[String] = []
	if world == null:
		return ids
	for person_id in world.people.keys():
		ids.append(String(person_id))
	ids.sort()
	return ids


func _debug_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	if world == null:
		return ids
	for resource_id in world.stockpiles.keys():
		var world_resource_value := String(resource_id)
		if not ids.has(world_resource_value):
			ids.append(world_resource_value)
	for person in world.people.values():
		if person == null:
			continue
		for resource_id in person.resources.keys():
			var person_resource_value := String(resource_id)
			if not ids.has(person_resource_value):
				ids.append(person_resource_value)
	for institution in world.institutions.values():
		for resource_id in institution.get("stockpiles", {}).keys():
			var institution_resource_value := String(resource_id)
			if not ids.has(institution_resource_value):
				ids.append(institution_resource_value)
	ids.sort()
	return ids

func _show_procedural_result(result_title: String, result_text: String, consequences: Array = []) -> void:
	_clear_choices()
	_set_phase("result")
	case_heading.text = "𒂍  " + result_title.to_upper()
	dossier.visible = false
	dossier.text = ""
	_set_evidence_facts("", "")
	_set_evidence_tension(0, 0)
	prompt_label.text = ConsequenceVisibilityScript.format_ledger(result_text, consequences) if not consequences.is_empty() else result_text
	if consequence_panel != null:
		if not consequences.is_empty():
			var ledger_style := StyleBoxFlat.new()
			ledger_style.bg_color = Color("#302519")
			ledger_style.border_color = Color("#e0b85c")
			ledger_style.set_border_width_all(2)
			ledger_style.set_corner_radius_all(4)
			ledger_style.content_margin_left = 16
			ledger_style.content_margin_right = 16
			ledger_style.content_margin_top = 12
			ledger_style.content_margin_bottom = 12
			consequence_panel.add_theme_stylebox_override("panel", ledger_style)
			prompt_label.add_theme_color_override("font_color", Color("#fff0ce"))
		else:
			consequence_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			prompt_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	_add_choice("End Period", _advance_period)
	_refresh_compound()

func _show_era_completion() -> void:
	world.era_completion_started = true
	_set_phase("era_complete")
	_clear_choices()
	var standing_total := 0
	var standing_count := 0
	for person in world.people.values():
		if person != null and person.id != actor.id:
			standing_total += person.get_opinion(actor.id)
			standing_count += 1
	var standing := int(round(float(standing_total) / maxf(1.0, float(standing_count))))
	var trait_names := PackedStringArray()
	for trait_id in world.traits_gained:
		trait_names.append(String(trait_id))
	var traits_text := ", ".join(trait_names) if not trait_names.is_empty() else "none recorded"
	var completed_epic_id := world.get_active_epic_id()
	var completed_epic := Registry.get_epic(completed_epic_id)
	var completed_epic_title := completed_epic.title if completed_epic != null else "Era Epic"
	var completed_epic_progress := world.get_resource(completed_epic.progress_resource) if completed_epic != null else 0
	var completed_epic_target := completed_epic.target if completed_epic != null else 0
	var summary := "Year %s / %s\nCases settled: %d\n%s: %d / %d — COMPLETE\nSilver earned: %d\nTraits gained: %s\nCompound standing: %+d average opinion" % [CalendarFormatter.format_year(world.year), String(current_era.display_name if current_era != null else "Current Era"), world.cases_settled, completed_epic_title, completed_epic_progress, completed_epic_target, world.silver_earned, traits_text, standing]
	world.cedar_desk_log.append({"year": world.year, "era_id": current_era.id if current_era != null else &"", "title": "ERA EPIC: %s — COMPLETE" % completed_epic_title, "epic_id": completed_epic_id, "epic_progress": completed_epic_progress, "epic_target": completed_epic_target, "summary": summary, "cases_settled": world.cases_settled, "silver_earned": world.silver_earned, "traits_gained": world.traits_gained.duplicate(), "standing": standing})
	case_heading.text = "𒂍  ERA EPIC COMPLETE / " + completed_epic_title.to_upper()
	dossier.visible = true
	dossier.text = summary
	_set_evidence_facts("THE CAREER RECORD\nThe completed Epic is entered into the chronicle. The apprentice kept the measures and the names.", "THE INSTITUTION\nThe work stands on the record. The next shift inherits its consequences.")
	# Completion is an authored career verdict, never leftover testimony from
	# whichever docket happened to precede the final period.
	evidence_left_title.text = "CAREER VERDICT / ARCHIVE"
	evidence_right_title.text = "STOREHOUSE VERDICT / RESERVES"
	evidence_left_speaker.text = "SHURUPPAK-ILU"
	evidence_right_speaker.text = "UR-NANNA"
	evidence_left_quote.text = "“A record is only useful when it survives the hands that made it. Yours will.”"
	evidence_right_quote.text = "“The work stands, and the record names what it cost. That is competent work.”"
	_set_evidence_portrait(&"shuruppak_ilu", &"ur_nanna")
	_set_evidence_tension(0, 0)
	prompt_label.text = completed_epic_title + " is complete. This era Epic is entered into the record."
	_add_choice("Begin Next Era / New Shift", _begin_next_shift)
	status_label.text = "ERA EPIC COMPLETE  /  CEDAR DESK ENTRY SEALED"

func _begin_next_shift() -> void:
	if phase != "era_complete":
		return
	var previous_era := current_era
	var next_year := previous_era.end_year + 1 if previous_era != null else world.year + 1
	world.year = next_year
	world.period = 0
	world.era_completion_started = false
	world.cedar_desk_log.append({"year": world.year, "title": "NEW SHIFT BEGUN", "summary": "The scribe leaves the completed Epic on the record and begins the next shift."})
	current_era = Registry.get_era_for_year(world.year)
	if current_era != null:
		var previous_epic_id := world.get_active_epic_id()
		var previous_epic_def := Registry.get_epic(previous_epic_id)
		if previous_epic_def != null:
			if previous_epic_def.era_id == current_era.id:
				world.reset_epic_for_new_shift(previous_epic_id)
			else:
				var previous_epic_state: Dictionary = world.epics.get(previous_epic_id, {})
				previous_epic_state["active"] = false
				world.epics[previous_epic_id] = previous_epic_state
	if current_era == null:
		current_era = previous_era
		var fallback_epic_id := world.get_active_epic_id()
		if fallback_epic_id != &"":
			world.reset_epic_for_new_shift(fallback_epic_id)
	context.era = current_era
	context.year = world.year
	_schedule_next_case()

func _show_end_of_queue() -> void:
	_clear_choices()
	_set_phase("end_of_queue")
	case_heading.add_theme_font_size_override("font_size", 20)
	case_heading.text = "𒂍  THE DESK IS CLEAR"
	dossier.visible = false
	dossier.text = ""
	_set_evidence_facts("", "")
	_set_evidence_tension(0, 0)
	prompt_label.text = "The desk is clear. No case is set before you."
	_add_choice("End Period", _advance_period)
	status_label.text = "THE WATER RISES. THE STORES CHANGE. THE CLAY WAITS."

func _add_choice(label_text: String, callback: Callable, disabled: bool = false) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var choice_height := 78 if label_text.contains("\n") else 46
	row.custom_minimum_size.y = choice_height
	choices.add_child(row)
	var wedge := Label.new()
	wedge.text = "𒁹"
	wedge.add_theme_font_override("font", CUNEIFORM_FONT)
	wedge.custom_minimum_size.x = 34
	wedge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wedge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wedge.add_theme_font_size_override("font_size", 22)
	_apply_incised_text(wedge)
	row.add_child(wedge)
	var button := Button.new()
	button.text = label_text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(190, choice_height)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = label_text.replace("\\n", " — ")
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("focus", _panel_style("#00000000", "#f5e6d0"))
	button.add_theme_font_size_override("font_size", 16)
	_apply_incised_text(button)
	button.add_theme_color_override("font_color", Color("#3b2819"))
	button.add_theme_color_override("font_hover_color", Color("#2b1d12"))
	button.add_theme_color_override("font_pressed_color", Color("#21170f"))
	button.add_theme_color_override("font_disabled_color", Color("#5a4632", 0.8))
	var button_normal := _panel_style("#00000000", "#6f512e")
	button_normal.content_margin_left = 18
	button_normal.content_margin_right = 18
	var button_hover := _panel_style("#120b0520", "#a9854e")
	button_hover.content_margin_left = 18
	button_hover.content_margin_right = 18
	var button_pressed := _panel_style("#24180e35", "#5b4228")
	button_pressed.content_margin_left = 18
	button_pressed.content_margin_right = 18
	button.add_theme_stylebox_override("normal", button_normal)
	button.add_theme_stylebox_override("hover", button_hover)
	button.add_theme_stylebox_override("pressed", button_pressed)
	var stamp := Label.new()
	stamp.text = "𒂍" if label_text.contains("Temple") else "𒁹"
	stamp.add_theme_font_override("font", CUNEIFORM_FONT)
	stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_theme_font_size_override("font_size", 38)
	stamp.add_theme_color_override("font_color", Color("#231a12", 0.96))
	stamp.add_theme_color_override("font_shadow_color", Color("#f5e6d0", 0.25))
	stamp.add_theme_constant_override("shadow_offset_x", 0)
	stamp.add_theme_constant_override("shadow_offset_y", 1)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.visible = false
	button.add_child(stamp)
	choice_buttons.append(button)
	choice_stamp_labels[button] = stamp
	button.pressed.connect(_handle_choice.bind(button, callback))
	button.mouse_entered.connect(_preview_choice.bind(button))
	button.mouse_exited.connect(_clear_choice_preview)
	row.add_child(button)

func _preview_choice(button: Button) -> void:
	if phase != "case" or choice_locked:
		return
	var index := choice_buttons.find(button)
	if index < 0:
		return
	var left_delta := 0
	var right_delta := 0
	if not procedural_assignment.is_empty():
		var docket_choices: Array = procedural_assignment.get("choices", [])
		if index >= docket_choices.size():
			return
		var effects: Dictionary = docket_choices[index].get("effects", {})
		left_delta = int(effects.get("opinion_left", 0))
		right_delta = int(effects.get("opinion_right", 0))
	else:
		if active_event == null or index >= active_event.outcomes.size():
			return
		var outcome: EventOutcome = active_event.outcomes[index]
		for effect in outcome.effects:
			if effect.effect_type != &"change_opinion":
				continue
			var effect_params: Dictionary = effect.parameters
			var affected_id := StringName(effect_params.get("subject", ""))
			if affected_id == &"" and context != null:
				var affected_person := context.resolve_subject(String(effect.target))
				if affected_person != null:
					affected_id = affected_person.id
			var amount := int(effect_params.get("amount", 0))
			if affected_id == active_left_speaker_id and active_left_speaker_id != &"":
				left_delta += amount
			elif affected_id == active_right_speaker_id and active_right_speaker_id != &"":
				right_delta += amount
	_set_evidence_tension(left_delta, right_delta)

func _clear_choice_preview() -> void:
	if phase == "case" and not choice_locked:
		_set_evidence_tension(0, 0)

func _handle_choice(button: Button, callback: Callable) -> void:
	if choice_locked:
		return
	if button.text == "End Period" or phase not in ["case", "catechism_path", "catechism_mentor", "north_bay_assessment", "opportunity_board", "world_engagement"]:
		callback.call()
		return
	choice_locked = true
	for choice_button in choice_buttons:
		choice_button.disabled = true
	var stamp: Label = choice_stamp_labels.get(button)
	if stamp != null:
		stamp.visible = true
		stamp.scale = Vector2(1.25, 1.25)
		stamp.pivot_offset = stamp.size * 0.5
		var punch := create_tween()
		punch.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch.tween_property(stamp, "scale", Vector2.ONE, 0.1)
		AudioManager.play_seal_press()
		await punch.finished
		await get_tree().create_timer(0.35).timeout
		_record_choice_stamp(button, stamp)
	callback.call()

func _record_choice_stamp(button: Button, stamp: Label) -> void:
	if stamp_history_row == null or button == null or stamp == null:
		return
	stamp_history_row.visible = true
	var entry := Label.new()
	entry.text = stamp.text
	entry.add_theme_font_override("font", CUNEIFORM_FONT)
	entry.custom_minimum_size = Vector2(32, 34)
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_theme_font_size_override("font_size", 25)
	entry.tooltip_text = "Recorded choice: " + button.text
	_apply_incised_text(entry)
	stamp_history_row.add_child(entry)
	stamp_history_row.visible = stamp_history_row.get_child_count() > 0

func _clear_stamp_history() -> void:
	if stamp_history_row == null:
		return
	stamp_history_row.visible = false
	for child in stamp_history_row.get_children():
		stamp_history_row.remove_child(child)
		child.queue_free()

func _clear_choices() -> void:
	choice_locked = false
	choice_buttons.clear()
	choice_stamp_labels.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _get_roster_person_ids() -> Array[StringName]:
	var roster: Array[StringName] = []
	if world != null and world.player_id != &"":
		roster.append(world.player_id)
	for person_id in ROSTER_CAST:
		if not roster.has(person_id):
			roster.append(person_id)
	return roster


func _build_dossier_text() -> String:
	var path_labels := {&"path_civil": "Civil / Government", &"path_religious": "Religious", &"path_martial": "Martial / Military", &"path_merchant": "Merchant / Commercial"}
	var path_label := String(path_labels.get(selected_path, "Unchosen"))
	var office_label := String(actor.office_id).replace("_", " ").to_upper()
	var currency := String(current_era.currency_name) if current_era != null else "silver"
	return "NAME  %s\nPATH  %s\nTITLE / OFFICE  %s\nPURSE  %d %s" % [actor.display_name, path_label, office_label, int(actor.resources.get(&"silver", 0)), currency.to_upper()]

func _refresh_faction_standings() -> void:
	for child in roster_box.get_children():
		roster_box.remove_child(child)
		child.queue_free()
	if world.current_location_id != &"uruk":
		for official in CompoundContextScript.officials(world, _local_institution_ids()):
			var official_line := Label.new()
			official_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			official_line.add_theme_font_size_override("font_size", 13)
			var title := "Canal Bailiff" if official.id == &"character_0013" else ("Granary Clerk" if official.id == &"character_0012" else String(official.office_id).replace("_", " ").capitalize())
			official_line.text = "%s\n%s / %s / Opinion %+d" % [official.display_name, title, String(official.office_id).replace("_", " ").capitalize(), official.get_opinion(actor.id)]
			roster_box.add_child(official_line)
		return
	for faction_id in [&"boatmens_guild", &"weavers_guild", &"council_of_elders"]:
		var standing := world.get_faction_standing(faction_id)
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size.y = 24
		line.add_theme_font_size_override("normal_font_size", 13)
		var color := "#8bc78b" if standing > 0 else "#d77c70" if standing < 0 else "#c7a96b"
		line.text = "[color=#e0d4bd]%s[/color]  [color=%s]%+d[/color]" % [String(FACTION_LABELS.get(faction_id, faction_id)), color, standing]
		roster_box.add_child(line)

func _apply_faction_opinion(faction_id: StringName, amount: int, _reason: String) -> void:
	if faction_id == &"" or amount == 0:
		return
	world.change_faction_standing(faction_id, amount)
	last_opinion_deltas[faction_id] = amount



func _configure_route_network() -> void:
	route_network = RouteNetworkScript.new()
	var active_era := Registry.get_era_for_year(world.year)
	var active_era_id := active_era.id if active_era != null else &""
	if not route_network.configure(world, Registry.all_places(), Registry.all_routes(), active_era_id):
		push_error("Main: regional route network could not be configured.")
		return
	travel_service = TravelServiceScript.new()
	if not travel_service.configure(route_network, world_simulator):
		push_error("Main: travel service could not be configured.")

func _location_header_text() -> String:
	var place := route_network.get_place(world.current_location_id) if route_network != null else null
	var place_name := place.display_name.to_upper() if place != null else String(world.current_location_id).to_upper()
	return "SCRIBE OF ERAS  /  %s / REGIONAL COMPOUND" % place_name

func _toggle_regional_survey() -> void:
	if survey_map == null or world == null or world.get_player() == null:
		if status_label != null:
			status_label.text = "THE SURVEY REQUIRES A CONFIRMED SCRIBE."
		return
	if survey_map.visible:
		_close_regional_survey()
		return
	_open_regional_survey()

func _open_regional_survey() -> void:
	if survey_map == null or route_network == null or world == null:
		return
	var travel_allowed := phase not in ["character_creation", "era_complete", "case", "world_engagement"]
	if not survey_map.configure(route_network, world, travel_allowed):
		status_label.text = "SURVEY UNAVAILABLE / REGIONAL ROUTE DATA IS INCOMPLETE."
		return
	_set_evidence_visible(false)
	survey_map.visible = true
	if work_queue_button != null:
		work_queue_button.visible = false
	docket_overlay.visible = false
	survey_button.text = "ROLL REGIONAL SURVEY"
	AudioManager.play_docket_slide()

func _close_regional_survey() -> void:
	if survey_map == null:
		return
	survey_map.visible = false
	_set_evidence_visible(CedarDeskLayoutScript.evidence_visible(phase, false))
	if docket_overlay != null:
		docket_overlay.visible = true
	if survey_button != null:
		survey_button.text = "UNROLL REGIONAL SURVEY"
	if work_queue_button != null:
		work_queue_button.visible = phase != "character_creation"
	AudioManager.play_docket_slide()

func _on_survey_travel_requested(route_id: StringName, destination_id: StringName) -> void:
	if phase in ["character_creation", "era_complete", "case", "world_engagement"] or travel_service == null or world == null:
		return
	var traveler := world.get_player()
	var result := travel_service.execute_selected_journey(world, traveler, destination_id, route_id)
	if not bool(result.get("success", false)):
		status_label.text = "DEPARTURE REFUSED / " + String(result.get("error", "Route unavailable")).to_upper()
		return
	_close_regional_survey()
	_show_journey_vignette(result)


func _build_journey_overlay() -> void:
	journey_overlay = Control.new()
	journey_overlay.name = "JourneyVignette"
	journey_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journey_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	journey_overlay.visible = false
	add_child(journey_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.055, 0.04, 0.025, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	journey_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journey_overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 500)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#e4d0a6")
	card_style.border_color = Color("#6d4d2d")
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(5)
	card_style.content_margin_left = 26
	card_style.content_margin_right = 26
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	card.add_child(body)

	journey_heading = Label.new()
	journey_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journey_heading.add_theme_font_size_override("font_size", 23)
	journey_heading.add_theme_color_override("font_color", Color("#382719"))
	body.add_child(journey_heading)

	journey_route_label = Label.new()
	journey_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journey_route_label.add_theme_font_size_override("font_size", 14)
	journey_route_label.add_theme_color_override("font_color", Color("#725333"))
	body.add_child(journey_route_label)

	journey_tableau = CanalJourneyTableau.new()
	journey_tableau.custom_minimum_size = Vector2(640, 170)
	journey_tableau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(journey_tableau)

	journey_narrative = Label.new()
	journey_narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journey_narrative.custom_minimum_size.y = 72
	journey_narrative.add_theme_font_size_override("font_size", 15)
	journey_narrative.add_theme_color_override("font_color", Color("#382719"))
	body.add_child(journey_narrative)

	journey_cost_label = Label.new()
	journey_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journey_cost_label.add_theme_font_size_override("font_size", 14)
	journey_cost_label.add_theme_color_override("font_color", Color("#5d432a"))
	body.add_child(journey_cost_label)

	journey_disembark_button = Button.new()
	journey_disembark_button.custom_minimum_size = Vector2(320, 46)
	journey_disembark_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	journey_disembark_button.add_theme_font_size_override("font_size", 14)
	journey_disembark_button.add_theme_stylebox_override("focus", _panel_style("#3a2b1d", "#f5e6d0"))
	journey_disembark_button.pressed.connect(_disembark_from_journey)
	body.add_child(journey_disembark_button)


func _show_journey_vignette(result: Dictionary) -> void:
	if journey_overlay == null or world == null:
		return
	var origin_name := String(result.get("origin", result.get("origin_id", "Unknown")))
	var destination_name := String(result.get("destination", result.get("destination_id", "Unknown")))
	var route_name := String(result.get("route_name", "Regional passage"))
	var route_type := StringName(result.get("route_type", ""))
	var periods := int(result.get("elapsed_periods", result.get("transit_periods", 1)))
	var fare_paid := int(result.get("fare_paid", 0))
	var fare_due := int(result.get("fare_due", 1))
	journey_heading.text = "EN ROUTE: %s  →  %s" % [origin_name.to_upper(), destination_name.to_upper()]
	journey_route_label.text = "%s  ·  %d PERIOD%s IN TRANSIT" % [route_name, periods, "" if periods == 1 else "S"]
	journey_tableau.route_type = route_type
	journey_tableau.queue_redraw()
	var last_shekel := fare_paid > 0 and int(world.get_player().resources.get(&"silver", 0)) == 0
	var passage_text := ""
	if fare_paid > 0:
		passage_text = "You pay your last shekel of silver for passage." if last_shekel else "You pay one silver for passage."
	else:
		passage_text = "You have no silver for passage; the fee is carried as debt."
	if route_type == &"river":
		journey_narrative.text = "%s The reed barge slides between high bulrushes and dried silt embankments. Word from %s is that the local office has more trouble than its ledgers admit." % [passage_text, destination_name]
	else:
		journey_narrative.text = "%s The road runs between low fields and dried canal embankments. Word from %s is that the local office has more trouble than its ledgers admit." % [passage_text, destination_name]
	if StringName(result.get("destination_id", "")) == &"umma":
		journey_narrative.text += " Umma's bailiff has had three work crews walk off the levee."
	var fare_summary := "-%d SILVER (PASSAGE FARE)" % fare_paid if fare_paid > 0 else "%d SILVER FARE DEFERRED / ROUTE DEBT RECORDED" % fare_due
	journey_cost_label.text = "%s  ·  %s  ·  PERIOD %02d" % [fare_summary, CalendarFormatter.format_year(world.year), world.period + 1]
	journey_disembark_button.text = "DISEMBARK AT %s OUTPOST" % destination_name.to_upper()
	journey_overlay.visible = true
	journey_disembark_button.grab_focus()


func _disembark_from_journey() -> void:
	if journey_overlay == null or not journey_overlay.visible or world == null:
		return
	journey_overlay.visible = false
	active_event = null
	procedural_assignment.clear()
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	actor = world.get_player()
	context.year = world.year
	current_era = Registry.get_era_for_year(world.year)
	context.era = current_era
	context.world = world
	context.actor = actor
	_refresh_compound()
	_schedule_next_case()


func _toggle_work_queue() -> void:
	if work_queue_overlay == null:
		return
	if work_queue_overlay.visible:
		work_queue_overlay.call("close_queue")
	else:
		work_queue_overlay.call("open_queue", assignment_opportunities, work_queue_button, phase == "opportunity_board")


func _on_queue_opportunity_selected(index: int) -> void:
	if index < 0 or index >= assignment_opportunities.size():
		return
	_select_assignment_opportunity(index)


func _set_evidence_visible(is_visible: bool) -> void:
	var visible_now := is_visible and CedarDeskLayoutScript.evidence_visible(phase, survey_map != null and survey_map.visible)
	if upper_workspace_control != null:
		upper_workspace_control.visible = visible_now
	if evidence_workspace != null:
		evidence_workspace.visible = visible_now
	if evidence_left != null:
		evidence_left.visible = visible_now
	if evidence_right != null:
		evidence_right.visible = visible_now


func _refresh_header_status() -> void:
	if actor == null:
		return
	if cedar_header != null:
		cedar_header.update_status(world, actor, current_era)
	_refresh_archive_stack()
	if header_resource_label == null:
		return
	var silver := int(actor.resources.get(&"silver", 0))
	var bread := int(actor.resources.get(&"bread", 0))
	var beer := int(actor.resources.get(&"beer", 0))
	var debt := int(actor.resources.get(&"debt", maxi(0, -silver)))
	var flags: Dictionary = world.world_flags
	var audit_exposure := int(flags.get(&"audit_exposure", flags.get(&"grain_scandal", 0)))
	var audit_text := "AUDIT EXPOSED" if audit_exposure > 0 else "AUDIT QUIET"
	var currency := String(current_era.currency_name) if current_era != null else "silver"
	header_resource_label.text = "PURSE %d %s  ·  DEBT %d  ·  BREAD %d  ·  BEER %d  ·  %s" % [silver, currency.to_upper(), debt, bread, beer, audit_text]


func _seal_clay_docket() -> void:
	if clay_docket != null:
		clay_docket.seal_verdict()

func _on_clay_impression_added(_action_id: StringName, _glyph: String) -> void:
	AudioManager.play_tablet_snap()

func _refresh_archive_stack() -> void:
	if archive_stack == null:
		return
	var urgent_kind := ""
	for opportunity in assignment_opportunities:
		var tags: Array = opportunity.get("tags", [])
		var tag_text := ""
		for tag in tags:
			tag_text += " " + String(tag)
		var text_value := String(opportunity.get("title", "")) + tag_text
		if text_value.to_upper().contains("SUMMONS"):
			urgent_kind = "SUMMONS"
			break
		if text_value.to_upper().contains("CHALLENGE"):
			urgent_kind = "CHALLENGE"
			break
		if text_value.to_upper().contains("DISPATCH"):
			urgent_kind = "DISPATCH"
	archive_stack.set_queue_status(assignment_opportunities.size(), urgent_kind)
	if work_queue_button != null:
		work_queue_button.text = "OPEN WORK QUEUE (%d)" % assignment_opportunities.size() if phase == "opportunity_board" else "ARCHIVE / QUEUE"

func _local_institution_ids() -> Array[StringName]:
	return CompoundContextScript.institution_ids(world, world.current_location_id)


func _refresh_local_stock_facts() -> void:
	if local_stock_label == null or world == null:
		return
	var place_name := String(world.places.get(world.current_location_id, {}).get("name", world.current_location_id))
	var location_titles := {&"uruk": "EANNA TEMPLE COMPOUND", &"umma": "UMMA PROVINCIAL SEAT", &"nippur": "NIPPUR SHRINES"}
	var lines := PackedStringArray([String(location_titles.get(world.current_location_id, "%s COMPOUND" % place_name.to_upper()))])
	var institution_ids := _local_institution_ids()
	if institution_ids.is_empty():
		lines.append("No institution is registered at this location.")
	for institution_id in institution_ids:
		var institution: Dictionary = world.institutions.get(institution_id, {})
		lines.append(String(institution.get("name", institution_id)))
		if institution.has("resource_pressure"):
			lines.append("  Current pressure: %d" % int(institution.get("resource_pressure", 0)))
		var stocks: Dictionary = institution.get("stockpiles", {})
		var stock_keys := stocks.keys()
		stock_keys.sort()
		if stock_keys.is_empty():
			lines.append("  No stockpile recorded")
		else:
			var stock_lines := PackedStringArray()
			for resource_value in stock_keys:
				var resource_id := StringName(resource_value)
				stock_lines.append("%s %d" % [String(resource_id).replace("_", " ").capitalize(), int(stocks[resource_id])])
			lines.append("  " + "  ·  ".join(stock_lines))
		var officials := PackedStringArray()
		for member_value in institution.get("members", []):
			var person := world.get_person(StringName(member_value))
			if person != null and person.office_id != &"":
				var opinion := person.get_opinion(actor.id) if actor != null else 0
				var title := "Canal Bailiff" if person.id == &"character_0013" else ("Granary Clerk" if person.id == &"character_0012" else String(person.office_id).replace("_", " ").capitalize())
				officials.append("%s — %s / %s / Opinion %+d" % [person.display_name, title, String(person.office_id).replace("_", " ").capitalize(), opinion])
		lines.append("  Officials: " + (", ".join(officials) if not officials.is_empty() else "none recorded"))
	local_stock_label.text = "\n".join(lines)


func _update_period_delta_feed() -> void:
	if world == null or period_delta_label == null:
		return
	var entries: Array[String] = []
	for index in range(maxi(0, world.last_period_deltas.size() - 4), world.last_period_deltas.size()):
		entries.append(String(world.last_period_deltas[index].get("text", "")))
	period_delta_label.text = "SINCE LAST PERIOD\n" + ("\n".join(entries) if not entries.is_empty() else "No major changes recorded since last period.")


func _show_archive_notices() -> void:
	if world == null or status_label == null:
		return
	var notices := PackedStringArray()
	for delta_value in world.last_period_deltas:
		if not delta_value is Dictionary:
			continue
		var delta: Dictionary = delta_value
		var category := StringName(delta.get("category", ""))
		if category not in [&"audit", &"arrears"]:
			continue
		var detail := String(delta.get("text", "An archive adjustment was entered against your account."))
		notices.append("ARCHIVE NOTICE FROM SHURUPPAK-ILU:\n%s" % detail)
	archive_notice_active = not notices.is_empty()
	if archive_notice_active:
		status_label.text = "\n\n".join(notices)

func _refresh_compound() -> void:
	if world == null:
		return
	_refresh_header_status()
	_refresh_local_stock_facts()
	_update_period_delta_feed()
	if location_label != null:
		location_label.text = _location_header_text()
	if survey_button != null:
		survey_button.disabled = world.get_player() == null
	if work_queue_button != null:
		work_queue_button.visible = phase != "character_creation" and (survey_map == null or not survey_map.visible)
	var mentor_trait := "unmarked"
	for trait_id in actor.traits:
		if trait_id in [&"exacting", &"stubborn", &"protective", &"diplomatic", &"pliable", &"severe", &"cautious"]:
			mentor_trait = String(trait_id)
	heirloom_label.text = "MENTOR MARK: %s" % mentor_trait.to_upper()
	dossier_label.text = _build_dossier_text()
	var active_epic_id := world.get_active_epic_id()
	var active_epic := Registry.get_epic(active_epic_id)
	if active_epic == null and current_era != null:
		for epic_definition in Registry.all_epics():
			var epic_state: Dictionary = world.epics.get(epic_definition.id, {})
			if epic_definition.era_id == current_era.id and bool(epic_state.get("active", false)):
				active_epic = epic_definition
				active_epic_id = epic_definition.id
				break
	var epic_title := active_epic.title if active_epic != null else "No active Epic"
	var epic_progress := world.get_resource(active_epic.progress_resource) if active_epic != null else 0
	var epic_target := active_epic.target if active_epic != null else 100
	var epic_state: Dictionary = world.epics.get(active_epic_id, {}) if active_epic != null else {}
	var courier_text := ConsequenceVisibilityScript.remote_courier_text(epic_state, epic_progress, epic_target) if world.current_location_id != &"uruk" and active_epic != null and active_epic_id == &"great_canal_cut" else ""
	canal_label.visible = world.current_location_id == &"uruk" or not courier_text.is_empty()
	if not courier_text.is_empty():
		canal_label.text = courier_text
	var filled := int(round(float(epic_progress) / maxf(1.0, float(epic_target)) * 10.0))
	var bar_fill := clampi(filled, 0, 10)
	if courier_text.is_empty():
		if active_epic == null:
			canal_label.text = "CANAL ADMINISTRATION / DORMANT\nNo summons has reached your desk. Local cases and regional work come first."
		else:
			canal_label.text = "ERA EPIC / BACKDROP\n%s\n[%s%s] %d / %d\nYour docket can move the project" % [epic_title.to_upper(), "=".repeat(bar_fill), "-".repeat(10 - bar_fill), epic_progress, epic_target]
	_refresh_faction_standings()
	year_label.text = CalendarFormatter.format_date(current_era, world.year, world.period)
	if not archive_notice_active:
		status_label.text = "SEED %d  /  PERIOD %02d OF 12" % [world.master_seed, world.period + 1]
