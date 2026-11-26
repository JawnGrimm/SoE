class_name CharacterCreationSelections
extends RefCounted
## Temporary player-authored choices. This object is not part of WorldState.

var answers: Dictionary[StringName, StringName] = {}
var character_name: String = ""
var committed: bool = false

func select_answer(question_id: StringName, answer_id: StringName) -> bool:
	if committed or question_id == &"" or answer_id == &"":
		return false
	answers[question_id] = answer_id
	return true

func get_answer(question_id: StringName) -> StringName:
	return answers.get(question_id, &"")

func set_character_name(value: String) -> bool:
	if committed:
		return false
	character_name = value.strip_edges()
	return true

func clear_answer(question_id: StringName) -> void:
	if not committed:
		answers.erase(question_id)

func snapshot() -> Dictionary:
	return {
		"answers": answers.duplicate(true),
		"character_name": character_name,
		"committed": committed,
	}
