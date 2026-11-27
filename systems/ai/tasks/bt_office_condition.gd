@tool
extends BTCondition
## Shared office condition task; reads standard Blackboard context.
const Resolver = preload("res://systems/ai/office_agenda_resolver.gd")
@export var condition_id: StringName = &""
func _generate_name() -> String:
	return "Office Condition: %s" % String(condition_id)
func _tick(_delta: float) -> Status:
	var actor := blackboard.get_var(&"actor", null) as PersonEntity
	var institution: Dictionary = blackboard.get_var(&"institution", {})
	var world := blackboard.get_var(&"world", null) as WorldState
	var institution_id := StringName(blackboard.get_var(&"institution_id", &""))
	if actor == null or world == null: return FAILURE
	return SUCCESS if Resolver.condition_passes(actor, institution, world, institution_id, condition_id) else FAILURE
