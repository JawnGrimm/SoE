class_name ConsequenceVisibility
extends RefCounted
## Presentation-safe consequence summaries. Does not mutate WorldState or save data.

const SKILL_LABELS := {
	"literacy": "Literacy", "arithmetic": "Arithmetic", "law": "Law",
	"rhetoric": "Rhetoric", "intrigue": "Intrigue", "stewardship": "Stewardship"
}

static func format_ledger(message: String, consequences: Array) -> String:
	var lines := PackedStringArray([message, "", "CONSEQUENCES RECORDED"])
	if consequences.is_empty():
		lines.append("No measurable changes were recorded.")
		return "\n".join(lines)
	for entry_value in consequences:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var skill_key := str(entry.get("skill", "skill")).to_lower()
		var skill_label := str(SKILL_LABELS.get(skill_key, skill_key.capitalize()))
		match StringName(entry.get("type", "")):
			&"opinion":
				lines.append("• %s (%s): %+d Opinion — “%s”" % [String(entry.get("target_name", "Unknown official")), String(entry.get("target_title", "Official")), int(entry.get("delta", 0)), String(entry.get("reason", "Assessment recorded."))])
			&"xp":
				lines.append("• %s: +%d XP" % [skill_label, int(entry.get("delta", 0))])
			&"level_up":
				lines.append("★ PROMOTION: %s INCREASED TO LEVEL %d! ★" % [skill_label.to_upper(), int(entry.get("new_level", 1))])
			&"silver":
				lines.append("• Purse: %+d Silver" % int(entry.get("delta", 0)))
			&"debt":
				lines.append("• Debt: %+d shekels entered in archive" % int(entry.get("delta", 0)))
			&"exposure":
				lines.append("• Audit Exposure: %+d" % int(entry.get("delta", 0)))
			&"trait":
				lines.append("• Acquired Trait: %s" % String(entry.get("name", "Unknown")))
			&"flag":
				var flag_label := str(entry.get("name", "A new flag")).replace("_", " ").to_lower()
				if not flag_label.is_empty():
					flag_label = flag_label.left(1).to_upper() + flag_label.substr(1)
				lines.append("• World record: %s" % flag_label)
	return "\n".join(lines)

static func remote_courier_text(epic: Dictionary, progress: int, target: int) -> String:
	var problem := String(epic.get("active_problem", ""))
	var stalled := bool(epic.get("stalled", false))
	var disrupted := bool(epic.get("crew_disruption", false)) or bool(epic.get("crew_disrupted", false)) or bool(epic.get("crew_strike", false)) or not problem.is_empty()
	var review := bool(epic.get("review_pending", false))
	if not stalled and not disrupted and not review:
		return ""
	var status := "STALLED" if stalled else ("CREW DISRUPTION" if disrupted else "REVIEW PENDING")
	var authored_problem := {
		"labor_shortage": "Crews have struck following ration cuts. Silt is washing into the ditch.",
		"barley_shortage": "The ration stores are short. Diggers have left the cut and silt is washing into the ditch.",
		"site_hazard": "The work face is unsafe. Crews have stopped until the site is inspected.",
		"scandal_audit": "The account is under audit; progress is held pending the archive's finding.",
		"audit_hold": "The cut is halted pending an audit. The foreman's roll must be examined."
	}
	var detail := String(epic.get("review_summary", ""))
	if detail.strip_edges().is_empty():
		detail = String(authored_problem.get(problem, "The capital reports a matter requiring your seal."))
	return "[URGENT DISPATCH FROM URUK]\nTHE GREAT CANAL CUT: %s (%d / %d)\n%s\nTravel to Uruk to convene the Stage Review." % [status, progress, target, detail]

static func remote_review_required(epic_place_id: StringName, current_location_id: StringName, review_pending: bool) -> bool:
	return review_pending and epic_place_id == &"uruk" and current_location_id in [&"umma", &"nippur"]
