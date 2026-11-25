class_name EffectExecutor
extends RefCounted

var _handlers: Dictionary[StringName, Callable] = {}

func _init() -> void:
    _handlers[&"add_trait"] = _add_trait
    _handlers[&"remove_trait"] = _remove_trait
    _handlers[&"change_opinion"] = _change_opinion
    _handlers[&"gain_skill_xp"] = _gain_skill_xp
    _handlers[&"create_form"] = _create_form
    _handlers[&"set_flag"] = _set_flag
    _handlers[&"clear_flag"] = _clear_flag
    _handlers[&"modify_resource"] = _modify_resource
    _handlers[&"resolve_form"] = _resolve_form
    _handlers[&"add_memory"] = _add_memory

func execute_all(effects: Array[EventEffect], ctx: EventContext) -> void:
    for effect in effects:
        execute(effect, ctx)

func execute(effect: EventEffect, ctx: EventContext) -> void:
    if not _handlers.has(effect.effect_type):
        push_warning("EffectExecutor: unknown effect '%s'" % effect.effect_type)
        return
    var subject := ctx.resolve_subject(effect.target)
    _handlers[effect.effect_type].call(subject, effect.parameters, ctx)

func _add_trait(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> void:
    var trait_id := StringName(p.get("trait_id", ""))
    if subject != null and trait_id != &"" and trait_id not in subject.traits:
        subject.traits.append(trait_id)

func _remove_trait(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> void:
    if subject != null:
        subject.traits.erase(StringName(p.get("trait_id", "")))

func _change_opinion(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    if subject == null:
        return
    var other := ctx.resolve_subject(String(p.get("other", "target")))
    if other == null:
        return
    var delta := int(p.get("amount", 0))
    subject.opinions[other.id] = int(subject.opinions.get(other.id, 0)) + delta
    var reasons: Array = subject.opinion_reasons.get(other.id, [])
    reasons.append({
        "year": ctx.year,
        "amount": delta,
        "reason": String(p.get("reason", "")),
    })
    subject.opinion_reasons[other.id] = reasons

func _gain_skill_xp(subject: PersonEntity, p: Dictionary, _ctx: EventContext) -> void:
    if subject != null:
        subject.skills.add_xp(StringName(p.get("skill", "")), int(p.get("amount", 0)))

func _create_form(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    if ctx.world == null:
        return
    ctx.world.enqueue_form({
        "form_type": StringName(p.get("form_type", "")),
        "subject_id": StringName(p.get("subject_id", "")),
        "urgency": int(p.get("urgency", 1)),
        "year": ctx.year,
    })

func _set_flag(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    var flag := StringName(p.get("flag", ""))
    var years := int(p.get("years", 0))
    var expiry := ctx.year + years if years > 0 else -1
    match String(p.get("scope", "world")):
        "world":
            if ctx.world != null: ctx.world.set_flag(flag, expiry)
        "actor":
            if ctx.actor != null and flag != &"": ctx.actor.flags[flag] = expiry
        "target":
            if subject != null and flag != &"": subject.flags[flag] = expiry

func _clear_flag(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    var flag := StringName(p.get("flag", ""))
    match String(p.get("scope", "world")):
        "world":
            if ctx.world != null: ctx.world.clear_flag(flag)
        "actor":
            if ctx.actor != null: ctx.actor.flags.erase(flag)
        "target":
            if subject != null: subject.flags.erase(flag)

func _modify_resource(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    if ctx.world != null:
        ctx.world.modify_resource(
            StringName(p.get("resource", "")),
            int(p.get("amount", 0)),
            String(p.get("scope", "world"))
        )

func _resolve_form(_subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    if ctx.world != null:
        ctx.world.resolve_form(p, ctx.year)

func _add_memory(subject: PersonEntity, p: Dictionary, ctx: EventContext) -> void:
    if subject == null:
        return
    var involved: Array = p.get("involved", [])
    subject.memory.append({
        "memory_id": StringName(p.get("memory_id", "")),
        "text": String(p.get("text", "")),
        "year": ctx.year,
        "involved": involved.duplicate(true),
    })
