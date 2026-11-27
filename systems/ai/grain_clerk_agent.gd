extends Node
## Temporary scene-tree adapter for one period-scoped LimboAI evaluation.
## The authoritative character and world state remain RefCounted SoE objects.

var world: WorldState
var clerk: PersonEntity
var institution_id: StringName = &"eanna_household"
var resolver := GrainClerkAgendaResolver.new()

func condition_passes(condition_id: StringName) -> bool:
	if world == null or clerk == null:
		return false
	var institution: Dictionary = world.institutions.get(institution_id, {})
	var place_id := StringName(institution.get("place_id", ""))
	match condition_id:
		&"north_bay_roof_leak_active":
			for hazard in world.hazards:
				if bool(hazard.get("active", false)) and (StringName(hazard.get("place_id", "")) == place_id or (institution_id == &"eanna_household" and StringName(hazard.get("place_id", "")) == &"north_bay")) and StringName(hazard.get("id", "")) == &"roof_leak":
					return true
			return false
		&"personal_fear_above_five":
			return int(clerk.vulnerabilities.get(&"personal_fear", 0)) > 5
		&"granary_barley_above_400":
			return int(institution.get("stockpiles", {}).get(&"barley", 0)) > 400
		&"household_silver_below_five":
			return int(institution.get("stockpiles", {}).get(&"silver", 0)) < 5
		_:
			push_warning("GrainClerkAgent: unknown condition '%s'" % condition_id)
			return false

func request_intent(intent_id: StringName) -> Dictionary:
	if resolver == null:
		return {"success": false, "reason": "No SoE intent resolver is configured."}
	return resolver.resolve_intent(world, clerk, intent_id, institution_id)
