class_name CharacterCreationResolver
extends RefCounted
## Resolves an uncommitted draft into a biography and one effect batch.
## No WorldState mutation occurs during selection, validation, or preview.

static func load_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CharacterCreationResolver: missing catalog %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("CharacterCreationResolver: catalog root must be a Dictionary")
		return {}
	return parsed

static func validate(catalog: Dictionary, selections: CharacterCreationSelections) -> Dictionary:
	var errors: Array[String] = []
	if catalog.is_empty() or selections == null:
		return {"valid": false, "errors": ["Character creation catalog or selections are missing."]}
	if selections.committed:
		errors.append("This character-creation draft has already been committed.")
	if selections.character_name.strip_edges().is_empty():
		errors.append("Enter a name before confirming the biography.")
	var selected_answers: Dictionary[StringName, Dictionary] = {}
	for question_data in catalog.get("questions", []):
		var question_id := StringName(question_data.get("id", ""))
		var answer_id := selections.get_answer(question_id)
		if answer_id == &"":
			errors.append("Choose an answer for %s." % String(question_data.get("title", question_id)))
			continue
		var answer := _find_answer(question_data, answer_id)
		if answer.is_empty():
			errors.append("The selected answer for %s is no longer available." % question_id)
			continue
		selected_answers[question_id] = answer
	for question_data in catalog.get("questions", []):
		var question_id := StringName(question_data.get("id", ""))
		if not selected_answers.has(question_id):
			continue
		var answer: Dictionary = selected_answers[question_id]
		var requirements: Dictionary = answer.get("requires", {})
		for required_question_variant in requirements.keys():
			var required_question := StringName(required_question_variant)
			var allowed: Array = requirements[required_question_variant]
			if not allowed.has(String(selections.get_answer(required_question))):
				errors.append("That combination is not available. Revisit %s before continuing." % required_question)
	return {"valid": errors.is_empty(), "errors": errors, "selected_answers": selected_answers}

static func build_biography(catalog: Dictionary, selections: CharacterCreationSelections) -> String:
	var validation := validate(catalog, selections)
	if not validation.has("selected_answers"):
		return ""
	var lines: Array[String] = [selections.character_name.strip_edges(), "Uruk · c. 3200 BCE"]
	for question_data in catalog.get("questions", []):
		var answer := _find_answer(question_data, selections.get_answer(StringName(question_data.get("id", ""))))
		var fragment := String(answer.get("biography", "")).strip_edges()
		if not fragment.is_empty():
			lines.append(fragment)
	return "\n\n".join(lines)

static func build_effects(catalog: Dictionary, selections: CharacterCreationSelections) -> Array[EventEffect]:
	var validation := validate(catalog, selections)
	if not bool(validation.get("valid", false)):
		return []
	var effects: Array[EventEffect] = []
	for question_data in catalog.get("questions", []):
		var answer := _find_answer(question_data, selections.get_answer(StringName(question_data.get("id", ""))))
		for effect_data in answer.get("effects", []):
			var effect := EventEffect.new()
			effect.effect_type = StringName(effect_data.get("effect_type", ""))
			effect.target = String(effect_data.get("target", "actor"))
			effect.parameters = effect_data.get("parameters", {}).duplicate(true)
			effects.append(effect)
	return effects

static func commit(catalog: Dictionary, selections: CharacterCreationSelections, world: WorldState, actor: PersonEntity, era: EraDef, executor: EffectExecutor) -> Dictionary:
	var validation := validate(catalog, selections)
	if not bool(validation.get("valid", false)):
		return {"committed": false, "errors": validation.get("errors", [])}
	if world == null or actor == null or executor == null:
		return {"committed": false, "errors": ["World, actor, and effect executor are required."]}
	if world.people.has(actor.id) and world.get_person(actor.id) != actor:
		return {"committed": false, "errors": ["A different person already uses this character ID."]}
	var effects := build_effects(catalog, selections)
	var context := EventContext.new()
	context.world = world
	context.actor = actor
	context.era = era
	context.year = world.year
	# The only mutation point: the draft actor enters WorldState and every
	# selected consequence uses the same EventEffect vocabulary as gameplay.
	world.people[actor.id] = actor
	executor.execute_all(effects, context)
	actor.display_name = selections.character_name.strip_edges()
	selections.committed = true
	return {"committed": true, "errors": [], "effect_count": effects.size()}

static func _find_answer(question_data: Dictionary, answer_id: StringName) -> Dictionary:
	for answer in question_data.get("answers", []):
		if StringName(answer.get("id", "")) == answer_id:
			return answer
	return {}
