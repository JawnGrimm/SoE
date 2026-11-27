class_name OutcomeAffordability
extends RefCounted

static func is_outcome_disabled_for_actor(event_id: StringName, outcome: EventOutcome, personal_silver: int) -> bool:
	if event_id != &"challenge_quayside_stoppage" or outcome == null or personal_silver >= 4:
		return false
	for effect in outcome.effects:
		if effect.effect_type != &"modify_resource":
			continue
		var parameters: Dictionary = effect.parameters
		if StringName(parameters.get("resource", "")) == &"silver" and String(parameters.get("scope", "")) == "actor" and int(parameters.get("amount", 0)) < 0:
			return true
	return false
