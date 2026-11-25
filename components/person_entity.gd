class_name PersonEntity
extends RefCounted

var id: StringName = &""
var skills := SkillsComponent.new()
var office_id: StringName = &""
var traits: Array[StringName] = []
var flags: Dictionary[StringName, int] = {} # absolute expiry period; -1 means permanent
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
	return expiry < 0 or current_period < expiry
