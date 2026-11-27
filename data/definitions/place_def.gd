class_name PlaceDef
extends Resource
## Immutable historical settlement definition. Runtime conditions belong in WorldState.

@export var id: StringName = &""
@export var display_name: String = ""
## Settlement archetype: metropolis, rival_city, sacred_center, river_colony, trade_enclave, highland_partner.
@export var place_type: StringName = &"metropolis"
@export var region: StringName = &"lower_mesopotamia"
@export var parent_place_id: StringName = &""
## Baseline framing only; runtime diplomacy belongs to WorldState.
@export var political_relation: StringName = &"autonomous_peer"
@export var exports: Array[StringName] = []
@export var imports: Array[StringName] = []
@export var connected_to: Array[StringName] = []
@export var era_id: StringName = &"uruk_storehouse"
## Authored position on the regional survey layer; zero means not plotted in this map.
@export var survey_position: Vector2 = Vector2.ZERO

func is_valid() -> bool:
	return id != &"" and not display_name.strip_edges().is_empty() and era_id != &""
