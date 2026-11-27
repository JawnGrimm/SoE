class_name ClayDocketProp
extends Control
## Transient tactile docket. Stamps are presentation-only and never serialized.

signal impression_added(action_id: StringName, glyph: String)
signal verdict_sealed(glyph: String)

const CUNEIFORM_FONT: Font = preload("res://assets/fonts/NotoSansCuneiform-Regular.ttf")
const ACTION_GLYPHS := {
	&"examine_records": {"glyph": "𒁾", "label": "Written record / archive"},
	&"reconcile_accounts": {"glyph": "𒂍", "label": "Storehouse / account"},
	&"consult_official": {"glyph": "𒇽", "label": "Official testimony"},
	&"inspect_source": {"glyph": "𒆠", "label": "Physical site / source"}
}
const VERDICT_GLYPH := "𒁹"

var title_label: Label
var grid: GridContainer
var impressions: Array[Dictionary] = []
var reduced_motion := false
var verdict_is_sealed := false

func _ready() -> void:
	custom_minimum_size = Vector2(150, 170)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "CLAY DOCKET"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	title_label = Label.new()
	title_label.text = "No active case"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 12)
	box.add_child(title_label)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for index in range(8):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(48, 40)
		cell.add_theme_stylebox_override("panel", _clay_cell_style())
		var glyph := Label.new()
		glyph.text = "·"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_override("font", CUNEIFORM_FONT)
		glyph.add_theme_font_size_override("font_size", 24)
		cell.add_child(glyph)
		grid.add_child(cell)

func clear_impressions() -> void:
	impressions.clear()
	verdict_is_sealed = false
	_refresh_grid()

func set_case_title(value: String) -> void:
	if title_label != null:
		title_label.text = value.left(42) if not value.is_empty() else "No active case"

func stamp_inquiry(action_id: StringName) -> bool:
	if not ACTION_GLYPHS.has(action_id) or impressions.size() >= 8 or verdict_is_sealed:
		return false
	var record: Dictionary = ACTION_GLYPHS[action_id]
	var glyph := String(record.glyph)
	impressions.append({"glyph": glyph, "label": String(record.label), "action_id": action_id})
	_refresh_grid()
	impression_added.emit(action_id, glyph)
	if not reduced_motion:
		var cell := grid.get_child(impressions.size() - 1) as Control
		if cell != null:
			cell.scale = Vector2(1.12, 1.12)
			var tween := create_tween()
			tween.tween_property(cell, "scale", Vector2.ONE, 0.12)
	return true

func seal_verdict() -> void:
	if impressions.size() >= 8 or verdict_is_sealed:
		return
	verdict_is_sealed = true
	impressions.append({"glyph": VERDICT_GLYPH, "label": "Verdict sealed", "action_id": &"verdict"})
	_refresh_grid()
	verdict_sealed.emit(VERDICT_GLYPH)
	if not reduced_motion:
		var tween := create_tween()
		tween.tween_property(self, "position", position + Vector2(2, 0), 0.025)
		tween.tween_property(self, "position", position - Vector2(2, 0), 0.025)
		tween.tween_property(self, "position", position, 0.025)

func _refresh_grid() -> void:
	for index in range(grid.get_child_count()):
		var cell := grid.get_child(index)
		var label := cell.get_child(0) as Label
		if index < impressions.size():
			var record: Dictionary = impressions[index]
			label.text = String(record.glyph)
			cell.tooltip_text = String(record.label)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			label.text = "·"
			cell.tooltip_text = "An unused clay impression position"
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clay_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#D4B58A")
	style.border_color = Color("#B88656")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style
