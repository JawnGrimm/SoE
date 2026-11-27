class_name RegionalSurveyMap
extends PanelContainer
## Diegetic regional survey. Worldmap Builder renders the authored route graph;
## RouteNetwork and TravelService remain the authoritative gameplay systems.

signal travel_requested(route_id: StringName, destination_id: StringName)
signal close_requested

const WorldmapViewScript = preload("res://addons/worldmap_builder/nodes/worldmap_view.gd")
const WorldmapGraphScript = preload("res://addons/worldmap_builder/nodes/worldmap_graph.gd")
const WorldmapNodeDataScript = preload("res://addons/worldmap_builder/resource_types/worldmap_node_data.gd")
const WorldmapStyleScript = preload("res://addons/worldmap_builder/resource_types/wordmap_style.gd")

var route_network: RouteNetwork
var world: WorldState
var map_view: Variant
var graph: Variant
var map_nodes: Dictionary[StringName, int] = {}
var selected_route_id: StringName = &""
var selected_destination_id: StringName = &""
var travel_allowed := true

var heading: Label
var route_summary: Label
var location_summary: Label
var board_button: Button
var map_canvas: Control

func _ready() -> void:
	_build_surface()

func configure(network: RouteNetwork, current_world: WorldState, allow_travel: bool = true) -> bool:
	if network == null or current_world == null:
		return false
	route_network = network
	world = current_world
	travel_allowed = allow_travel
	selected_route_id = &""
	selected_destination_id = &""
	_build_route_graph()
	_refresh_route_summary()
	return map_view != null

func get_map_node_count() -> int:
	return map_nodes.size()

func get_map_connection_count() -> int:
	return graph.get_connections().size() if graph != null else 0

func select_destination(destination_id: StringName) -> bool:
	selected_route_id = &""
	selected_destination_id = &""
	if route_network == null or world == null or destination_id == world.current_location_id:
		_refresh_route_summary()
		return false
	var route := route_network.get_route_between(world.current_location_id, destination_id)
	if route == null:
		_refresh_route_summary()
		return false
	selected_route_id = route.id
	selected_destination_id = destination_id
	_refresh_route_summary()
	return can_board_selected_route()

func can_board_selected_route() -> bool:
	return travel_allowed and route_network != null and world != null and selected_route_id != &"" and selected_destination_id != &"" and route_network.get_transit_periods(selected_route_id, world.current_location_id, selected_destination_id) > 0

func board_selected_route() -> bool:
	if not can_board_selected_route():
		return false
	travel_requested.emit(selected_route_id, selected_destination_id)
	return true

func get_selected_route_id() -> StringName:
	return selected_route_id

func get_selected_destination_id() -> StringName:
	return selected_destination_id

func _build_surface() -> void:
	if heading != null:
		return
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#d6c29b")
	paper.border_color = Color("#6d5131")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(2)
	paper.content_margin_left = 12
	paper.content_margin_right = 12
	paper.content_margin_top = 8
	paper.content_margin_bottom = 8
	add_theme_stylebox_override("panel", paper)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	heading = Label.new()
	heading.text = "REGIONAL SURVEY / LOWER EUPHRATES"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("#3a2818"))
	title_row.add_child(heading)
	var close_button := Button.new()
	close_button.text = "ROLL SURVEY"
	close_button.add_theme_font_size_override("font_size", 10)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	title_row.add_child(close_button)
	location_summary = Label.new()
	location_summary.add_theme_font_size_override("font_size", 11)
	location_summary.add_theme_color_override("font_color", Color("#59432a"))
	body.add_child(location_summary)
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(0, 210)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.clip_contents = true
	body.add_child(map_canvas)
	route_summary = Label.new()
	route_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_summary.custom_minimum_size.y = 24
	route_summary.add_theme_font_size_override("font_size", 12)
	route_summary.add_theme_color_override("font_color", Color("#3a2818"))
	body.add_child(route_summary)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(footer)
	board_button = Button.new()
	board_button.text = "SELECT A CONNECTED SETTLEMENT"
	board_button.disabled = true
	board_button.custom_minimum_size = Vector2(270, 34)
	board_button.add_theme_font_size_override("font_size", 12)
	board_button.pressed.connect(board_selected_route)
	footer.add_child(board_button)

func _build_route_graph() -> void:
	if map_view != null and is_instance_valid(map_view):
		map_canvas.remove_child(map_view)
		map_view.queue_free()
	map_nodes.clear()
	map_view = WorldmapViewScript.new()
	map_view.name = "WorldmapBuilderSurveyView"
	map_view.set("auto_minsize", false)
	map_view.custom_minimum_size = Vector2(0, 210)
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inactive_style := _make_style(Color("#806443"), Color("#9c8158"), 0)
	var active_style := _make_style(Color("#5a3820"), Color("#6c4b28"), 2)
	var reachable_style := _make_style(Color("#4e6650"), Color("#8b7447"), 1)
	map_view.set("style_inactive", inactive_style)
	map_view.set("style_active", active_style)
	map_view.set("style_can_activate", reachable_style)
	graph = WorldmapGraphScript.new()
	graph.name = "RegionalRouteGraph"
	graph.set("connection_mode", 2) # Custom: route costs remain authored by the route definitions.
	var plotted_places: Dictionary[StringName, PlaceDef] = {}
	for route in route_network.routes.values():
		plotted_places[route.origin_id] = route_network.get_place(route.origin_id)
		plotted_places[route.destination_id] = route_network.get_place(route.destination_id)
	var place_ids: Array[StringName] = []
	for place_id in plotted_places:
		if plotted_places[place_id] != null:
			place_ids.append(place_id)
	place_ids.sort()
	graph.set("node_count", place_ids.size())
	var current_index := 0
	for index in range(place_ids.size()):
		var place_id := place_ids[index]
		var place: PlaceDef = plotted_places[place_id]
		var node_data: Variant = WorldmapNodeDataScript.new()
		node_data.id = place.id
		node_data.name = place.display_name
		node_data.desc = "%s / %s" % [String(place.place_type).replace("_", " ").to_upper(), String(place.political_relation).replace("_", " ").to_upper()]
		node_data.texture = _make_place_marker(index, place_id == world.current_location_id)
		graph.set("node_%d/data" % index, node_data)
		graph.set("node_%d/position" % index, place.survey_position)
		map_nodes[place_id] = index
		if place_id == world.current_location_id:
			current_index = index
	for route in route_network.routes.values():
		if not map_nodes.has(route.origin_id) or not map_nodes.has(route.destination_id):
			continue
		graph.set_connected(map_nodes[route.origin_id], map_nodes[route.destination_id], true)
	map_view.set("initial_item", graph)
	map_view.set("initial_node", current_index)
	map_view.set("initial_node_value", 1)
	map_view.node_gui_input.connect(_on_map_node_input)
	map_view.add_child(graph)
	for place_id in place_ids:
		var place: PlaceDef = plotted_places[place_id]
		var name_label := Label.new()
		name_label.text = place.display_name.to_upper()
		name_label.position = place.survey_position + Vector2(-58, 23)
		name_label.size = Vector2(116, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color("#3a2818"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_view.add_child(name_label)
	map_canvas.add_child(map_view)

func _make_style(icon_tint: Color, line_tint: Color, priority: int) -> Resource:
	var style: Resource = WorldmapStyleScript.new()
	style.set("icon_modulate", icon_tint)
	style.set("connection_modulate", line_tint)
	style.set("priority", priority)
	var line_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	line_image.fill(Color.WHITE)
	style.set("straight_tex", ImageTexture.create_from_image(line_image))
	style.set("straight_tex_region", Rect2(0, 0, 4, 4))
	return style

func _make_place_marker(index: int, is_current: bool) -> Texture2D:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	var center := Vector2(19.5, 19.5)
	var fill := Color("#65421f") if is_current else Color("#8a754e")
	var border := Color("#e4cf9e")
	for y in range(40):
		for x in range(40):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= 17.0:
				image.set_pixel(x, y, border if distance >= 13.5 else fill)
				if distance <= 3.0:
					image.set_pixel(x, y, Color("#f2dfb5"))
	return ImageTexture.create_from_image(image)

func _on_map_node_input(event: InputEvent, _path: NodePath, node_index: int, data: WorldmapNodeData) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	select_destination(data.id)

func _refresh_route_summary() -> void:
	if world == null or route_network == null or route_summary == null:
		return
	var current_place := route_network.get_place(world.current_location_id)
	var current_name := current_place.display_name if current_place != null else String(world.current_location_id)
	location_summary.text = "YOU ARE HERE: %s  /  %s, MONTH %02d" % [current_name.to_upper(), CalendarFormatter.format_year(world.year), world.period + 1]
	if not travel_allowed:
		route_summary.text = "Finish the open docket before departure. The regional routes remain visible, but the barge will wait."
		board_button.text = "FINISH CURRENT DOCKET FIRST"
		board_button.disabled = true
		return
	if selected_route_id == &"":
		route_summary.text = "Choose a connected settlement on the survey. The current seal marks your place of departure."
		board_button.text = "SELECT A CONNECTED SETTLEMENT"
		board_button.disabled = true
		return
	var route := route_network.get_route(selected_route_id)
	var destination := route_network.get_place(selected_destination_id)
	var periods := route_network.get_transit_periods(selected_route_id, world.current_location_id, selected_destination_id)
	var status := String(route_network.get_route_status(selected_route_id)).to_upper()
	var route_name := route.display_name if not route.display_name.is_empty() else String(route.route_type).replace("_", " ").to_upper()
	route_summary.text = "%s TO %s  /  %d PERIOD%s  /  ROUTE %s" % [route_name.to_upper(), destination.display_name.to_upper(), periods, "" if periods == 1 else "S", status]
	if periods > 0:
		var mode := "BOARD RIVER BARGE" if route.route_type == &"river" else "TAKE THE OVERLAND ROAD"
		board_button.text = "%s  /  %d PERIOD%s" % [mode, periods, "" if periods == 1 else "S"]
	else:
		board_button.text = "ROUTE CLOSED"
	board_button.disabled = periods <= 0
