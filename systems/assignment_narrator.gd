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
	"work_progress", "progress", "pressure", "metric", "score",
	"capability applied", "form:", "pension_roll", "grain_levy",
	"travel_pass", "succession_claim", "form: pension_roll", "form: grain_levy",
	"form: travel_pass", "form: succession_claim"
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
		for card_key in ["left_card", "right_card"]:
			var card: Dictionary = result.get(card_key, {})
			for field in ["title", "quote", "facts"]:
				if card.has(field):
					card[field] = _clean_display(String(card[field]), "The record is incomplete; seek the source tablet.")
			result[card_key] = card
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

static func narrate_record_examination(record: Dictionary, actor: PersonEntity, world: WorldState, evidence: Dictionary) -> Dictionary:
	## A first-person tablet scene for the first investigative action.
	## This is presentation only; evidence and effects are resolved by AssignmentPipeline.
	var source: Dictionary = record.get("source_data", {})
	var official := world.get_person(StringName(record.get("employer_id", ""))) if world != null else null
	var official_name := official.display_name if official != null else "the responsible clerk"
	var npc_evidence: Dictionary = source.get("npc_evidence", {})
	var beats: Array[Dictionary] = []
	beats.append({"kind": "description", "speaker": "", "text": "You draw the tablet closer. The clay is cool where the seal has kept it from the sun."})
	if not npc_evidence.is_empty():
		var dispatch := String(npc_evidence.get("dispatch_record", "The dispatch tablet gives no account of the load."))
		var tally := String(npc_evidence.get("threshold_tally", "The threshold tally is absent."))
		beats.append({"kind": "document", "speaker": "The written record", "text": dispatch})
		beats.append({"kind": "document", "speaker": "The threshold tally", "text": tally})
		beats.append({"kind": "observation", "speaker": "", "text": "The two accounts cannot both be true. Someone has made the contradiction durable by pressing it into clay."})
	elif StringName(record.get("kind", "")) == &"form":
		var form_type := String(source.get("form_type", ""))
		var titles := {"pension_roll": "Pension Ledger", "grain_levy": "Grain Levy", "travel_pass": "Travel Pass", "succession_claim": "Succession Claim"}
		var subject := String(source.get("subject_id", "the named place"))
		beats.append({"kind": "document", "speaker": "The pending register", "text": "The %s concerns %s. Its urgency is marked %d." % [String(titles.get(form_type, "official record")), subject.replace("_", " "), int(source.get("urgency", 1))]})
		beats.append({"kind": "observation", "speaker": "", "text": "The register tells you why the matter arrived. It does not tell you who is telling the truth."})
	else:
		beats.append({"kind": "document", "speaker": "The written record", "text": String(evidence.get("facts", "The source tablet carries the matter forward, but leaves its origin uncertain."))})
		beats.append({"kind": "observation", "speaker": "", "text": "The figures are orderly. That is not the same thing as their being honest."})
	if official != null:
		beats.append({"kind": "dialogue", "speaker": official_name, "text": "The entry is in order. I have nothing further to add to what is written."})
		beats.append({"kind": "observation", "speaker": "", "text": "He calls it an entry, not an account. You notice the distinction because he seems determined not to."})
	else:
		beats.append({"kind": "observation", "speaker": "", "text": "No name stands beside the entry. The hand that made it has left no witness but the clay."})
	var thought := "A record can survive its maker. It can also survive the lie that its maker needed."
	if actor != null and actor.skills != null and actor.skills.get_level(&"literacy") >= 2:
		thought = "The hand is practiced; the wording is not. Whoever made this entry knew how to write around a question."
	beats.append({"kind": "internal_monologue", "speaker": actor.display_name if actor != null else "The scribe", "text": thought})
	return {
		"heading": "A closer reading",
		"beats": beats,
		"closing": "The tablet has yielded a contradiction, not a verdict. The next voice may explain it—or make it worse."
	}

static func _canal_review_template(record: Dictionary) -> Dictionary:
	var epic: Dictionary = record.get("source_data", {})
	var stage := String(epic.get("stage", ""))
	var progress := int(epic.get("progress", 0))
	var target := maxi(1, int(epic.get("target", 100)))
	if stage.is_empty():
		stage = "approaching_completion" if progress >= target * 0.75 else ("cutting" if progress >= target * 0.25 else "survey")
	var last_reviewed_progress := int(epic.get("last_reviewed_progress", progress))
	var stalled := bool(epic.get("stalled", false)) or not String(epic.get("active_problem", "")).is_empty() or progress < last_reviewed_progress
	if stalled:
		return MATTER_TEMPLATES[&"great_canal_cut"]
	match stage:
		"survey":
			return {"title": "THE CANAL SURVEY", "summary": "The survey stakes are set along the low ground. The first tally concerns distance, labor, and whose fields will lose a boundary."}
		"cutting":
			return {"title": "THE CANAL CUT", "summary": "The channel has reached the working cut. Earth moves by basket and shoulder; the clerk's figures move by seal."}
		"approaching_completion":
			return {"title": "THE LAST REACH", "summary": "The canal nears its intended line. The remaining work is less earth than obligation: gates, stores, and the names owed a share."}
		"completed":
			return {"title": "THE CANAL ENTERED IN THE RECORD", "summary": "The watercourse has reached its recorded measure. The final account must say what was built—and what the fields surrendered."}
		_:
			return {"title": "THE CANAL WORKS", "summary": "The crews continue along the marked line. Review the stage tally and the obligations attached to it."}

static func _template_for(record: Dictionary) -> Dictionary:
	if StringName(record.get("kind", "")) == &"project_review" and StringName(record.get("source_id", "")) == &"great_canal_cut":
		return _canal_review_template(record)
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
	var lines := PackedStringArray()
	for line in value.split("\n"):
		if line.strip_edges().begins_with("CAPABILITY APPLIED:"):
			continue
		lines.append(line)
	var cleaned := "\n".join(lines)
	var titles := {"FORM: pension_roll": "RECORD TYPE: Pension Ledger", "FORM: grain_levy": "RECORD TYPE: Grain Levy", "FORM: travel_pass": "RECORD TYPE: Travel Pass", "FORM: succession_claim": "RECORD TYPE: Succession Claim"}
	for raw_title in titles:
		cleaned = cleaned.replace(raw_title, titles[raw_title])
	var form_pattern := RegEx.new()
	form_pattern.compile("form_[0-9]+")
	cleaned = form_pattern.sub(cleaned, "the pending record", true)
	return fallback if _contains_raw_metric(cleaned) else cleaned
