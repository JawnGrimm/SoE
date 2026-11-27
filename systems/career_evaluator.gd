class_name CareerEvaluator
extends RefCounted
## Pure end-of-career scoring. Reads the authoritative world and actor; never mutates either.

const FACTION_LABELS := {
	&"eanna_temple": "Eanna Temple",
	&"council_of_elders": "City Elders",
	&"boatmens_guild": "Boatmen",
	&"provincial_frontier": "Provincial Frontier",
	&"umma": "Umma",
	&"nippur": "Nippur"
}

static func is_terminal_failure(actor: PersonEntity) -> bool:
	return actor != null and (bool(actor.flags.get(&"dead", false)) or bool(actor.flags.get(&"bankrupt", false)))

static func evaluate(world: WorldState, actor: PersonEntity) -> Dictionary:
	if world == null or actor == null:
		return {}
	var silver := int(actor.resources.get(&"silver", 0))
	var debt := maxi(0, maxi(int(actor.resources.get(&"debt", 0)), int(actor.flags.get(&"audit_debt", actor.flags.get(&"debt", 0)))))
	var unpaid_upkeep := maxi(0, int(actor.flags.get(&"unpaid_upkeep", 0)))
	var corruption_flags := [&"phantom_barley_measure", &"entangled_brewery_accounts", &"complicit", &"bribe_accepted", &"concealed_accounts"]
	var audit_exposure := maxi(int(world.world_flags.get(&"audit_exposure", 0)), int(actor.flags.get(&"audit_exposure", 0)))
	var corruption := audit_exposure * 8
	if &"pliable" in actor.traits:
		corruption += 15
	for flag in corruption_flags:
		if world.world_flags.has(flag) and int(world.world_flags[flag]) != 0:
			corruption += 18
	if actor.traits.has(&"complicit"):
		corruption += 20
	if actor.flags.has(&"bribe_accepted") or actor.flags.has(&"concealed_accounts"):
		corruption += 18
	var corrections := maxi(int(world.world_flags.get(&"honest_corrections", 0)), _count_log_title(world, "FORMAL AUDIT CORRECTION"))
	var exposure_clears := int(world.world_flags.get(&"exposure_clears", 0)) + _count_log_phrase(world, "audit exposure is cleared")
	var mentor := world.get_person(&"shuruppak_ilu")
	var mentor_trust := int(actor.relationships.get(&"shuruppak_ilu", {}).get("trust", 0))
	if mentor != null:
		mentor_trust = maxi(mentor_trust, int(mentor.relationships.get(actor.id, {}).get("trust", 0)))
	var archivist_trust := maxi(mentor_trust, int(world.world_flags.get(&"archivist_trust", 0)))
	var integrity := clampi(corrections * 12 + exposure_clears * 15 + archivist_trust * 4 + actor.skills.get_level(&"law") * 5 - corruption, 0, 100)
	corruption = clampi(corruption, 0, 100)
	var faction_scores: Dictionary = world.faction_standings.duplicate(true)
	var temple_opinions := 0
	var temple_count := 0
	for temple_person_id in [&"ur_nanna", &"shuruppak_ilu"]:
		var temple_person := world.get_person(temple_person_id)
		if temple_person != null:
			temple_opinions += temple_person.get_opinion(actor.id)
			temple_count += 1
	if temple_count > 0:
		faction_scores[&"eanna_temple"] = maxi(int(faction_scores.get(&"eanna_temple", 0)), int(round(float(temple_opinions) / temple_count)))
	var provincial_opinion := 0
	for provincial_person_id in [&"ur_mes", &"character_0012"]:
		var provincial_person := world.get_person(provincial_person_id)
		if provincial_person != null:
			provincial_opinion = maxi(provincial_opinion, provincial_person.get_opinion(actor.id))
	faction_scores[&"provincial_frontier"] = maxi(int(faction_scores.get(&"provincial_frontier", 0)), provincial_opinion)
	for faction_id in [&"eanna_temple", &"council_of_elders", &"boatmens_guild", &"provincial_frontier"]:
		if not faction_scores.has(faction_id):
			faction_scores[faction_id] = 0
	var primary_faction: StringName = &""
	var highest := -2147483648
	for faction_id in faction_scores:
		var score := int(faction_scores[faction_id])
		if score > highest:
			highest = score
			primary_faction = StringName(faction_id)
	var epic: Dictionary = world.epics.get(&"great_canal_cut", {})
	var progress := int(epic.get("progress", world.get_resource(&"canal_progress")))
	var target := int(epic.get("target", 100))
	var labor_outcome := _labor_outcome(world, epic)
	var start_year := int(world.world_flags.get(&"career_start_year", -3200))
	var orientation_label := "Unrecorded"
	for path_id in [&"path_civil", &"path_religious", &"path_martial", &"path_merchant"]:
		if int(world.world_flags.get(&"professional_orientation", -1)) == int(path_id.hash()):
			orientation_label = String(path_id).replace("path_", "").replace("_", " ").capitalize()
	var law_level := actor.skills.get_level(&"law")
	var literacy_level := actor.skills.get_level(&"literacy")
	var epitaph := _epitaph(integrity, corruption, silver - debt - unpaid_upkeep, law_level, labor_outcome, primary_faction, actor)
	return {
		"character_name": actor.display_name,
		"final_office": String(actor.office_id).replace("_", " ").capitalize() if actor.office_id != &"" else "No office held",
		"starting_orientation": orientation_label,
		"years_in_service": maxi(0, world.year - start_year),
		"start_year": start_year,
		"end_year": world.year,
		"period": world.period + 1,
		"total_cases_settled": world.cases_settled,
		"silver_earned": world.silver_earned,
		"silver_held": silver,
		"debt_defaulted": debt,
		"debt_cleared": maxi(int(world.world_flags.get(&"debt_cleared", 0)), _count_log_title(world, "DEBT CLEARED")),
		"unpaid_upkeep": unpaid_upkeep,
		"audit_reprimands_survived": _count_log_title(world, "ARCHIVE REPRIMAND"),
		"net_worth": silver - debt - unpaid_upkeep,
		"corruption_score": corruption,
		"integrity_score": integrity,
		"honest_corrections": corrections,
		"exposure_clears": exposure_clears,
		"audit_exposure": audit_exposure,
		"law": law_level,
		"literacy": literacy_level,
		"arithmetic": actor.skills.get_level(&"arithmetic"),
		"mentor_trust": mentor_trust,
		"archivist_trust": archivist_trust,
		"primary_legacy_faction": String(FACTION_LABELS.get(primary_faction, String(primary_faction).replace("_", " ").capitalize())),
		"character_standings": _character_standings(world, actor),
		"faction_standings": faction_scores,
		"canal_progress": progress,
		"canal_target": target,
		"canal_completed": bool(epic.get("completed", false)) or progress >= target,
		"canal_labor_outcome": labor_outcome,
		"epitaph": epitaph,
		"scandals_buried": _buried_scandals(world)
	}

static func generate_export_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "# Career Record\n\nNo completed career record is available."
	var lines := PackedStringArray([
		"# %s" % String(summary.get("character_name", "Unknown Scribe")),
		"## %s" % String(summary.get("epitaph", "The Diligent Keeper of the Daybook")),
		"",
		"Served from %s to %s (%d years); concluded in period %d." % [CalendarFormatter.format_year(int(summary.get("start_year", -3200))), CalendarFormatter.format_year(int(summary.get("end_year", -3200))), int(summary.get("years_in_service", 0)), int(summary.get("period", 1))],
		"Settled %d cases and earned %d silver; held %d silver at conclusion." % [int(summary.get("total_cases_settled", 0)), int(summary.get("silver_earned", 0)), int(summary.get("silver_held", 0))],
		"Net worth: %d silver; debt cleared %d, defaulted %d, and unpaid upkeep %d." % [int(summary.get("net_worth", 0)), int(summary.get("debt_cleared", 0)), int(summary.get("debt_defaulted", 0)), int(summary.get("unpaid_upkeep", 0))],
		"Integrity: %d / 100. Corruption: %d / 100. Law: %d; Literacy: %d; Arithmetic: %d. Audit reprimands survived: %d." % [int(summary.get("integrity_score", 0)), int(summary.get("corruption_score", 0)), int(summary.get("law", 0)), int(summary.get("literacy", 0)), int(summary.get("arithmetic", 0)), int(summary.get("audit_reprimands_survived", 0))],
		"Great Canal Cut: %d / %d — %s. Lasting standing: %s." % [int(summary.get("canal_progress", 0)), int(summary.get("canal_target", 100)), String(summary.get("canal_labor_outcome", "unrecorded")), String(summary.get("primary_legacy_faction", "No faction recorded"))],
		"",
		"Thus the tablets remember %s: not the loudest hand in Uruk, but the hand whose marks endured." % String(summary.get("character_name", "the scribe"))
	])
	return "\n".join(lines)

static func _epitaph(integrity: int, corruption: int, net_worth: int, law: int, labor_outcome: String, faction: StringName, actor: PersonEntity) -> String:
	if actor.flags.has(&"name_on_monument"):
		return "The Name Cut into the Sluice Stone"
	if integrity >= 65 and law >= 2:
		return "The Incorruptible Scaleman of the Lowlands"
	if corruption >= 55 and net_worth > 5:
		return "The Silver-Handed Operator of Eanna"
	if net_worth < 0 and faction in [&"provincial_frontier", &"umma", &"nippur"]:
		return "The Indentured Scribe of the Umma Reeds"
	if labor_outcome == "full rations" or actor.traits.has(&"protective_of_crew") or actor.traits.has(&"honors_labor"):
		return "The Reed-Friend of the Ditch Crews"
	return "The Diligent Keeper of the Daybook"

static func _labor_outcome(world: WorldState, epic: Dictionary) -> String:
	if world.has_flag(&"canal_forced_drafts", world.current_period_index()):
		return "forced drafts"
	if world.has_flag(&"canal_worker_strike", world.current_period_index()) or world.has_flag(&"canal_crew_slowdown", world.current_period_index()):
		return "worker strikes"
	if int(epic.get("progress", world.get_resource(&"canal_progress"))) >= int(epic.get("target", 100)):
		return "full rations"
	return "unfinished works"

static func _character_standings(world: WorldState, actor: PersonEntity) -> Dictionary:
	var result := {}
	for person_id in [&"ur_nanna", &"shuruppak_ilu", &"ur_mes", &"character_0012"]:
		var person := world.get_person(person_id)
		if person != null:
			result[person.display_name] = person.get_opinion(actor.id)
	var boatmen := int(world.faction_standings.get(&"boatmens_guild", 0))
	result["Boatmen"] = boatmen
	return result

static func _count_log_title(world: WorldState, title: String) -> int:
	var count := 0
	for entry in world.cedar_desk_log:
		if String(entry.get("title", "")).to_upper() == title:
			count += 1
	return count

static func _count_log_phrase(world: WorldState, phrase: String) -> int:
	var count := 0
	for entry in world.cedar_desk_log:
		if String(entry.get("summary", "")).to_lower().contains(phrase.to_lower()):
			count += 1
	return count

static func _buried_scandals(world: WorldState) -> int:
	var count := 0
	for flag in [&"phantom_barley_measure", &"entangled_brewery_accounts", &"complicit", &"grain_scandal"]:
		if world.world_flags.has(flag):
			count += 1
	return count
