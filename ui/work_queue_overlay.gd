class_name WorkQueueOverlay
extends Control

signal opportunity_selected(index: int)
signal closed

const Narrator = preload("res://systems/assignment_narrator.gd")

var _opportunities: Array[Dictionary] = []
var _return_focus: Control
var _can_select := true
var _close_button: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open_queue(opportunities: Array[Dictionary], return_focus: Control = null, can_select: bool = true) -> void:
	_opportunities = opportunities
	_return_focus = return_focus
	_can_select = can_select
	_rebuild()
	visible = true
	if _can_select and not _buttons.is_empty():
		_buttons[0].grab_focus()
	elif _close_button != null:
		_close_button.grab_focus()

func close_queue() -> void:
	visible = false
	closed.emit()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_queue()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.04, 0.025, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 36)
	center.add_theme_constant_override("margin_right", 36)
	center.add_theme_constant_override("margin_top", 28)
	center.add_theme_constant_override("margin_bottom", 28)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 460)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#211a12"), Color("#9a7545")))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var heading := HBoxContainer.new()
	outer.add_child(heading)
	var title := Label.new()
	title.text = "THE ARCHIVE  /  WORK QUEUE"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#e5d2a8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	_close_button = close
	close.text = "CLOSE  [Esc]"
	close.tooltip_text = "Close the work queue and return to the desk."
	close.custom_minimum_size = Vector2(104, 44)
	close.add_theme_stylebox_override("focus", _panel_style(Color("#211a12"), Color("#f5e6d0")))
	close.pressed.connect(close_queue)
	heading.add_child(close)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = Color("#80653b")
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)
	var groups := [
		{"id": "epics", "title": "EPICS", "note": "Monumental undertakings and macro-historical project reviews."},
		{"id": "challenges", "title": "CHALLENGES", "note": "Unusual matters with a longer reach."},
		{"id": "assignments", "title": "ASSIGNMENTS", "note": "Local forms, inspections, and routine commissions."}
	]
	for group in groups:
		var group_items: Array[int] = []
		for i in range(_opportunities.size()):
			if category_for(_opportunities[i]) == String(group.id):
				group_items.append(i)
		if group_items.is_empty():
			continue
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 5)
		sections.add_child(section)
		var label := Label.new()
		label.text = String(group.title) + "  /  " + String(group.note)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#d6bd8b"))
		section.add_child(label)
		for index in group_items:
			var item := Narrator.translate_opportunity(_opportunities[index])
			var button := Button.new()
			var tags: Array = _opportunities[index].get("tags", [])
			var tag_prefix := "[%s]\n" % String(tags[0]) if not tags.is_empty() else ""
			button.text = "%s%s\n%s" % [tag_prefix, String(item.get("title", "Work")), String(item.get("summary", "A matter requires attention."))]
			button.disabled = not _can_select
			button.tooltip_text = "Open this matter at the cedar desk." if _can_select else "Return to the period board to open work."
			button.custom_minimum_size = Vector2(0, 64)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_stylebox_override("focus", _panel_style(Color("#211a12"), Color("#f5e6d0")))
			button.pressed.connect(_select.bind(index))
			section.add_child(button)
			_buttons.append(button)
	if _buttons.is_empty():
		var empty := Label.new()
		empty.text = "No matters are waiting. The world is quiet for this period."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sections.add_child(empty)

static func category_for(item: Dictionary) -> String:
	var kind := StringName(item.get("kind", ""))
	if kind in [&"project_review", &"epic", &"work"] or bool(item.get("is_work", false)):
		return "epics"
	var source_id := String(item.get("source_id", ""))
	if kind == &"challenge" or kind == &"career_challenge" or item.has("challenge_id") or source_id.begins_with("challenge_"):
		return "challenges"
	return "assignments"

func _select(index: int) -> void:
	visible = false
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	opportunity_selected.emit(index)

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
