extends Control

const CAMPAIGN_SEED: int = 32003200
const CASE_15_ID: StringName = &"case_15_south_court"
const CASE_01_ID: StringName = &"case_01_sealed_vessel"
const CASE_02_ID: StringName = &"case_02_brewers_reckoning"
const ROSTER_ORDER: Array[StringName] = [&"player_apprentice", &"shuruppak_ilu", &"utu_mansum", &"enlil_kisu", &"ur_nanna", &"nin_kasi", &"geme_inana", &"lu_nanshe"]

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
var world: WorldState
var actor: PersonEntity
var active_event: EventTemplate
var context: EventContext
var current_era: EraDef
var first_case_pending := true
var turn_two_pending := false
var arc_complete := false
var selected_path: StringName = &""
var phase := "case"
var last_opinion_deltas: Dictionary[StringName, int] = {}

var year_label: Label
var case_heading: Label
var dossier: RichTextLabel
var record_grid: GridContainer
var prompt_label: Label
var choices: VBoxContainer
var stores_label: Label
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
var choice_buttons: Array[Button] = []
var choice_stamp_labels: Dictionary = {}
var choice_locked := false

func _ready() -> void:
	_build_interface()
	_start_world()

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
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SCRIBE OF ERAS  /  EANNA STOREHOUSE"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#e5d2a8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	year_label = Label.new()
	year_label.add_theme_font_size_override("font_size", 14)
	year_label.add_theme_color_override("font_color", Color("#c4ad7c"))
	header.add_child(year_label)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = Color("#80653b")
	root.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var mat := PanelContainer.new()
	mat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mat.size_flags_stretch_ratio = 2.2
	mat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mat.add_theme_stylebox_override("panel", _panel_style("#00000000", "#00000000"))
	body.add_child(mat)
	var desk_box := VBoxContainer.new()
	desk_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_box.add_theme_constant_override("separation", 8)
	mat.add_child(desk_box)
	var desk_caption := Label.new()
	desk_caption.text = "THE DESK  /  CEDAR AND REED"
	desk_caption.add_theme_font_size_override("font_size", 11)
	desk_caption.add_theme_color_override("font_color", Color("#a99570"))
	desk_box.add_child(desk_caption)
	docket_motion_layer = Control.new()
	docket_motion_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docket_motion_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docket_motion_layer.custom_minimum_size.y = 400
	desk_box.add_child(docket_motion_layer)
	docket_overlay = PanelContainer.new()
	docket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tablet_style := StyleBoxTexture.new()
	tablet_style.texture = load("res://assets/desk/clay_docket.png")
	tablet_style.texture_margin_left = 96.0
	tablet_style.texture_margin_right = 96.0
	tablet_style.texture_margin_top = 82.0
	tablet_style.texture_margin_bottom = 82.0
	tablet_style.content_margin_left = 0.0
	tablet_style.content_margin_right = 0.0
	tablet_style.content_margin_top = 0.0
	tablet_style.content_margin_bottom = 0.0
	docket_overlay.add_theme_stylebox_override("panel", tablet_style)
	docket_motion_layer.add_child(docket_overlay)
	var tablet_content := MarginContainer.new()
	tablet_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tablet_content.add_theme_constant_override("margin_left", 50)
	tablet_content.add_theme_constant_override("margin_right", 50)
	tablet_content.add_theme_constant_override("margin_top", 50)
	tablet_content.add_theme_constant_override("margin_bottom", 50)
	docket_overlay.add_child(tablet_content)
	var mat_box := VBoxContainer.new()
	mat_box.add_theme_constant_override("separation", 10)
	tablet_content.add_child(mat_box)
	case_heading = Label.new()
	var title_font := FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 0.65
	case_heading.add_theme_font_override("font", title_font)
	case_heading.add_theme_font_size_override("font_size", 24)
	_apply_incised_text(case_heading)
	mat_box.add_child(case_heading)
	dossier = RichTextLabel.new()
	dossier.bbcode_enabled = true
	dossier.fit_content = true
	dossier.scroll_active = true
	dossier.custom_minimum_size.y = 105
	dossier.add_theme_font_size_override("normal_font_size", 15)
	_apply_incised_text(dossier)
	mat_box.add_child(dossier)
	var records_title := Label.new()
	records_title.text = "𒂍  SURVIVING RECORDS"
	records_title.add_theme_font_size_override("font_size", 12)
	_apply_incised_text(records_title)
	records_title.visible = false
	mat_box.add_child(records_title)
	record_grid = GridContainer.new()
	record_grid.columns = 3
	record_grid.add_theme_constant_override("h_separation", 8)
	record_grid.add_theme_constant_override("v_separation", 8)
	mat_box.add_child(record_grid)
	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 20)
	_apply_incised_text(prompt_label)
	mat_box.add_child(prompt_label)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 11)
	mat_box.add_child(choices)

	var desk_props := HBoxContainer.new()
	desk_props.custom_minimum_size.y = 72
	desk_props.add_theme_constant_override("separation", 14)
	desk_props.alignment = BoxContainer.ALIGNMENT_CENTER
	desk_box.add_child(desk_props)
	archive_prop = TextureRect.new()
	archive_prop.texture = load("res://assets/desk/archive_stack.png")
	archive_prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	archive_prop.custom_minimum_size = Vector2(110, 60)
	archive_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(archive_prop)
	stylus_prop = TextureRect.new()
	stylus_prop.texture = load("res://assets/desk/Ancient Wrapped Wooden Stylus.png")
	stylus_prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stylus_prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stylus_prop.custom_minimum_size = Vector2(110, 48)
	stylus_prop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stylus_prop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stylus_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(stylus_prop)
	var seal_prop := CylinderSealProp.new()
	seal_prop.custom_minimum_size = Vector2(52, 52)
	seal_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_props.add_child(seal_prop)

	var compound := PanelContainer.new()
	compound.custom_minimum_size.x = 265
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
	stores_title.text = "SETTLEMENT STORES"
	stores_title.add_theme_font_size_override("font_size", 11)
	stores_title.add_theme_color_override("font_color", Color("#a99570"))
	compound_box.add_child(stores_title)
	stores_label = Label.new()
	stores_label.add_theme_font_size_override("font_size", 14)
	stores_label.add_theme_color_override("font_color", Color("#e5d2a8"))
	compound_box.add_child(stores_label)
	canal_label = Label.new()
	canal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canal_label.add_theme_font_size_override("font_size", 13)
	canal_label.add_theme_color_override("font_color", Color("#d6bd8b"))
	compound_box.add_child(canal_label)
	var roster_title := Label.new()
	roster_title.text = "LIVING ROSTER  /  OPINION OF YOU"
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
	AudioManager.play_docket_slide()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(docket_overlay, "position", target_position, 0.2)
	tween.tween_property(docket_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(docket_overlay, "rotation_degrees", 0.0, 0.2)

func _archive_docket() -> void:
	if docket_overlay == null:
		return
	AudioManager.play_docket_slide()
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

func _add_record(heading: String, value: String, detail: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style("#00000000", "#705b3a"))
	record_grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var head := Label.new()
	head.text = "𒂍  " + heading
	head.add_theme_font_size_override("font_size", 11)
	_apply_incised_text(head)
	box.add_child(head)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 19)
	_apply_incised_text(val)
	box.add_child(val)
	var note := Label.new()
	note.text = detail
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	_apply_incised_text(note)
	box.add_child(note)

func _start_world() -> void:
	runner = EventRunner.new()
	scheduler = EventScheduler.new(runner)
	world = WorldState.new()
	actor = UrukSeeder.seed_campaign(world, CAMPAIGN_SEED)
	current_era = Registry.get_era(&"uruk_storehouse")
	context = EventContext.new()
	context.world = world
	context.actor = actor
	context.era = current_era
	context.year = world.year
	_refresh_compound()
	_show_path_catechism()

func _schedule_next_case() -> void:
	context.year = world.year
	current_era = Registry.get_era_for_year(world.year)
	context.era = current_era
	if first_case_pending:
		active_event = Registry.get_event(CASE_15_ID)
		first_case_pending = false
	else:
		active_event = null
	_refresh_compound()
	if active_event == null:
		_show_end_of_queue()
	else:
		_show_case()


func _show_path_catechism() -> void:
	_clear_choices()
	phase = "catechism_path"
	case_heading.text = "𒂍  THE FIRST CLAY"
	case_heading.add_theme_font_size_override("font_size", 24)
	dossier.text = ""
	dossier.visible = false
	_clear_records()
	prompt_label.text = "Where were you taught the city's marks?"
	_add_choice("The Granary Terraces — Temple Path", _choose_path.bind(&"path_temple"))
	_add_choice("The River Quays — Landing Path", _choose_path.bind(&"path_landing"))
	status_label.text = "TWO QUESTIONS BEFORE THE FIRST CLAY"

func _choose_path(path: StringName) -> void:
	if phase != "catechism_path":
		return
	selected_path = path
	if not UrukCatechism.choose_path(world, actor, path):
		return
	_refresh_compound()
	_show_mentor_catechism()

func _show_mentor_catechism() -> void:
	_clear_choices()
	_animate_docket_in()
	phase = "catechism_mentor"
	case_heading.text = "𒂍  THE MENTOR'S MARK"
	case_heading.add_theme_font_size_override("font_size", 24)
	dossier.text = ""
	dossier.visible = false
	_clear_records()
	prompt_label.text = "Whose instruction will you carry?"
	_add_choice("Shuruppak-ilu — +1 Arithmetic; exacting", _choose_mentor.bind(&"shuruppak_ilu"))
	_add_choice("Utu-mansum — +1 Law; stubborn", _choose_mentor.bind(&"utu_mansum"))
	_add_choice("Enlil-kisu — +1 Stewardship; protective", _choose_mentor.bind(&"enlil_kisu"))
	_add_choice("Nin-kasi — +1 Rhetoric; diplomatic", _choose_mentor.bind(&"nin_kasi"))

func _choose_mentor(mentor_id: StringName) -> void:
	if phase != "catechism_mentor":
		return
	if not UrukCatechism.choose_mentor(world, actor, mentor_id):
		return
	_refresh_compound()
	_schedule_next_case()

func _show_case() -> void:
	_clear_choices()
	_animate_docket_in()
	phase = "case"
	case_heading.add_theme_font_size_override("font_size", 24)
	case_heading.text = "𒂍  " + active_event.title.to_upper()
	dossier.visible = true
	dossier.text = "[color=#231a12]" + active_event.description + "[/color]"
	_clear_records()
	if active_event.id == CASE_15_ID:
		_add_record("DISPATCH TABLET", "24 measures barley", "Sealed by Enlil-kisu at the river.")
		_add_record("THRESHOLD TALLY", "23 measures barley", "Marked by Utu-mansum at the gate.")
		_add_record("CUSTODY NOTE", "No witness", "Loading unwitnessed. Unloading unwitnessed. River transit unobserved.")
	elif active_event.id == CASE_01_ID:
		_add_record("PIERCED TAG", "4 jars oil", "6 linen bundles. Sender's seal intact on tag.")
		_add_record("COURT MAT", "4 jars present", "6 bundles present. Smallest oil jar seal cracked.")
		_add_record("CARRIER TESTIMONY", "Road was rough", "Enlil-kisu says the jar was never unstoppered.")
	elif active_event.id == CASE_02_ID:
		_add_record("GRAIN ENTRIES", "6 + 8 + 4 = 18", "Subtotal written: 17.")
		_add_record("MALT ENTRY", "3 baskets malt", "Malted spelt, recorded below the dividing line.")
		_add_record("BLURRED SIGN", "Moisture-damaged", "Allocation between libation and worker bread cannot be established.")
	prompt_label.text = "What mark will you leave?"
	for index in range(active_event.outcomes.size()):
		var outcome: EventOutcome = active_event.outcomes[index]
		_add_choice(outcome.label, _resolve_choice.bind(index), false)
	status_label.text = "THE CLERK'S MARK WILL OUTLIVE THE CLERK"

func _resolve_choice(index: int) -> void:
	if phase != "case":
		return
	if index < 0 or index >= active_event.outcomes.size():
		return
	var before: Dictionary[StringName, int] = {}
	for person_id in ROSTER_ORDER:
		var person := world.get_person(person_id)
		if person != null:
			before[person_id] = int(person.opinions.get(actor.id, 0))
	context.year = world.year
	context.era = Registry.get_era_for_year(world.year)
	runner.resolve_outcome(active_event, active_event.outcomes[index], context)
	if active_event.id == CASE_15_ID:
		turn_two_pending = true
	else:
		arc_complete = true
	last_opinion_deltas.clear()
	for person_id in before:
		var person := world.get_person(person_id)
		var delta := int(person.opinions.get(actor.id, 0)) - before[person_id]
		if delta != 0:
			last_opinion_deltas[person_id] = delta
	_show_result(active_event.outcomes[index])

func _play_outcome_foley(index: int) -> void:
	match active_event.id:
		CASE_15_ID:
			if index == 0:
				AudioManager.play_stylus_mark()
			elif index == 1:
				AudioManager.play_seal_press()
			else:
				AudioManager.play_tablet_snap()
		CASE_01_ID:
			if index == 0:
				AudioManager.play_stylus_mark()
			else:
				AudioManager.play_tablet_snap()
		CASE_02_ID:
			if index == 0:
				AudioManager.play_stylus_mark()
			elif index == 1:
				AudioManager.play_seal_press()
			else:
				AudioManager.play_tablet_snap()

func _show_result(outcome: EventOutcome) -> void:
	_clear_choices()
	phase = "result"
	case_heading.add_theme_font_size_override("font_size", 24)
	case_heading.text = "𒂍  MARK MADE"
	dossier.visible = true
	dossier.text = "[color=#231a12]" + outcome.title_override + "[/color]\n\n[color=#231a12]" + outcome.description_override + "[/color]"
	_clear_records()
	prompt_label.text = "The clay is wet. The record is not."
	_add_choice("End Period", _advance_period, false)
	_refresh_compound()

func _advance_period() -> void:
	if phase != "result" and phase != "end_of_queue":
		return
	if phase == "result":
		await _archive_docket()
	world.advance_period()
	last_opinion_deltas.clear()
	if turn_two_pending:
		turn_two_pending = false
		active_event = Registry.get_event(CASE_02_ID if selected_path == &"path_temple" else CASE_01_ID)
		_refresh_compound()
		_show_case()
	elif arc_complete:
		_show_end_of_queue()
	else:
		_schedule_next_case()

func _prepare_seasonal_forms() -> void:
	# Harvest opens the South Court barley docket and the oil/textile receiving docket.
	if world.period == 6 and not world.has_pending_form(&"grain_levy"):
		world.enqueue_form({"form_type": &"grain_levy", "subject_id": &"south_court_storehouse", "urgency": 1, "year": world.year})
	if world.period == 6 or world.period == 9:
		if not world.has_pending_form(&"consignment_receipt"):
			world.enqueue_form({"form_type": &"consignment_receipt", "subject_id": &"temple_consignment", "urgency": 1, "year": world.year})

func _show_end_of_queue() -> void:
	_clear_choices()
	phase = "end_of_queue"
	case_heading.add_theme_font_size_override("font_size", 24)
	case_heading.text = "𒂍  THE DESK IS CLEAR"
	dossier.visible = true
	dossier.text = "[color=#231a12]All cases filed for now. The record is not.[/color]"
	_clear_records()
	prompt_label.text = "No case is set before you."
	_add_choice("End Period", _advance_period, false)
	status_label.text = "THE WATER RISES. THE STORES CHANGE. THE CLAY WAITS."

func _add_choice(label_text: String, callback: Callable, archive_after_stamp: bool = true) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 56
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
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	_apply_incised_text(button)
	button.add_theme_color_override("font_color", Color("#3b2819"))
	button.add_theme_color_override("font_hover_color", Color("#2b1d12"))
	button.add_theme_color_override("font_pressed_color", Color("#21170f"))
	button.add_theme_color_override("font_disabled_color", Color("#5a4632", 0.8))
	button.add_theme_stylebox_override("normal", _panel_style("#00000000", "#6f512e"))
	button.add_theme_stylebox_override("hover", _panel_style("#120b0520", "#a9854e"))
	button.add_theme_stylebox_override("pressed", _panel_style("#24180e35", "#5b4228"))
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
	button.pressed.connect(_handle_choice.bind(button, callback, archive_after_stamp))
	row.add_child(button)

func _handle_choice(button: Button, callback: Callable, archive_after_stamp: bool) -> void:
	if choice_locked:
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
	if archive_after_stamp:
		await _archive_docket()
	callback.call()

func _clear_choices() -> void:
	choice_locked = false
	choice_buttons.clear()
	choice_stamp_labels.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _clear_records() -> void:
	for child in record_grid.get_children():
		record_grid.remove_child(child)
		child.queue_free()

func _refresh_compound() -> void:
	if world == null:
		return
	var mentor_trait := "unmarked"
	for trait_id in actor.traits:
		if trait_id in [&"exacting", &"stubborn", &"protective", &"diplomatic"]:
			mentor_trait = String(trait_id)
	heirloom_label.text = "HEIRLOOM RIM  /  APPRENTICE SCRIBE  /  MENTOR MARK: %s  /  SILVER AT DESK: %d SHEKELS" % [mentor_trait.to_upper(), world.get_resource(&"silver")]
	stores_label.text = "Barley     %d measures\nSilver     %d shekels\nClay/Reeds %d\nLabor      %d" % [world.get_resource(&"barley"), world.get_resource(&"silver"), world.get_resource(&"clay_reeds"), world.get_resource(&"labor")]
	var canal := world.get_resource(&"canal_progress")
	var filled := int(round(float(canal) / 10.0))
	canal_label.text = "THE GREAT CANAL CUT\n[%s%s] %d / 100\nTarget before Inundation" % ["=".repeat(filled), "-".repeat(10 - filled), canal]
	for child in roster_box.get_children():
		roster_box.remove_child(child)
		child.queue_free()
	for person_id in ROSTER_ORDER:
		var person := world.get_person(person_id)
		if person == null:
			continue
		var opinion := int(person.opinions.get(actor.id, 0))
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size.y = 22
		line.add_theme_font_size_override("normal_font_size", 13)
		var change := int(last_opinion_deltas.get(person_id, 0))
		var flash := ""
		if change > 0:
			flash = " [color=#8bc78b](+%d)[/color]" % change
		elif change < 0:
			flash = " [color=#d77c70](%d)[/color]" % change
		if person.id == actor.id:
			line.text = "[color=#e0d4bd]%s[/color]  [color=#a99570]APPRENTICE[/color]" % person.display_name
		else:
			line.text = "[color=#e0d4bd]%s[/color]  [color=#c7a96b]%+d[/color]%s" % [person.display_name, opinion, flash]
		roster_box.add_child(line)
	year_label.text = CalendarFormatter.format_date(current_era, world.year, world.period)
	status_label.text = "SEED %d  /  PERIOD %02d OF 12" % [world.master_seed, world.period + 1]
