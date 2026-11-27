@tool
extends BTCondition
## Tests one period-level institutional condition through the SoE agent adapter.

@export var condition_id: StringName = &""

func _generate_name() -> String:
	return "SoE Condition: %s" % String(condition_id)

func _tick(_delta: float) -> Status:
	if agent == null:
		return FAILURE
	return SUCCESS if bool(agent.call("condition_passes", condition_id)) else FAILURE
