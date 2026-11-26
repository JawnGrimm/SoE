class_name PersonEntity
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var skills := SkillsComponent.new()
var office_id: StringName = &""
var traits: Array[StringName] = []
var vulnerabilities: Dictionary[StringName, int] = {}
var flags: Dictionary[StringName, int] = {}
var memory: Array[Dictionary] = []
var personal_stockpiles: Dictionary[StringName, int] = {}
# Directed social ties keyed by the other person's entity id.
var relationships: Dictionary[StringName, Dictionary] = {}

func get_personal_resource(resource_id: StringName) -> int:
	return personal_stockpiles.get(resource_id, 0)

func modify_personal_resource(resource_id: StringName, amount: int) -> void:
	if resource_id == &"":
		push_warning("PersonEntity: refusing personal resource change with empty id")
		return
	personal_stockpiles[resource_id] = maxi(0, get_personal_resource(resource_id) + amount)

func get_opinion(other_id: StringName) -> int:
	var tie: Dictionary = relationships.get(other_id, {})
	return int(tie.get("opinion", 0))

func set_opinion(other_id: StringName, value: int) -> void:
	if other_id == &"":
		return
	var tie: Dictionary = relationships.get(other_id, {})
	tie["opinion"] = value
	if not tie.has("strength"):
		tie["strength"] = value
	relationships[other_id] = tie

func change_opinion(other_id: StringName, amount: int, reason: String, current_year: int) -> void:
	if other_id == &"":
		return
	var tie: Dictionary = relationships.get(other_id, {})
	tie["opinion"] = int(tie.get("opinion", 0)) + amount
	var reasons: Array = tie.get("reasons", [])
	reasons.append({"year": current_year, "amount": amount, "reason": reason})
	tie["reasons"] = reasons
	if not tie.has("strength"):
		tie["strength"] = int(tie["opinion"])
	relationships[other_id] = tie
var liege_id: StringName = &""
var spouse_id: StringName = &""
var rival_id: StringName = &""

func has_flag(flag: StringName, current_period: int) -> bool:
	if not flags.has(flag):
		return false
	var expiry: int = flags[flag]
	return expiry == -1 or current_period < expiry
