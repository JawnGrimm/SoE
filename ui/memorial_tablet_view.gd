class_name MemorialTabletView
extends Control
## Presentation-only career epilogue. The supplied summary is a derived snapshot.

signal return_to_title
signal succession_requested
signal restart_requested

const STONE := Color("#D4B58A")
const INK := Color("#261C14")
const GOLD := Color("#8A642F")

var summary: Dictionary = {}

func present(record: Dictionary) -> void:
	summary = record.duplicate(true)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := ColorRect.new()
	backing.color = Color("#17120E")
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 760)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	var tablet := PanelContainer.new()
	tablet.custom_minimum_size = Vector2(920, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = STONE
	style.border_color = Color("#6F512E")
	style.set_border_width_all(8)
	style.set_corner_radius_all(8)
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	tablet.add_theme_stylebox_override("panel", style)
	scroll.add_child(tablet)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	tablet.add_child(body)
	var header := _label("ERA I: URUK ARCHAIC (3200 BCE) — CAREER RECORD CONCLUDED", 17, INK)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(header)
	body.add_child(HSeparator.new())
	body.add_child(_label("%s\nFinal office: %s\nOrientation: %s\nYears in service: %d" % [summary.get("character_name", "Unknown Scribe"), summary.get("final_office", "No office"), summary.get("starting_orientation", "Unrecorded"), int(summary.get("years_in_service", 0))], 16, INK))
	var epitaph := _label(String(summary.get("epitaph", "The Diligent Keeper of the Daybook")), 29, GOLD)
	epitaph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epitaph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(epitaph)
	body.add_child(_label("THE PURSE\nSilver earned: %d   Held: %d\nDebt cleared: %d   Defaulted: %d   Unpaid upkeep: %d\nNet worth: %d" % [int(summary.get("silver_earned", 0)), int(summary.get("silver_held", 0)), int(summary.get("debt_cleared", 0)), int(summary.get("debt_defaulted", 0)), int(summary.get("unpaid_upkeep", 0)), int(summary.get("net_worth", 0))], 15, INK))
	body.add_child(_label("THE LAW & THE ARCHIVE\nLaw: %d   Literacy: %d   Arithmetic: %d\nRhetoric: %d   Intrigue: %d   Stewardship: %d\nIntegrity: %d / 100   Corruption: %d / 100\nAudit exposure: %d   Reprimands survived: %d\nScandals buried: %d" % [int(summary.get("law", 0)), int(summary.get("literacy", 0)), int(summary.get("arithmetic", 0)), int(summary.get("rhetoric", 0)), int(summary.get("intrigue", 0)), int(summary.get("stewardship", 0)), int(summary.get("integrity_score", 0)), int(summary.get("corruption_score", 0)), int(summary.get("audit_exposure", 0)), int(summary.get("audit_reprimands_survived", 0)), int(summary.get("scandals_buried", 0))], 15, INK))
	var standings: Dictionary = summary.get("character_standings", {})
	var faction_scores: Dictionary = summary.get("faction_standings", {})
	var faction_labels := {
		&"eanna_temple": "Eanna Temple",
		&"council_of_elders": "City Elders",
		&"boatmens_guild": "Boatmen",
		&"provincial_frontier": "Provincial Frontier"
	}
	var standing_lines := PackedStringArray()
	for faction_id in faction_labels:
		standing_lines.append("%s: %+d" % [String(faction_labels[faction_id]), int(faction_scores.get(faction_id, 0))])
	for person_name in standings:
		standing_lines.append("%s: %+d" % [String(person_name), int(standings[person_name])])
	body.add_child(_label("THE CITY & THE PROVINCE\nPrimary legacy: %s\nSettled cases: %d\n%s" % [summary.get("primary_legacy_faction", "Unrecorded"), int(summary.get("total_cases_settled", 0)), "\n".join(standing_lines)], 15, INK))
	body.add_child(_label("THE GREAT CANAL CUT\nProgress: %d / %d   Labor: %s\nConcluded: %s, period %d" % [int(summary.get("canal_progress", 0)), int(summary.get("canal_target", 100)), summary.get("canal_labor_outcome", "unrecorded"), CalendarFormatter.format_year(int(summary.get("end_year", -3200))), int(summary.get("period", 1))], 15, INK))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var copy := Button.new()
	copy.text = "Copy Career Summary to Clipboard"
	copy.custom_minimum_size.y = 48
	copy.focus_mode = Control.FOCUS_ALL
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(CareerEvaluator.generate_export_text(summary)))
	actions.add_child(copy)
	var title := Button.new()
	title.text = "Conclude Alpha Slice & Return to Title"
	title.custom_minimum_size.y = 48
	title.focus_mode = Control.FOCUS_ALL
	title.pressed.connect(func() -> void: return_to_title.emit())
	actions.add_child(title)
	var restart := Button.new()
	restart.text = "Begin New Career"
	restart.custom_minimum_size.y = 48
	restart.focus_mode = Control.FOCUS_ALL
	restart.pressed.connect(func() -> void: restart_requested.emit())
	actions.add_child(restart)
	var succession := Button.new()
	succession.text = "Pass Seal to Next Scribe"
	succession.custom_minimum_size.y = 48
	succession.focus_mode = Control.FOCUS_ALL
	succession.pressed.connect(func() -> void: succession_requested.emit())
	actions.add_child(succession)
	copy.grab_focus()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
