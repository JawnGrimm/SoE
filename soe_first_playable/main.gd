extends Control

const CASE_YEAR := 1200
const CASE_EVENT_ID: StringName = &"corrupt_grain_official"
const EVENT_TEMPLATE: EventTemplate = preload("res://data/events/corrupt_grain_official.tres")

var runner: EventRunner
var world: WorldState
var actor: PersonEntity
var event_template: EventTemplate
var context: EventContext

var phase := "assessment"
var selected_assessment := ""
var selected_outcome := -1

var page: VBoxContainer
var title_label: Label
var year_label: Label
var stats_label: Label
var narrative: RichTextLabel
var evidence_grid: GridContainer
var prompt_label: Label
var choices: VBoxContainer
var footer_label: Label

func _ready() -> void:
    _build_interface()
    _start_case()

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
    year_label.text = "YEAR 1200  •  ARCHIVE 07"
    year_label.add_theme_font_size_override("font_size", 14)
    year_label.add_theme_color_override("font_color", Color("#b5a98e"))
    header.add_child(year_label)

    var rule := ColorRect.new()
    rule.custom_minimum_size.y = 2
    rule.color = Color("#66583f")
    page.add_child(rule)

    var section := Label.new()
    section.text = "CASE FILE  /  THE MISSING MEASURES"
    section.add_theme_font_size_override("font_size", 16)
    section.add_theme_color_override("font_color", Color("#c7a96b"))
    page.add_child(section)

    narrative = RichTextLabel.new()
    narrative.bbcode_enabled = true
    narrative.fit_content = true
    narrative.scroll_active = false
    narrative.add_theme_font_size_override("normal_font_size", 17)
    narrative.add_theme_color_override("default_color", Color("#d5d8dc"))
    narrative.add_theme_color_override("font_color", Color("#d5d8dc"))
    narrative.custom_minimum_size.y = 105
    page.add_child(narrative)

    var evidence_heading := Label.new()
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
    stats_label.text = "STATE"
    stats_label.add_theme_font_size_override("font_size", 14)
    stats_label.add_theme_color_override("font_color", Color("#c9cdd2"))
    stats_label.add_theme_constant_override("margin_left", 12)
    stats_label.add_theme_constant_override("margin_right", 12)
    stats_label.add_theme_constant_override("margin_top", 9)
    stats_label.add_theme_constant_override("margin_bottom", 9)
    stats_panel.add_child(stats_label)

    prompt_label = Label.new()
    prompt_label.text = "What can you responsibly enter in the assessment?"
    prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prompt_label.add_theme_font_size_override("font_size", 18)
    prompt_label.add_theme_color_override("font_color", Color("#e8dfcc"))
    page.add_child(prompt_label)

    choices = VBoxContainer.new()
    choices.add_theme_constant_override("separation", 8)
    page.add_child(choices)

    footer_label = Label.new()
    footer_label.text = "The record is evidence. Your assessment is a separate act."
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

func _start_case() -> void:
    runner = EventRunner.new()
    world = WorldState.new()
    world.year = CASE_YEAR
    world.stockpiles[&"grain"] = 10

    actor = PersonEntity.new()
    actor.id = &"player_scribe"
    actor.office_id = &"grain_clerk"
    actor.skills.levels[&"arithmetic"] = 2
    world.people[actor.id] = actor
    world.enqueue_form({
        "form_type": &"grain_levy",
        "subject_id": &"south_court_storehouse",
        "urgency": 1,
        "year": CASE_YEAR,
    })

    event_template = EVENT_TEMPLATE
    context = EventContext.new()
    context.world = world
    context.actor = actor
    context.year = CASE_YEAR

    phase = "assessment"
    selected_assessment = ""
    selected_outcome = -1
    _refresh_stats()
    _show_assessment()

func _show_assessment() -> void:
    _clear_choices()
    prompt_label.text = "What can you responsibly enter in the assessment?"
    narrative.text = "[color=#d5d8dc]The surviving dispatch copy records 24 measures. The receiving tally records 21. Neither document is direct observation of loading, and no independent origin-side count survives. The three-measure difference is real in the record; its cause is not established.[/color]"
    _add_choice("No individual responsibility assigned", "The evidence does not identify who caused the difference.", _choose_assessment.bind("No individual responsibility assigned"))
    _add_choice("Origin-side dispatch count or handling requires verification", "Request verification of the dispatch count and handling at origin.", _choose_assessment.bind("Origin-side dispatch count or handling requires verification"))
    footer_label.text = "EVIDENCE ≠ INTERPRETATION ≠ JUDGMENT"

func _choose_assessment(claim: String) -> void:
    if phase != "assessment":
        return
    selected_assessment = claim
    actor.memory.append({
        "year": CASE_YEAR,
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

func _resolve_choice(index: int) -> void:
    if phase != "response":
        return
    if not runner.is_eligible(event_template, context):
        _show_error("This event is no longer eligible in the current world state.")
        return
    selected_outcome = index
    var outcome: EventOutcome = event_template.outcomes[index]
    runner.resolve_outcome(event_template, outcome, context)
    phase = "result"
    _show_result(outcome)

func _show_result(outcome: EventOutcome) -> void:
    _clear_choices()
    prompt_label.text = "Docket closed"
    narrative.text = "[color=#c7a96b]" + outcome.title_override + "[/color]\n\n[color=#d5d8dc]" + outcome.description_override + "[/color]\n\n[color=#aab2bb]Assessment entered: " + selected_assessment + ".[/color]"
    _add_choice("Begin another clerk's day", "Reset this small case and try another course of action.", _start_case)
    footer_label.text = "THE WORLD REMEMBERS WHAT YOU STAMPED — AND WHAT YOU LEFT UNRESOLVED"
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
    stats_label.text = "GRAIN  %d    |    PENDING FORMS  %d    |    TRAITS  %s    |    CHRONICLE  %d ENTRIES" % [
        world.get_resource(&"grain"),
        world.pending_forms.size(),
        trait_text,
        actor.memory.size(),
    ]

func _show_error(message: String) -> void:
    _clear_choices()
    prompt_label.text = "The docket cannot proceed."
    narrative.text = "[color=#e59a8b]" + message + "[/color]"
    _add_choice("Restart case", "Reset the world state and return to the first docket.", _start_case)
