class_name AssignmentDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var employer: StringName = &""
@export var compensation_resource: StringName = &"silver"
@export var compensation_amount: int = 0
@export var law_xp: int = 0
@export var opinion_reward: int = 0
@export var opinion_penalty: int = 0
@export var required_actions: Array[StringName] = []

func is_valid() -> bool:
	if id == &"" or title.strip_edges().is_empty() or employer == &"":
		return false
	if compensation_resource == &"" or compensation_amount < 0 or law_xp < 0:
		return false
	if required_actions.is_empty():
		return false
	var seen: Dictionary = {}
	for action_id in required_actions:
		if action_id == &"" or seen.has(action_id):
			return false
		seen[action_id] = true
	return true
