class_name ConditionEvaluator
extends RefCounted

var _handlers: Dictionary[StringName, Callable] = {}

func _init() -> void:
    _handlers[&"has_trait"] = _has_trait
    _handlers[&"lacks_trait"] = _lacks_trait
    _handlers[&"skill_at_least"] = _skill_at_least
    _handlers[&"in_office"] = _in_office
    _handlers[&"year_in_range"] = _year_in_range
    _handlers[&"opinion_compare"] = _opinion_compare
    _handlers[&"has_pending_form"] = _has_pending_form
    _handlers[&"flag_set"] = _flag_set
    _handlers[&"resource_compare"] = _resource_compare
    _handlers[&"recent_event"] = _recent_event

func evaluate_all(conditions: Array[EventCondition], ctx: EventContext) -> bool:
    for condition in conditions:
        if not evaluate(condition, ctx):
            return false
    return true

func evaluate(condition: EventCondition, ctx: EventContext) -> bool:
    if not _handlers.has(condition.condition_type):
        push_warning("ConditionEvaluator: unknown condition '%s'" % condition.condition_type)
        return false
    var subject := ctx.resolve_subject(condition.target)
    return bool(_handlers[condition.condition_type].call(subject, condition.parameters, ctx))

func _has_trait(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> bool:
    return subject != null and StringName(p.get("trait_id", "")) in subject.traits

func _lacks_trait(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> bool:
    return subject != null and not (StringName(p.get("trait_id", "")) in subject.traits)

func _skill_at_least(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> bool:
    if subject == null:
        return false
    return subject.skills.get_level(StringName(p.get("skill", ""))) >= int(p.get("level", 1))

func _in_office(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> bool:
    if subject == null or subject.office_id == &"":
        return false
    var required := StringName(p.get("office_id", ""))
    return required == &"" or subject.office_id == required

func _year_in_range(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
    return ctx.year >= int(p.get("min", -999999)) and ctx.year <= int(p.get("max", 999999))

func _has_pending_form(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
    return ctx.world != null and ctx.world.has_pending_form(StringName(p.get("form_type", "")))

func _flag_set(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
    var flag := StringName(p.get("flag", ""))
    match String(p.get("scope", "world")):
        "world":
            return ctx.world != null and ctx.world.has_flag(flag, ctx.world.current_period_index())
        "actor":
            return ctx.actor != null and ctx.actor.has_flag(flag, ctx.world.current_period_index())
        "target":
            return subject != null and subject.has_flag(flag, ctx.world.current_period_index())
        _:
            return false

func _resource_compare(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
    if ctx.world == null:
        return false
    var actual := ctx.world.get_resource(StringName(p.get("resource", "")))
    var expected := int(p.get("value", 0))
    match String(p.get("comparison", ">=")):
        ">=": return actual >= expected
        "<=": return actual <= expected
        "==": return actual == expected
        _:
            push_warning("ConditionEvaluator: invalid resource comparison")
            return false

func _recent_event(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
    return ctx.world != null and ctx.world.was_event_recent(
        StringName(p.get("event_id", "")), ctx.year, int(p.get("within_years", 1))
    )


func _opinion_compare(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> bool:
	if subject == null or ctx.actor == null:
		return false
	var other_id := StringName(p.get("other", ""))
	var opinion_owner := subject
	if other_id != &"":
		var other := ctx.world.get_person(other_id) if ctx.world != null else null
		if other == null:
			return false
		opinion_owner = other
	var value := int(opinion_owner.opinions.get(ctx.actor.id, 0))
	var expected := int(p.get("value", 0))
	match String(p.get("comparison", ">=")):
		">=": return value >= expected
		"<=": return value <= expected
		"==": return value == expected
		_:
			push_warning("ConditionEvaluator: invalid opinion comparison")
			return false
