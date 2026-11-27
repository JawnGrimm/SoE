@tool
extends BTAction
## Requests an intent. The SoE resolver, not this task, mutates authoritative state.

@export var intent_id: StringName = &""

func _generate_name() -> String:
	return "Request Intent: %s" % String(intent_id)

func _tick(_delta: float) -> Status:
	if agent == null:
		return FAILURE
	var result: Dictionary = agent.call("request_intent", intent_id)
	return SUCCESS if bool(result.get("success", false)) else FAILURE
