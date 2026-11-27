class_name CedarDeskHeader
extends HBoxContainer
## Presentation-only status strip. Reads live WorldState and PersonEntity values.

static func format_purse(silver: int, currency: String) -> String:
	return "PURSE: %d %s" % [silver, currency.to_upper()]

static func format_arrears(debt: int, unpaid_upkeep: int) -> String:
	return "ARREARS: %d DEBT%s" % [maxi(0, debt), (" · UPKEEP %d" % unpaid_upkeep) if unpaid_upkeep > 0 else ""]

static func arrears_visible(debt: int, unpaid_upkeep: int) -> bool:
	return debt > 0 or unpaid_upkeep > 0

static func exposure_visible(exposure: int) -> bool:
	return exposure > 0

static func format_exposure(exposure: int) -> String:
	return "EXPOSURE: %d" % maxi(0, exposure)

var place_label: Label
var office_label: Label
var purse_label: Label
var arrears_label: Label
var exposure_label: Label
var date_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	place_label = _make_label("PLACE / SEASON", 13, "#EDE0C6")
	place_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(place_label)
	office_label = _make_label("OFFICE", 14, "#D4B58A")
	office_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	office_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(office_label)
	date_label = _make_label("YEAR", 14, "#EDE0C6")
	add_child(date_label)
	purse_label = _make_label("PURSE", 14, "#E0B85C")
	add_child(purse_label)
	arrears_label = _make_label("", 13, "#C45A3C")
	add_child(arrears_label)
	exposure_label = _make_label("", 13, "#D68B3C")
	add_child(exposure_label)

func _make_label(text_value: String, font_size: int, color_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color_value))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label

func update_status(world: WorldState, actor: PersonEntity, era: EraDef) -> void:
	if world == null or actor == null:
		return
	var place: Dictionary = world.places.get(world.current_location_id, {})
	var place_name := String(place.get("name", world.current_location_id)).to_upper()
	var month := posmod(world.period, 12) + 1
	var season := ["INUNDATION", "INUNDATION", "INUNDATION", "EMERGENCE", "EMERGENCE", "EMERGENCE", "HARVEST", "HARVEST", "HARVEST", "REST", "REST", "REST"][month - 1]
	place_label.text = "%s · %s (M%02d)" % [place_name, season, month]
	var office := String(actor.office_id).replace("_", " ").capitalize()
	office_label.text = "OFFICE: %s" % (office if not office.is_empty() else "Apprentice Scribe")
	date_label.text = CalendarFormatter.format_year(world.year)
	var currency := String(era.currency_name) if era != null else "silver"
	var silver := int(actor.resources.get(&"silver", 0))
	purse_label.text = format_purse(silver, currency)
	var debt := maxi(0, int(actor.resources.get(&"debt", maxi(0, -silver))))
	var unpaid := int(actor.resources.get(&"unpaid_upkeep", 0))
	arrears_label.visible = arrears_visible(debt, unpaid)
	arrears_label.text = format_arrears(debt, unpaid)
	var exposure := int(world.world_flags.get(&"audit_exposure", world.world_flags.get(&"grain_scandal", 0)))
	exposure_label.visible = exposure_visible(exposure)
	exposure_label.text = format_exposure(exposure)
