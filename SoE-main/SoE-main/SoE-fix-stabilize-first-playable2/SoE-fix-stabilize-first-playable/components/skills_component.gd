class_name SkillsComponent
extends RefCounted

var levels: Dictionary[StringName, int] = {
    &"literacy": 1,
    &"arithmetic": 1,
    &"law": 1,
    &"rhetoric": 1,
    &"intrigue": 1,
    &"stewardship": 1,
}
var xp: Dictionary[StringName, int] = {}

func get_level(skill: StringName) -> int:
    return levels.get(skill, 0)

func add_xp(skill: StringName, amount: int) -> bool:
    if skill == &"" or amount <= 0:
        return false
    var current_xp: int = xp.get(skill, 0) + amount
    var current_level: int = levels.get(skill, 1)
    var leveled := false
    while current_xp >= current_level * 100:
        current_xp -= current_level * 100
        current_level += 1
        leveled = true
    xp[skill] = current_xp
    levels[skill] = current_level
    return leveled
