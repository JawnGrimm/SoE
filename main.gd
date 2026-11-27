extends Control

const AssignmentGeneratorScript = preload("res://systems/assignment_generator.gd")
const CAMPAIGN_SEED: int = 32003200
const ROSTER_CAST: Array[StringName] = [&"shuruppak_ilu", &"utu_mansum", &"enlil_kisu", &"ur_nanna", &"nin_kasi", &"geme_inana", &"lu_nanshe"]
const FACTION_LABELS := {
	&"eanna_household": "🏛 Eanna Temple",
	&"boatmens_guild": "⛵ Landing Boatmen & Guilds",
	&"city_garrison": "🛡 City Garrison",
	&"council_of_elders": "📜 Council of Elders",
	&"agricultural_households": "🌾 Agricultural Households"
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

var runner: EventRunner
var scheduler: EventScheduler
var world_simulator: WorldSimulator
var world: WorldState
var actor: PersonEntity
var active_event: EventTemplate
var procedural_assignment: Dictionary = {}
var assignment_opportunities: Array[Dictionary] = []
var active_world_assignment_id: StringName = &""
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

var year_label: Label
var case_heading: Label
var dossier: RichTextLabel
var prompt_label: Label
var choices: VBoxContainer
var stamp_history_row: HFlowContainer
var dossier_label: Label
var canal_label: Label
var roster_box: VBoxContainer
var status_label: Label
var docket_overlay: PanelContainer
var docket_motion_layer: Control
var archive_prop: TextureRect
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
var evidence_left_facts: Label
var evidence_right_facts: Label
var evidence_left_portrait: TextureRect
var evidence_right_portrait: TextureRect
var portrait_cache: Dictionary = {}
var choice_buttons: Array[Button] = []
var choice_stamp_labels: Dictionary = {}
var choice_locked := false

func _ready() -> void:
	_build_interface()
	_start_world()
	if SaveManager.consume_load_on_start():
		var load_result := load_game()
		if not bool(load_result.get("success", false)):
			status_label.text = "LOAD FAILED / " + String(load_result.get("error", "Unknown error"))
	MusicDirector.play_for_phase(phase)

func _open_pause_menu() -> void:
	var pause_controller := get_node_or_null("PauseMenuController")
	if pause_controller != null and pause_controller.has_method("pause"):
		pause_controller.call("pause")

func _set_phase(next_phase: String) -> void:
	phase = next_phase
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
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SCRIBE OF ERAS  /  THE SCRIBE’S DESK"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#e5d2a8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	year_label = Label.new()
	year_label.add_theme_font_size_override("font_size", 14)
	year_label.add_theme_color_override("font_color", Color("#c4ad7c"))
	header.add_child(year_label)
	var menu_button := Button.new()
	menu_button.text = "☰  MENU"
	menu_button.tooltip_text = "Open the in-game menu (Esc)"
	menu_button.custom_minimum_size = Vector2(104, 34)
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
	var desk_caption := Label.new()
	desk_caption.text = "THE DESK  /  CEDAR AND REED"
	desk_caption.add_theme_font_size_override("font_size", 10)
	desk_caption.add_theme_color_override("font_color", Color("#a99570"))
	desk_box.add_child(desk_caption)
	var upper_workspace := VBoxContainer.new()
	upper_workspace.custom_minimum_size.y = 0
	upper_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Evidence cards are fixed-height; the docket receives the remaining vertical space.
	upper_workspace.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	upper_workspace.add_theme_constant_override("separation", 6)
	desk_box.add_child(upper_workspace)
	var evidence_row := HBoxContainer.new()
	evidence_row.custom_minimum_size.y = 116
	evidence_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_row.add_theme_constant_override("separation", 12)
	upper_workspace.add_child(evidence_row)
	evidence_left = _make_evidence_panel(evidence_row, "GRANARY TERRACES  /  TEMPLE", "Ur-Nanna", "The temple cellars are cold, dry, and exact. The gods demand honest measures.", &"ur_nanna")
	evidence_right = _make_evidence_panel(evidence_row, "RIVER QUAYS  /  LANDING", "Enlil-kisu", "The river road is dangerous and hungry. We respect the scribe who knows what a boatman endures.", &"enlil_kisu")
	docket_motion_layer = Control.new()
	docket_motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	docket_motion_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docket_motion_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docket_motion_layer.custom_minimum_size.y = 256
	desk_box.add_child(docket_motion_layer)
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
	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.custom_minimum_size.y = 22
	_apply_incised_text(prompt_label)
	mat_box.add_child(prompt_label)
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

	var desk_props := HBoxContainer.new()
	desk_props.custom_minimum_size.y = 42
	desk_props.size_flags_vertical = Control.SIZE_SHRINK_END
	desk_props.add_theme_constant_override("separation", 14)
	desk_props.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(desk_props)
	archive_prop = TextureRect.new()
	archive_prop.texture = load("res://assets/desk/archive_stack.png")
	archive_prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	archive_prop.custom_minimum_size = Vector2(82, 44)
	archive_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(archive_prop)
	stylus_prop = TextureRect.new()
	stylus_prop.texture = load("res://assets/desk/Ancient Wrapped Wooden Stylus.png")
	stylus_prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stylus_prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stylus_prop.custom_minimum_size = Vector2(100, 40)
	stylus_prop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stylus_prop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stylus_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(stylus_prop)
	var seal_prop := CylinderSealProp.new()
	seal_prop.custom_minimum_size = Vector2(52, 52)
	seal_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(seal_prop)

	var compound := PanelContainer.new()
	compound.custom_minimum_size.x = 280
	compound.size_flags_horizontal = Control.SIZE_SHRINK_END
	compound.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compound.add_theme_stylebox_override("panel", _panel_style("#211d17", "#665238"))
	body.add_child(compound)
	var compound_box := VBoxContainer.new()
	compound_box.add_theme_constant_override("separation", 10)
	compound.add_child(compound_box)
	var compound_title := Label.new()
	compound_title.text = "THE COMPOUND"
	compound_title.add_theme_font_size_override("font_size", 17)
	compound_title.add_theme_color_override("font_color", Color("#d6bd8b"))
	compound_box.add_child(compound_title)
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
	status_label.add_theme_font_size_override("font_size", 11)
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
	portrait.custom_minimum_size = Vector2(44, 44)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _load_character_portrait(character_id)
	header.add_child(portrait)
	var title := Label.new()
	title.text = heading
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#d6bd8b"))
	header.add_child(title)
	var speaker_label := Label.new()
	speaker_label.text = speaker.to_upper()
	speaker_label.add_theme_font_size_override("font_size", 10)
	speaker_label.add_theme_color_override("font_color", Color("#a99570"))
	box.add_child(speaker_label)
	var quote_label := Label.new()
	quote_label.text = "“%s”" % quote
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	quote_label.add_theme_font_size_override("font_size", 13)
	quote_label.add_theme_color_override("font_color", Color("#e0d4bd"))
	box.add_child(quote_label)
	var facts_label := Label.new()
	facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts_label.add_theme_font_size_override("font_size", 11)
	facts_label.add_theme_color_override("font_color", Color("#c7ad7e"))
	facts_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
				# Center-crop and downsample once for the 44px evidence badge.
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
	actor = UrukSeeder.seed_campaign(world, CAMPAIGN_SEED, false)
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
	status_label.text = "CAMPAIGN RESTORED / RECORD RESUMED"
	return {"success": true}

func _schedule_next_case() -> void:
	_clear_stamp_history()
	var current_player := world.get_player()
	if current_player != null:
		actor = current_player
	context.actor = actor
	context.year = world.year
	current_era = Registry.get_era_for_year(world.year)
	context.era = current_era
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
	active_event = scheduler.pick_next_event(world, actor, event_templates, current_era)
	procedural_assignment.clear()
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	_refresh_compound()
	assignment_opportunities = AssignmentPipeline.generate_opportunities(world, actor, selected_path)
	if active_event != null:
		assignment_opportunities.push_front({
			"id": StringName("work_event_%s_%d" % [active_event.id, world.current_period_index()]),
			"kind": &"event",
			"source_id": active_event.id,
			"title": active_event.title,
			"summary": active_event.description,
			"priority": 100
		})
		while assignment_opportunities.size() > 3:
			assignment_opportunities.pop_back()
	if assignment_opportunities.size() == 3:
		_show_assignment_board()
	else:
		push_warning("Main: assignment pipeline produced fewer than three opportunities (%d)" % assignment_opportunities.size())
		_show_end_of_queue()

func _show_character_creation_screen(screen: int) -> void:
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
	for index in range(8):
		var button := Button.new()
		button.text = "%d %s%s" % [index + 1, nav_labels[index], " ✓" if _creation_step_complete(index + 1) else ""]
		button.disabled = creation_screen == index + 1
		button.pressed.connect(_show_character_creation_screen.bind(index + 1))
		button.add_theme_font_size_override("font_size", 10)
		nav.add_child(button)

	if creation_screen == 0:
		prompt_label.text = "A LIFE ALREADY UNDERWAY"
		dossier.text = "You are not beginning with an empty slate. You have grown up among other people, learned to be useful, made mistakes, and found your way toward the work of a scribe.\n\nThe choices ahead describe the life that brought you here. They shape the people you know, the work you recognize, and the circumstances in which your career begins.\n\n" + String(creation_catalog.get("display_context", "Current era")) + ""
		_add_choice("Begin this life", _show_character_creation_screen.bind(1))
		return

	if creation_screen >= 1 and creation_screen <= 6:
		var question: Dictionary = creation_catalog.get("questions", [])[creation_screen - 1]
		prompt_label.text = String(question.get("prompt", ""))
		dossier.text = String(question.get("title", ""))
		for answer in question.get("answers", []):
			var question_id := StringName(question.get("id", ""))
			var answer_id := StringName(answer.get("id", ""))
			var label := String(answer.get("title", ""))
			if creation_selections.get_answer(question_id) == answer_id:
				label = "✓  " + label
			label += "\n" + String(answer.get("description", ""))
			var availability := CharacterCreationResolver.is_answer_available(creation_catalog, creation_selections, question_id, answer)
			var unavailable := not bool(availability.get("available", false))
			if unavailable:
				label += "\nUnavailable — " + String(availability.get("reason", "Incompatible with an earlier choice."))
			_add_choice(label, _select_creation_answer.bind(question_id, answer_id), unavailable)
		_add_creation_back_next()
		return

	if creation_screen == 7:
		prompt_label.text = "What should people call you?"
		dossier.text = "Your starting traits will be chosen here in a later character-design pass.\n\nYour character's ambition will be defined here. It is not an objective or progression track yet."
		var name_input := LineEdit.new()
		name_input.placeholder_text = "Character name"
		name_input.text = creation_selections.character_name if not creation_selections.character_name.is_empty() else actor.display_name
		name_input.text_changed.connect(_set_creation_name)
		name_input.custom_minimum_size.y = 38
		choices.add_child(name_input)
		creation_selections.set_character_name(name_input.text)
		_add_choice("Review biography", _show_character_creation_screen.bind(8))
		_add_creation_back_next()
		return

	if creation_screen == 8:
		prompt_label.text = "This is where your story begins."
		var validation := CharacterCreationResolver.validate(creation_catalog, creation_selections)
		dossier.text = CharacterCreationResolver.build_biography(creation_catalog, creation_selections)
		var contact_lines: Dictionary = {}
		for effect in CharacterCreationResolver.build_effects(creation_catalog, creation_selections):
			if effect.effect_type != &"set_relationship":
				continue
			var contact_id := StringName(effect.parameters.get("other_id", ""))
			var contact := world.get_person(contact_id)
			if contact != null:
				contact_lines[contact_id] = "%s — %s" % [contact.display_name, String(effect.parameters.get("relation_type", "known contact")).replace("_", " ")]
		dossier.text += "\n\nPEOPLE YOU KNOW\n" + ("\n".join(contact_lines.values()) if not contact_lines.is_empty() else "No personal connections selected.")
		dossier.text += "\n\nPERSONAL QUALITIES\nReserved for a later character-design pass."
		dossier.text += "\n\nAMBITION\nReserved for a later character-design pass."
		if not bool(validation.get("valid", false)):
			dossier.text += "\n\nBEFORE CONFIRMING\n" + "\n".join(validation.get("errors", []))
		else:
			_add_choice("CONFIRM  /  BEGIN CAREER", _confirm_character_creation)
		_add_creation_back_next()
		return

func _creation_step_complete(screen: int) -> bool:
	if screen >= 1 and screen <= 6:
		var question: Dictionary = creation_catalog.get("questions", [])[screen - 1]
		return creation_selections.get_answer(StringName(question.get("id", ""))) != &""
	if screen == 7:
		return not creation_selections.character_name.strip_edges().is_empty()
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
		var ready := true
		if creation_screen >= 1 and creation_screen <= 6:
			var question: Dictionary = creation_catalog.get("questions", [])[creation_screen - 1]
			ready = creation_selections.get_answer(StringName(question.get("id", ""))) != &""
		next.disabled = not ready
		next.pressed.connect(_show_character_creation_screen.bind(creation_screen + 1))
		row.add_child(next)

func _select_creation_answer(question_id: StringName, answer_id: StringName) -> void:
	if phase != "character_creation":
		return
	if not creation_selections.select_answer(question_id, answer_id):
		return
	CharacterCreationResolver.prune_invalid_answers(creation_catalog, creation_selections)
	_show_character_creation_screen(creation_screen)

func _set_creation_name(value: String) -> void:
	creation_selections.set_character_name(value)

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

func _authored_choices_payload() -> Array:
	var result: Array = []
	if active_event == null:
		return result
	for outcome in active_event.outcomes:
		result.append({"label": outcome.label, "result_title": outcome.title_override, "result_text": outcome.description_override, "effects": outcome.effects})
	return result

func _show_assignment_board() -> void:
	_clear_stamp_history()
	_clear_choices()
	_set_phase("opportunity_board")
	var choices_payload: Array = []
	var callbacks: Array[Callable] = []
	var summaries := PackedStringArray()
	for index in range(assignment_opportunities.size()):
		var opportunity: Dictionary = assignment_opportunities[index]
		var label := "%s\n%s" % [String(opportunity.get("title", "Work")), String(opportunity.get("summary", "A matter requires attention."))]
		choices_payload.append({"label": label})
		callbacks.append(_select_assignment_opportunity.bind(index))
		summaries.append("%d. %s / %s" % [index + 1, String(opportunity.get("kind", "work")).replace("_", " ").to_upper(), String(opportunity.get("title", "Work"))])
	var payload := {
		"title": "THE SCRIBE'S DESK / THREE OPPORTUNITIES",
		"left_card": {"title": "THE LIVING WORLD", "speaker_id": &"", "quote": "The city has continued its business while you were away from the desk.", "facts": "YEAR: %s\nPERIOD: %d / 12\nPENDING FORMS: %d\nACTIVE HAZARDS: %d" % [CalendarFormatter.format_year(world.year), world.period + 1, world.pending_forms.size(), world.hazards.filter(func(h: Dictionary) -> bool: return bool(h.get("active", false))).size()]},
		"right_card": {"title": "AVAILABLE WORK", "speaker_id": &"shuruppak_ilu", "quote": "Choose the matter you will take responsibility for this period. The others remain in the world, whether you attend to them or not.", "facts": "\n".join(summaries)},
		"prompt": "Three matters have reached your desk. Select one engagement, or pass without penalty.",
		"choices": choices_payload
	}
	_render_docket_payload(payload, callbacks)
	_add_choice("Regional Map / Travel", _show_regional_map)
	_add_choice("Pass / End Period", _decline_opportunities)
	_refresh_compound()

func _show_regional_map() -> void:
	if phase != "opportunity_board" and phase != "regional_map":
		return
	_clear_choices()
	_set_phase("regional_map")
	var origin_id := actor.current_location_id if actor.current_location_id != &"" else &"uruk"
	var origin_name := String(world.places.get(origin_id, {}).get("name", origin_id))
	var options := RegionalWorldSystem.get_destination_options(world, origin_id)
	var payload := {
		"title": "REGIONAL NETWORK / ROUTE DOCKET",
		"left_card": {"title": "CURRENT LOCATION", "speaker_id": &"", "quote": origin_name, "facts": "PLACE: %s\nROUTES AVAILABLE: %d" % [String(origin_id), options.size()]},
		"right_card": {"title": "THE ROAD AND RIVER", "speaker_id": &"", "quote": "Distance is time, exposure, and the chance that the world changes before you arrive.", "facts": "Travel advances with the world calendar. Route incidents are recorded along the way."},
		"prompt": "Choose a destination. This begins travel; each End Period advances the journey and the world.",
		"choices": []
	}
	var callbacks: Array[Callable] = []
	for option in options:
		var destination_id: StringName = option.place_id
		payload.choices.append({"label": "%s / %d periods / %d bread / %d beer / route risk %d" % [String(option.name), int(option.travel_periods), int(option.bread_required), int(option.beer_required), int(option.route_risk_percent)]})
		callbacks.append(_begin_regional_travel.bind(destination_id))
	_render_docket_payload(payload, callbacks)
	_add_choice("Return to Work Board", _show_assignment_board)
	_refresh_compound()

func _begin_regional_travel(destination_id: StringName) -> void:
	if phase != "regional_map":
		return
	var travel_result := RegionalWorldSystem.start_player_travel(world, actor, destination_id)
	if not bool(travel_result.get("success", false)):
		status_label.text = String(travel_result.get("error", "Travel could not begin."))
		_show_regional_map()
		return
	var destination_name := String(world.places.get(destination_id, {}).get("name", destination_id))
	var periods := int(travel_result.get("travel_periods", 0))
	_show_procedural_result("REGIONAL JOURNEY ACCEPTED", "You depart for %s. The route requires %d periods and consumes bread each period plus beer every third period. Any missing rations are purchased from local stores for silver. The world advances while you travel; route incidents are recorded." % [destination_name, periods])

func _select_assignment_opportunity(index: int) -> void:
	if phase != "opportunity_board" or index < 0 or index >= assignment_opportunities.size():
		return
	var opportunity := assignment_opportunities[index]
	if StringName(opportunity.get("kind", "")) == &"event":
		active_event = Registry.get_event(StringName(opportunity.get("source_id", "")))
		if active_event == null:
			status_label.text = "EVENT COULD NOT BE OPENED / SOURCE MAY HAVE CHANGED"
			return
		AudioManager.play_docket_slide()
		_show_case()
		return
	active_event = null
	if not AssignmentPipeline.begin(world, opportunity, actor):
		status_label.text = "WORK COULD NOT BE OPENED / SOURCE MAY HAVE CHANGED"
		return
	active_world_assignment_id = StringName(opportunity.get("id", ""))
	AudioManager.play_docket_slide()
	_show_world_engagement()

func _show_world_engagement() -> void:
	var record := AssignmentPipeline.get_record(world, active_world_assignment_id)
	if record.is_empty():
		active_world_assignment_id = &""
		_show_assignment_board()
		return
	_clear_choices()
	_set_phase("world_engagement")
	var actions: Dictionary = record.get("actions", {})
	var available_actions: Array = AssignmentPipeline.get_actions(record)
	var evidence: Dictionary = record.get("evidence", {})
	var evidence_lines := PackedStringArray()
	for action_id in evidence.keys():
		var entry: Dictionary = evidence[action_id]
		evidence_lines.append("%s\n%s" % [String(action_id).replace("_", " ").to_upper(), String(entry.get("facts", ""))])
	var left_quote := String(record.get("summary", "A matter requires professional attention."))
	var employer := world.get_person(StringName(record.get("employer_id", "")))
	var right_quote := "The record is incomplete. Read it, reconcile the figures, hear the responsible official, and inspect the source before making your assessment."
	if StringName(record.get("kind", "")) == &"regional_work":
		right_quote = "Trade decisions move goods along the route. The seal you issue will arrive before you can see its consequences."
	var payload := {
		"title": String(record.get("title", "ASSIGNMENT")),
		"left_card": {"title": "WORLD SITUATION / %s" % String(record.get("kind", "work")).to_upper(), "speaker_id": &"", "quote": left_quote, "facts": "SOURCE: %s\nOPENED: %s / PERIOD %d" % [String(record.get("source_id", "")), CalendarFormatter.format_year(world.year), world.period + 1]},
		"right_card": {"title": "RESPONSIBLE OFFICE", "speaker_id": employer.id if employer != null else &"", "quote": right_quote, "facts": "WORK STEPS RECORDED: %d / %d\n\n%s" % [actions.size(), available_actions.size(), "\n\n".join(evidence_lines)]},
		"prompt": "Choose how to approach the work. Your skills shape what you can establish; your judgment determines what is entered.",
		"choices": []
	}
	var callbacks: Array[Callable] = []
	for action in available_actions:
		var action_id: StringName = action.id
		var done := actions.has(action_id)
		payload.choices.append({"label": String(action.label) + (" / RECORDED" if done else "")})
		callbacks.append(_world_assignment_action.bind(action_id))
		payload.choices.back()["disabled"] = done
	_render_docket_payload(payload, callbacks)
	if actions.size() >= 2:
		match StringName(record.get("kind", "")):
			&"form":
				var form_data: Dictionary = record.get("source_data", {})
				var form_type := StringName(form_data.get("form_type", ""))
				if form_type == &"remote_dispatch":
					_add_choice("Accept received cargo and certify", _resolve_world_assignment.bind(&"certify"))
					_add_choice("Hold cargo / request origin account", _resolve_world_assignment.bind(&"refer"))
					_add_choice("Defer entry / return to docket", _resolve_world_assignment.bind(&"defer"))
				elif form_type == &"remote_origin_reply":
					_add_choice("Accept cargo on the origin account", _resolve_world_assignment.bind(&"certify"))
					_add_choice("Keep cargo held / request another account", _resolve_world_assignment.bind(&"refer"))
					_add_choice("Defer settlement", _resolve_world_assignment.bind(&"defer"))
				else:
					_add_choice("Certify and close the form", _resolve_world_assignment.bind(&"certify"))
					_add_choice("Refer the matter for senior review", _resolve_world_assignment.bind(&"refer"))
					_add_choice("Defer the assessment", _resolve_world_assignment.bind(&"defer"))
			&"regional_work":
				var work_data: Dictionary = record.get("source_data", {})
				match StringName(work_data.get("work_type", "")):
					&"dispatch_export":
						_add_choice("Seal and dispatch the export", _resolve_world_assignment.bind(&"dispatch"))
						_add_choice("Hold the cargo in reserve", _resolve_world_assignment.bind(&"hold"))
					&"request_import":
						_add_choice("Authorize the import request", _resolve_world_assignment.bind(&"authorize"))
						_add_choice("Decline the purchase this period", _resolve_world_assignment.bind(&"hold"))
					&"route_provisions":
						_add_choice("Issue beer to provision the route", _resolve_world_assignment.bind(&"issue"))
						_add_choice("Keep the beer in reserve", _resolve_world_assignment.bind(&"hold"))
			&"hazard":
				_add_choice("Allocate three labor and repair", _resolve_world_assignment.bind(&"repair"), world.get_resource(&"labor", "institution", "", &"eanna_household") < 3)
				_add_choice("Record the loss and defer repair", _resolve_world_assignment.bind(&"defer"))
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
	_show_world_engagement()

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
	_show_procedural_result("ASSESSMENT SEALED", String(result.get("message", "The work is entered into the record.")))

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
	_render_docket_payload(_active_docket_payload())

func _render_docket_payload(payload: Dictionary, callbacks: Array = []) -> void:
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
	_show_result(active_event.outcomes[index])

func _resolve_procedural_choice(index: int, choice: Dictionary) -> void:
	var effects: Dictionary = choice.get("effects", {})
	var pair_parts := String(procedural_assignment.get("npc_pair", "")).split("|")
	var left := world.get_person(StringName(pair_parts[0])) if pair_parts.size() > 0 else null
	var right := world.get_person(StringName(pair_parts[1])) if pair_parts.size() > 1 else null
	var silver_before := int(actor.resources.get(&"silver", 0))
	var traits_before: Array[StringName] = actor.traits.duplicate()
	last_opinion_deltas.clear()
	var left_delta := int(effects.get("opinion_left", 0))
	var right_delta := int(effects.get("opinion_right", 0))
	var docket_kind := String(procedural_assignment.get("docket_kind", ""))
	var opinion_reason := "Procedural docket: %s" % String(procedural_assignment.get("title", ""))
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
	if skill_id != &"":
		actor.skills.add_xp(skill_id, int(effects.get("xp", 0)))
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
	var result_title := String(choice.get("result_title", "MARK MADE"))
	_show_procedural_result(result_title, result_text)

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
	assignment_opportunities.clear()
	active_world_assignment_id = &""
	_clear_stamp_history()
	world_simulator.advance_period(world)
	last_opinion_deltas.clear()
	if world.is_active_epic_complete() and not world.era_completion_started:
		_show_era_completion()
		return
	_schedule_next_case()

func _show_procedural_result(result_title: String, result_text: String) -> void:
	_clear_choices()
	_set_phase("result")
	case_heading.text = "𒂍  " + result_title.to_upper()
	dossier.visible = false
	dossier.text = ""
	_set_evidence_facts("", "")
	_set_evidence_tension(0, 0)
	prompt_label.text = result_text
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	for faction_id in [&"eanna_household", &"boatmens_guild", &"city_garrison", &"council_of_elders", &"agricultural_households"]:
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

func _apply_faction_opinion(faction_id: StringName, amount: int, reason: String) -> void:
	if faction_id == &"" or amount == 0:
		return
	world.change_faction_standing(faction_id, amount)
	last_opinion_deltas[faction_id] = amount


func _refresh_compound() -> void:
	if world == null:
		return
	var mentor_trait := "unmarked"
	for trait_id in actor.traits:
		if trait_id in [&"exacting", &"stubborn", &"protective", &"diplomatic"]:
			mentor_trait = String(trait_id)
	heirloom_label.text = "MENTOR MARK: %s" % mentor_trait.to_upper()
	dossier_label.text = _build_dossier_text()
	var active_epic_id := world.get_active_epic_id()
	var active_epic := Registry.get_epic(active_epic_id)
	if active_epic == null and current_era != null:
		for epic_definition in Registry.all_epics():
			if epic_definition.era_id == current_era.id:
				active_epic = epic_definition
				break
	var epic_title := active_epic.title if active_epic != null else "No active Epic"
	var epic_progress := world.get_resource(active_epic.progress_resource) if active_epic != null else 0
	var epic_target := active_epic.target if active_epic != null else 100
	var filled := int(round(float(epic_progress) / maxf(1.0, float(epic_target)) * 10.0))
	var bar_fill := clampi(filled, 0, 10)
	canal_label.text = "ERA EPIC / BACKDROP\n%s\n[%s%s] %d / %d\nYour docket can move the project" % [epic_title.to_upper(), "=".repeat(bar_fill), "-".repeat(10 - bar_fill), epic_progress, epic_target]
	_refresh_faction_standings()
	year_label.text = CalendarFormatter.format_date(current_era, world.year, world.period)
	var location_id := actor.current_location_id if actor.current_location_id != &"" else &"uruk"
	var location_name := String(world.places.get(location_id, {}).get("name", location_id))
	if String(world.player_travel.get("status", "")) == "in_transit":
		status_label.text = "TRAVEL / %s  /  %d PERIODS REMAINING" % [location_name, int(world.player_travel.get("remaining_periods", 0))]
	else:
		status_label.text = "%s  /  SEED %d  /  PERIOD %02d OF 12" % [location_name.to_upper(), world.master_seed, world.period + 1]
