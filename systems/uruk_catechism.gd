class_name UrukCatechism
extends RefCounted

static func choose_path(world: WorldState, actor: PersonEntity, path: StringName) -> bool:
	if world == null or actor == null or path not in [&"path_temple", &"path_landing"]:
		return false
	actor.flags[path] = -1
	if path == &"path_temple":
		world.get_person(&"ur_nanna").change_opinion(actor.id, 5, "Path catechism: temple instruction", world.year)
		world.get_person(&"nin_kasi").change_opinion(actor.id, 3, "Path catechism: temple instruction", world.year)
		world.enqueue_form({"form_type": &"pension_roll", "subject_id": &"brewing_house_account", "urgency": 1, "year": world.year})
	else:
		world.get_person(&"enlil_kisu").change_opinion(actor.id, 5, "Path catechism: landing instruction", world.year)
		world.get_person(&"geme_inana").change_opinion(actor.id, 3, "Path catechism: landing instruction", world.year)
		world.enqueue_form({"form_type": &"consignment_receipt", "subject_id": &"temple_consignment", "urgency": 1, "year": world.year})
	return true

static func choose_mentor(world: WorldState, actor: PersonEntity, mentor_id: StringName) -> bool:
	if world == null or actor == null:
		return false
	var mentor_data := {
		&"shuruppak_ilu": [&"arithmetic", &"exacting"],
		&"utu_mansum": [&"law", &"stubborn"],
		&"enlil_kisu": [&"stewardship", &"protective"],
		&"nin_kasi": [&"rhetoric", &"diplomatic"]
	}
	if not mentor_data.has(mentor_id):
		return false
	var selection: Array = mentor_data[mentor_id]
	var skill: StringName = selection[0]
	var trait_id: StringName = selection[1]
	actor.skills.levels[skill] = actor.skills.get_level(skill) + 1
	if trait_id not in actor.traits:
		actor.traits.append(trait_id)
	var mentor := world.get_person(mentor_id)
	if mentor == null:
		return false
	mentor.opinions[actor.id] = int(mentor.opinions.get(actor.id, 0)) + 5
	return true
