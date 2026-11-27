class_name AssignmentNarrator
extends RefCounted

## Converts simulation-facing assignment records into diegetic docket language.
## This layer is presentation-only: it never mutates world state or mechanics.

const MATTER_TEMPLATES := {
	&"nippur_shrine_establishment": {
		"title": "THE NIPPUR SHRINE SHORTAGE",
		"summary": "The provincial priest writes that the bins are thin and the local grain-levy is overdue."
	},
	&"regional_grain_shortage": {
		"title": "THE NIPPUR SHRINE SHORTAGE",
		"summary": "The provincial priest writes that the bins are thin and the local grain-levy is overdue."
	},
	&"great_canal_cut": {
		"title": "THE UPPER EMBANKMENT STALLED",
		"summary": "The ditch-diggers at the northern cut have thrown down their baskets. They want beer or they want home."
	},
	&"canal_progress_review": {
		"title": "THE UPPER EMBANKMENT STALLED",
		"summary": "The ditch-diggers at the northern cut have thrown down their baskets. They want beer or they want home."
	},
	&"offering_audit": {
		"title": "THE MISSING LAPIS BEADS",
		"summary": "The shrine treasurer claims a sealed offering chest from Susa arrived light by three carved stones."
	},
	&"nippur_shrine_offerings": {
		"title": "THE MISSING LAPIS BEADS",
		"summary": "The shrine treasurer claims a sealed offering chest from Susa arrived light by three carved stones."
	}
}

const RAW_METRIC_LABELS := [
	"pressure_index", "progress_review", "resource_pressure", "completion_ratio",
	"work_progress", "progress", "pressure", "metric", "score"
]

static func translate_opportunity(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var template := _template_for(result)
	if not template.is_empty():
		result["title"] = String(template.get("title", result.get("title", "A Matter for the Archive")))
		result["summary"] = String(template.get("summary", result.get("summary", "A matter requires the scribe's attention.")))
	else:
		result["title"] = _clean_display(String(result.get("title", "A Matter for the Archive")), "A Matter for the Archive")
		result["summary"] = _clean_display(String(result.get("summary", "A matter requires the scribe's attention.")), "A matter requires the scribe's attention.")
	return result

static func translate_payload(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var template := _template_for(result)
	if not template.is_empty():
		result["title"] = String(template.get("title", result.get("title", "A Matter for the Archive")))
		var left: Dictionary = result.get("left_card", {})
		if left.has("quote") and _contains_raw_metric(String(left.get("quote", ""))):
			left["quote"] = String(template.get("summary", "A matter requires the scribe's attention."))
		result["left_card"] = left
		if _contains_raw_metric(String(result.get("prompt", ""))):
			result["prompt"] = "What shall be entered upon the tablet?"
		return result
	result["title"] = _clean_display(String(result.get("title", "A Matter for the Archive")), "A Matter for the Archive")
	for card_key in ["left_card", "right_card"]:
		var card: Dictionary = result.get(card_key, {})
		for field in ["title", "quote", "facts"]:
			if card.has(field):
				card[field] = _clean_display(String(card[field]), "The record is incomplete; seek the source tablet.")
		result[card_key] = card
	result["prompt"] = _clean_display(String(result.get("prompt", "What mark will you leave?")), "What mark will you leave?")
	return result

static func translate_record(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var template := _template_for(result)
	if not template.is_empty():
		result["title"] = String(template.get("title", result.get("title", "A Matter for the Archive")))
		result["summary"] = String(template.get("summary", result.get("summary", "A matter requires the scribe's attention.")))
	else:
		result["title"] = _clean_display(String(result.get("title", "A Matter for the Archive")), "A Matter for the Archive")
		result["summary"] = _clean_display(String(result.get("summary", "A matter requires the scribe's attention.")), "A matter requires the scribe's attention.")
	var evidence: Dictionary = result.get("evidence", {})
	for action_id in evidence:
		var entry: Dictionary = evidence[action_id]
		entry["summary"] = _clean_display(String(entry.get("summary", "Finding recorded.")), "A finding is entered.")
		entry["facts"] = _clean_display(String(entry.get("facts", "")), "The figures remain on the source tablet.")
		evidence[action_id] = entry
	result["evidence"] = evidence
	return result

static func _template_for(record: Dictionary) -> Dictionary:
	for key in ["template_id", "source_id", "matter_id", "id"]:
		var value := StringName(record.get(key, ""))
		if MATTER_TEMPLATES.has(value):
			return MATTER_TEMPLATES[value]
	var identifying_text := "%s %s %s %s" % [String(record.get("title", "")), String(record.get("summary", "")), String(record.get("matter_type", "")), String(record.get("kind", ""))]
	identifying_text = identifying_text.to_lower()
	if identifying_text.contains("nippur") and (identifying_text.contains("shrine") or identifying_text.contains("grain")):
		return MATTER_TEMPLATES[&"nippur_shrine_establishment"]
	if identifying_text.contains("canal") or identifying_text.contains("embankment") or identifying_text.contains("progress_review"):
		return MATTER_TEMPLATES[&"great_canal_cut"]
	if identifying_text.contains("offering") or identifying_text.contains("lapis") or identifying_text.contains("susa"):
		return MATTER_TEMPLATES[&"offering_audit"]
	return {}

static func _contains_raw_metric(value: String) -> bool:
	var lowered := value.to_lower()
	for raw_label in RAW_METRIC_LABELS:
		if lowered.contains(raw_label):
			return true
	return false

static func _clean_display(value: String, fallback: String) -> String:
	if _contains_raw_metric(value):
		return fallback
	return value
