class_name EventContext
extends RefCounted

var actor: PersonEntity
var target: PersonEntity
var world: WorldState
var era: EraDef
var year: int = 0

func resolve_subject(role: String) -> PersonEntity:
    match role:
        "actor":
            return actor
        "target":
            return target
        "liege":
            return world.get_person(actor.liege_id) if actor != null and world != null else null
        "spouse":
            return world.get_person(actor.spouse_id) if actor != null and world != null else null
        "rival":
            return world.get_person(actor.rival_id) if actor != null and world != null else null
        _:
            return null
