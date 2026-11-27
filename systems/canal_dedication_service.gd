class_name CanalDedicationService
extends RefCounted
## Applies the three authored terminal acts for the Great Canal Cut.

static func can_personal_seal(actor: PersonEntity) -> bool:
	return actor != null and actor.skills.get_level(&"law") >= 2 and actor.skills.get_level(&"literacy") >= 2

static func apply_choice(world: WorldState, actor: PersonEntity, choice: StringName) -> bool:
	if world == null or actor == null or world.world_flags.has(&"canal_dedication_concluded"):
		return false
	if choice == &"personal_seal" and not can_personal_seal(actor):
		return false
	match choice:
		&"honor_crews":
			world.change_faction_standing(&"boatmens_guild", 25)
			world.change_faction_standing(&"council_of_elders", 8)
			world.world_flags[&"canal_crew_legacy"] = 1
			actor.traits.append(&"honors_labor") if not actor.traits.has(&"honors_labor") else null
		&"temple_only":
			world.change_faction_standing(&"eanna_temple", 35)
			actor.resources[&"silver"] = int(actor.resources.get(&"silver", 0)) + 8
			world.world_flags[&"canal_temple_claim"] = 1
		&"personal_seal":
			world.world_flags[&"canal_personal_seal"] = 1
			world.change_faction_standing(&"council_of_elders", 15)
			actor.flags[&"name_on_monument"] = -1
		_:
			return false
	world.world_flags[&"canal_dedication_concluded"] = 1
	world.world_flags[&"canal_dedication_choice"] = int(choice.hash())
	var epic: Dictionary = world.epics.get(&"great_canal_cut", {})
	epic["completed"] = true
	epic["active"] = false
	epic["dedicated"] = true
	epic["dedication_choice"] = choice
	world.epics[&"great_canal_cut"] = epic
	world.cedar_desk_log.append({"year": world.year, "period": world.period, "title": "DEDICATION OF THE SLUICE GATES", "summary": "The scribe's final seal was entered on the monument: %s." % String(choice).replace("_", " ")})
	return true
