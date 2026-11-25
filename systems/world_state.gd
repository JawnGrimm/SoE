class_name WorldState
extends RefCounted

var year: int = 0
var stockpiles: Dictionary[StringName, int] = {}
var world_flags: Dictionary[StringName, int] = {}
var pending_forms: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var character_event_history: Dictionary[StringName, Array] = {}

func get_person(person_id: StringName) -> PersonEntity:
    return people.get(person_id)

var people: Dictionary[StringName, PersonEntity] = {}

func has_pending_form(form_type: StringName = &"") -> bool:
    for form in pending_forms:
        if form_type == &"" or StringName(form.get("form_type", "")) == form_type:
            return true
    return false

func enqueue_form(form: Dictionary) -> void:
    pending_forms.append(form.duplicate(true))

func get_resource(resource_id: StringName) -> int:
    return stockpiles.get(resource_id, 0)

func modify_resource(resource_id: StringName, amount: int, _scope: String = "world") -> void:
    if resource_id == &"":
        push_warning("WorldState: refusing resource change with empty id")
        return
    stockpiles[resource_id] = get_resource(resource_id) + amount

func set_flag(flag: StringName, expiry_year: int) -> void:
    if flag != &"":
        world_flags[flag] = expiry_year

func clear_flag(flag: StringName) -> void:
    world_flags.erase(flag)

func has_flag(flag: StringName, current_year: int) -> bool:
    if not world_flags.has(flag):
        return false
    var expiry: int = world_flags[flag]
    return expiry < 0 or current_year <= expiry

func record_event(event_id: StringName, actor_id: StringName, current_year: int) -> void:
    event_history.append({"event_id": event_id, "actor_id": actor_id, "year": current_year})
    if actor_id != &"":
        if not character_event_history.has(actor_id):
            character_event_history[actor_id] = []
        character_event_history[actor_id].append({"event_id": event_id, "year": current_year})

func has_event_fired(event_id: StringName) -> bool:
    for entry in event_history:
        if StringName(entry.get("event_id", "")) == event_id:
            return true
    return false

func has_character_fired(event_id: StringName, actor_id: StringName) -> bool:
    for entry in character_event_history.get(actor_id, []):
        if StringName(entry.get("event_id", "")) == event_id:
            return true
    return false

func was_event_recent(event_id: StringName, current_year: int, within_years: int) -> bool:
    for entry in event_history:
        if StringName(entry.get("event_id", "")) == event_id:
            var event_year: int = int(entry.get("year", -999999))
            if current_year - event_year <= within_years:
                return true
    return false
