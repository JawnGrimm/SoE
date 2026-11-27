extends Node
## Temporary scene-tree adapter for one period-scoped LimboAI evaluation.
## The authoritative character and world state remain RefCounted SoE objects.

var world: WorldState
var clerk: PersonEntity
var resolver := GrainClerkAgendaResolver.new()

func condition_passes(condition_id: StringName) -> bool:
	if world == null or clerk == null:
		return false
	match condition_id:
		&"north_bay_roof_leak_active":
			return world.has_active_hazard(&"north_bay", &"roof_leak")
		&"personal_fear_above_five":
			return int(clerk.vulnerabilities.get(&"personal_fear", 0)) > 5
		&"granary_barley_above_400":
			return world.get_resource(&"barley", "institution", "", &"eanna_household") > 400
		&"household_silver_below_five":
			return world.get_resource(&"silver", "institution", "", &"eanna_household") < 5
		_:
			push_warning("GrainClerkAgent: unknown condition '%s'" % condition_id)
			return false

func request_intent(intent_id: StringName) -> Dictionary:
	if resolver == null:
		return {"success": false, "reason": "No SoE intent resolver is configured."}
	return resolver.resolve_intent(world, clerk, intent_id)
