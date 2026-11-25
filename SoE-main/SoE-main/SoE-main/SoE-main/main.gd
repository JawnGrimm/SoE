extends Control

const INITIAL_YEAR := 1200
const INITIAL_EVENT_ID: StringName = &"corrupt_grain_official"
var event_templates: Array[EventTemplate] = []
var current_era: EraDef

var runner: EventRunner
var scheduler: EventScheduler
var world: WorldState
var actor: PersonEntity
var active_event: EventTemplate
var context: EventContext
var grain_levy_form_id: StringName = &""

var phase := "assessment"
var selected_assessment := ""

var page: VBoxContainer
var title_label: Label
var year_label: Label
var section_label: Label
var evidence_heading: Label
var stats_label: Label
var narrative: RichTextLabel
var evidence_grid: GridContainer
var prompt_label: Label
var choices: VBoxContainer
var footer_label: Label

func _ready() -> void:
	_build_interface()
	_start_world()

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("#11151b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	title_label = Label.new()
	title_label.text = "SCRIBE OF ERAS"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color("#e8dfcc"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	year_label = Label.new()
	year_label.add_theme_font_size_override("font_size", 14)
	year_label.add_theme_color_override("font_color", Color("#b5a98e"))
	header.add_child(year_label)

	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = Color("#66583f")
	page.add_child(rule)

	section_label = Label.new()
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.add_theme_color_override("font_color", Color("#c7a96b"))
	page.add_child(section_label)

	narrative = RichTextLabel.new()
	narrative.bbcode_enabled = true
	narrative.fit_content = true
	narrative.scroll_active = false
	narrative.add_theme_font_size_override("normal_font_size", 17)
	narrative.add_theme_color_override("default_color", Color("#d5d8dc"))
	narrative.add_theme_color_override("font_color", Color("#d5d8dc"))
	narrative.custom_minimum_size.y = 105
	page.add_child(narrative)

	evidence_heading = Label.new()
	evidence_heading.text = "SURVIVING RECORDS"
	evidence_heading.add_theme_font_size_override("font_size", 13)
	evidence_heading.add_theme_color_override("font_color", Color("#8f9aa8"))
	page.add_child(evidence_heading)

	evidence_grid = GridContainer.new()
	evidence_grid.columns = 3
	evidence_grid.add_theme_constant_override("h_separation", 12)
	evidence_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(evidence_grid)

	_add_evidence_card("DISPATCH COPY", "24 measures", "A surviving copy records the amount dispatched.")
	_add_evidence_card("RECEIVING TALLY", "21 measures", "The storehouse clerk recorded three fewer.")
	_add_evidence_card("LOADING OBSERVATION", "Not present", "No independent witness account of loading survives.")

	var stats_panel := PanelContainer.new()
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color("#1b222b")
	stats_style.border_color = Color("#343d49")
	stats_style.set_border_width_all(1)
	stats_style.set_corner_radius_all(5)
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	page.add_child(stats_panel)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color("#c9cdd2"))
	stats_panel.add_child(stats_label)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("#e8dfcc"))
	page.add_child(prompt_label)

	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	page.add_child(choices)

	footer_label = Label.new()
	footer_label.add_theme_font_size_override("font_size", 12)
	footer_label.add_theme_color_override("font_color", Color("#7e8792"))
	page.add_child(footer_label)

func _add_evidence_card(heading: String, value: String, detail: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202832")
	style.border_color = Color("#3a4654")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("panel", style)
	evidence_grid.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_theme_constant_override("margin_left", 12)
	box.add_theme_constant_override("margin_right", 12)
	box.add_theme_constant_override("margin_top", 10)
	box.add_theme_constant_override("margin_bottom", 10)
	card.add_child(box)

	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_size_override("font_size", 11)
	heading_label.add_theme_color_override("font_color", Color("#9ca8b5"))
	box.add_child(heading_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", Color("#e8dfcc"))
	box.add_child(value_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color("#aab2bb"))
	box.add_child(detail_label)

func _start_world() -> void:
	runner = EventRunner.new()
	scheduler = EventScheduler.new(runner)
	event_templates.clear()
	for definition in Registry.get_definitions("events"):
		if definition is EventTemplate:
			event_templates.append(definition)
	event_templates.sort_custom(func(a: EventTemplate, b: EventTemplate) -> bool: return String(a.id) < String(b.id))
	world = WorldState.new()
	current_era = _find_era_for_year(world.year)
	world.year = INITIAL_YEAR
	world.period = 0
	world.stockpiles[&"grain"] = 10

	actor = PersonEntity.new()
	actor.id = &"player_scribe"
	actor.office_id = &"grain_clerk"
	actor.skills.levels[&"arithmetic"] = 2
	world.people[actor.id] = actor

	grain_levy_form_id = world.enqueue_form({
		"form_type": &"grain_levy",
		"subject_id": &"south_court_storehouse",
		"urgency": 1,
		"year": world.year,
	})

	context = EventContext.new()
	context.world = world
	context.actor = actor
	context.year = world.year
	_schedule_next_case()

func _schedule_next_case() -> void:
	context.year = world.year
	active_event = scheduler.pick_next_event(world, actor, event_templates)
	_refresh_stats()
	if active_event == null:
		_show_end_of_queue()
	elif active_event.id == INITIAL_EVENT_ID:
		_show_assessment()
	else:
		_show_scheduled_case()

func _show_assessment() -> void:
	_clear_choices()
	phase = "assessment"
	selected_assessment = ""
	section_label.text = "CASE FILE  /  " + active_event.title.to_upper()
	evidence_heading.visible = true
	evidence_grid.visible = true
	prompt_label.text = "What can you responsibly enter in the assessment?"
	narrative.text = "[color=#d5d8dc]" + active_event.description + "[/color]"
	_add_choice("No individual responsibility assigned", "The evidence does not identify who caused the difference.", _choose_assessment.bind("No individual responsibility assigned"))
	_add_choice("Origin-side dispatch count or handling requires verification", "Request verification of the dispatch count and handling at origin.", _choose_assessment.bind("Origin-side dispatch count or handling requires verification"))
	footer_label.text = "EVIDENCE ≠ INTERPRETATION ≠ JUDGMENT"

func _choose_assessment(claim: String) -> void:
	if phase != "assessment":
		return
	selected_assessment = claim
	if not world.record_form_assessment(grain_levy_form_id, claim):
		_show_error("The assessment could not be attached to the pending form.")
		return
	actor.memory.append({
		"year": world.year,
		"memory_id": &"grain_assessment",
		"text": "Assessment entered: " + claim + ".",
		"involved": [],
	})
	phase = "response"
	_show_response()

func _show_response() -> void:
	_clear_choices()
	prompt_label.text = "The assessment is entered. What do you do with the form?"
	narrative.text = "[color=#c7a96b]ASSESSMENT RECORDED[/color]\n[color=#d5d8dc]" + selected_assessment + ".[/color]\n\n[color=#aab2bb]The clerk's stamp is the next piece of evidence history will inherit.[/color]"
	_add_choice("Certify the receiving tally", "Close the form without further inquiry. The unresolved difference stays in the account.", _resolve_choice.bind(0))
	_add_choice("Open a formal inquiry", "Refer the discrepancy for origin-side dispatch and handling verification.", _resolve_choice.bind(1))
	footer_label.text = "YOUR ASSESSMENT IS RECORDED; THE RESPONSE IS STILL YOURS TO CHOOSE"

func _show_scheduled_case() -> void:
	_clear_choices()
	phase = "scheduled_choice"
	section_label.text = "CASE FILE  /  " + active_event.title.to_upper()
	evidence_heading.visible = false
	evidence_grid.visible = false
	var body := active_event.description
	if active_event.id == &"origin_side_reply":
		var archived := world.get_latest_resolved_form(&"grain_levy")
		var assessment := String(archived.get("assessment", "No assessment was preserved."))
		body += "\n\n[color=#c7a96b]YOUR EARLIER ASSESSMENT[/color]\n[color=#d5d8dc]" + assessment + "[/color]"
	narrative.text = "[color=#d5d8dc]" + body + "[/color]"
	prompt_label.text = "What do you enter in the docket?"
	for index in range(active_event.outcomes.size()):
		var outcome: EventOutcome = active_event.outcomes[index]
		_add_choice(outcome.label, outcome.description_override, _resolve_choice.bind(index))
	footer_label.text = "THE NEXT CASE HAS ARRIVED BECAUSE OF WHAT THE RECORD ALREADY CONTAINS"

func _resolve_choice(index: int) -> void:
	if phase != "response" and phase != "scheduled_choice":
		return
	context.year = world.year
	if not runner.is_eligible(active_event, context):
		_show_error("This event is no longer eligible in the current world state.")
		return
	if index < 0 or index >= active_event.outcomes.size():
		_show_error("The selected outcome does not exist.")
		return
	var outcome: EventOutcome = active_event.outcomes[index]
	runner.resolve_outcome(active_event, outcome, context)
	phase = "result"
	_show_result(outcome)

func _show_result(outcome: EventOutcome) -> void:
	_clear_choices()
	section_label.text = "FILED  /  " + active_event.title.to_upper()
	evidence_heading.visible = false
	evidence_grid.visible = false
	prompt_label.text = "Docket closed"
	var result_text := "[color=#c7a96b]" + outcome.title_override + "[/color]\n\n[color=#d5d8dc]" + outcome.description_override + "[/color]"
	if not selected_assessment.is_empty():
		result_text += "\n\n[color=#aab2bb]Assessment entered: " + selected_assessment + ".[/color]"
	narrative.text = result_text
	_add_choice("End Period", "Advance the monthly desk turn and receive the next eligible case, if one exists.", _advance_period)
	footer_label.text = "THE WORLD REMEMBERS WHAT YOU STAMPED — AND WHAT YOU LEFT UNRESOLVED"
	_refresh_stats()

func _advance_period() -> void:
	if phase != "result" and phase != "end_of_queue":
		return
	world.advance_period()
	context.year = world.year
	selected_assessment = ""
	_schedule_next_case()

func _show_end_of_queue() -> void:
	_clear_choices()
	phase = "end_of_queue"
	section_label.text = "END OF QUEUE"
	evidence_heading.visible = false
	evidence_grid.visible = false
	prompt_label.text = "All cases filed for now."
	narrative.text = "[color=#d5d8dc]There are no currently eligible assignments. The desk is clear; the record is not.[/color]\n\n[color=#aab2bb]The period clock continues. New business may arrive when the world state makes another case eligible.[/color]"
	_add_choice("Advance Period", "Move to the next month and check the case register again.", _advance_period)
	footer_label.text = "NO ELIGIBLE CASES REMAIN IN THE CURRENT REGISTER"
	_refresh_stats()

func _add_choice(label_text: String, description: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text + "\n" + description
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#e8dfcc"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#c7a96b"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#242d38"), Color("#3d4b5c")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#303c49"), Color("#c7a96b")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#18202a"), Color("#c7a96b")))
	button.add_theme_stylebox_override("focus", _button_style(Color("#242d38"), Color("#c7a96b")))
	button.pressed.connect(callback)
	choices.add_child(button)

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _refresh_stats() -> void:
	if stats_label == null or world == null:
		return
	var trait_text := "none" if actor.traits.is_empty() else str(actor.traits)
	stats_label.text = "GRAIN  %d    |    PENDING FORMS  %d    |    ARCHIVED  %d    |    TRAITS  %s    |    CHRONICLE  %d ENTRIES" % [
		world.get_resource(&"grain"),
		world.pending_forms.size(),
		world.resolved_forms.size(),
		trait_text,
		actor.memory.size(),
	]
	current_era = _find_era_for_year(world.year)
	year_label.text = CalendarFormatter.format_date(current_era, world.year, world.period)

func _find_era_for_year(year: int) -> EraDef:
	for definition in Registry.get_definitions("eras"):
		if definition is EraDef and year >= definition.start_year and year <= definition.end_year:
			return definition
	return null

func _show_error(message: String) -> void:
	_clear_choices()
	prompt_label.text = "The docket cannot proceed."
	narrative.text = "[color=#e59a8b]" + message + "[/color]"
	_add_choice("Return to the case register", "Check which assignments remain eligible.", _schedule_next_case)
