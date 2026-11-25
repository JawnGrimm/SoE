class_name PersonEntity
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var skills := SkillsComponent.new()
var office_id: StringName = &""
var traits: Array[StringName] = []
var vulnerabilities: Dictionary[StringName, int] = {}
var flags: Dictionary[StringName, int] = {}
var opinions: Dictionary[StringName, int] = {}
var opinion_reasons: Dictionary[StringName, Array] = {}
var memory: Array[Dictionary] = []
var liege_id: StringName = &""
var spouse_id: StringName = &""
var rival_id: StringName = &""

func has_flag(flag: StringName, current_period: int) -> bool:
	if not flags.has(flag):
		return false
	var expiry: int = flags[flag]
	return expiry == -1 or current_period < expiry
