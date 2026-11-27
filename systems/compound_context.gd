class_name CompoundContext
extends RefCounted

static func institution_ids(world: WorldState, location_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if world == null or location_id == &"":
		return result
	for institution_value in world.institutions.keys():
		var institution_id := StringName(institution_value)
		var cursor := StringName(world.institutions[institution_id].get("place_id", ""))
		var visited: Dictionary = {}
		while cursor != &"" and not visited.has(cursor):
			if cursor == location_id:
				result.append(institution_id)
				break
			visited[cursor] = true
			cursor = StringName(world.places.get(cursor, {}).get("parent", ""))
	result.sort()
	return result

static func officials(world: WorldState, ids: Array[StringName]) -> Array[PersonEntity]:
	var result: Array[PersonEntity] = []
	if world == null:
		return result
	for institution_id in ids:
		for member_id in world.institutions.get(institution_id, {}).get("members", []):
			var person := world.get_person(StringName(member_id))
			if person != null and person.office_id != &"" and person not in result:
				result.append(person)
	return result
