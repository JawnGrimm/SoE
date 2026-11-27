class_name CharacterCreationResolver
extends RefCounted
## Pure draft validation/preview; commit is the only WorldState mutation boundary.

static func load_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CharacterCreationResolver: missing catalog %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("CharacterCreationResolver: catalog root must be a Dictionary")
		return {}
	return parsed

static func _find_question(catalog: Dictionary, question_id: StringName) -> Dictionary:
	for question_data in catalog.get("questions", []):
		if StringName(question_data.get("id", "")) == question_id:
			return question_data
	return {}

static func _find_answer(question_data: Dictionary, answer_id: StringName) -> Dictionary:
	for answer in question_data.get("answers", []):
		if StringName(answer.get("id", "")) == answer_id:
			return answer
	return {}

static func validate(catalog: Dictionary, selections: CharacterCreationSelections) -> Dictionary:
	var errors: Array[String] = []
	if catalog.is_empty() or selections == null:
		return {"valid": false, "errors": ["Character creation catalog or selections are missing."]}
	if selections.committed:
		errors.append("This character-creation draft has already been committed.")
	if selections.character_name.strip_edges().is_empty():
		errors.append("Enter a name before confirming the biography.")
	if not CharacterCreationSelections.PRONOUNS.has(selections.pronouns):
		errors.append("Choose he, she, or they before the intake begins.")
	var selected_answers: Dictionary[StringName, Dictionary] = {}
	for question_data in catalog.get("questions", []):
		var question_id := StringName(question_data.get("id", ""))
		var answer_id := selections.get_answer(question_id)
		if answer_id == &"":
			errors.append("Choose an answer for %s." % String(question_data.get("title", question_id)))
			continue
		var answer := _find_answer(question_data, answer_id)
		if answer.is_empty():
			errors.append("The selected answer for %s is not in this intake." % question_id)
			continue
		selected_answers[question_id] = answer
	return {"valid": errors.is_empty(), "errors": errors, "selected_answers": selected_answers}

static func build_biography(catalog: Dictionary, selections: CharacterCreationSelections) -> String:
	var validation := validate(catalog, selections)
	if not validation.has("selected_answers"):
		return ""
	var origin_id := selections.get_answer(&"origin")
	var designation := String(catalog.get("designation_by_origin", {}).get(String(origin_id), "compound entrant"))
	var lines: Array[String] = [selections.character_name.strip_edges() + ", " + designation + ".", String(catalog.get("display_context", ""))]
	for question_data in catalog.get("questions", []):
		var answer := _find_answer(question_data, selections.get_answer(StringName(question_data.get("id", ""))))
		var fragment := String(answer.get("biography", "")).strip_edges()
		if not fragment.is_empty():
			lines.append(fragment)
	return "\n\n".join(lines)

static func build_collision_comments(catalog: Dictionary, selections: CharacterCreationSelections) -> Array[String]:
	var selected: Array[String] = []
	for answer_id in selections.answers.values():
		selected.append(String(answer_id))
	var comments: Array[String] = []
	for collision in catalog.get("collision_comments", []):
		var required: Array = collision.get("answer_ids", [])
		var matches := not required.is_empty()
		for required_id in required:
			if not selected.has(String(required_id)):
				matches = false
				break
		if matches:
			comments.append(String(collision.get("text", "")))
	return comments

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
	var biography_effect := EventEffect.new()
	biography_effect.effect_type = &"add_memory"
	biography_effect.target = "actor"
	biography_effect.parameters = {"memory_id": "character_creation_biography", "text": build_biography(catalog, selections), "involved": []}
	effects.append(biography_effect)
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
	# Keep the actor out of the world until all validation has passed.
	world.people[actor.id] = actor
	if not world.set_player(actor):
		world.people.erase(actor.id)
		return {"committed": false, "errors": ["The player character could not be registered in WorldState."]}
	actor.display_name = selections.character_name.strip_edges()
	actor.pronouns = selections.pronouns
	var origin_id := selections.get_answer(&"origin")
	actor.institutional_designation = String(catalog.get("designation_by_origin", {}).get(String(origin_id), "compound entrant"))
	executor.execute_all(effects, context)
	selections.committed = true
	return {"committed": true, "errors": [], "effect_count": effects.size()}

