class_name ArchiveStackProp
extends Button
## Clickable archive prop with a live, accessible queue seal.

static func format_inbox(count: int, urgent_kind: String = "") -> String:
	return "INBOX: %d%s" % [maxi(0, count), (" [" + urgent_kind.to_upper() + "]") if not urgent_kind.is_empty() else ""]

var count_label: Label
var badge_label: Label

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(130, 92)
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Open work queue: Epics, Challenges, Assignments"
	var art := TextureRect.new()
	art.texture = load("res://assets/svg/archive_stack.svg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var seal := PanelContainer.new()
	seal.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	seal.position = Vector2(-4, 2)
	seal.custom_minimum_size = Vector2(100, 28)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#261C14")
	style.border_color = Color("#E0B85C")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	seal.add_theme_stylebox_override("panel", style)
	add_child(seal)
	count_label = Label.new()
	count_label.text = "INBOX: 0"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color("#EDE0C6"))
	seal.add_child(count_label)
	badge_label = Label.new()
	badge_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	badge_label.position.y = -22
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 11)
	badge_label.add_theme_color_override("font_color", Color("#C45A3C"))
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_label)

func set_queue_status(count: int, urgent_kind: String = "") -> void:
	if count_label == null:
		return
	count_label.text = "INBOX: %d" % maxi(0, count)
	badge_label.text = "[%s]" % urgent_kind.to_upper() if not urgent_kind.is_empty() else ""
	badge_label.visible = not urgent_kind.is_empty()
	tooltip_text = "Open work queue. %d items%s" % [count, (", " + urgent_kind) if not urgent_kind.is_empty() else ""]
	accessible_name = tooltip_text
