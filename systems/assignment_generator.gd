class_name AssignmentGenerator
extends RefCounted

const GOODS: Array[StringName] = [&"barley", &"dates", &"fish", &"beer", &"wool", &"textiles", &"timber", &"copper"]
const DAMAGED_GOODS: Array[StringName] = [&"beer", &"wool", &"textiles"]
const ARCHETYPES: Array[StringName] = [&"delivery_mismatch", &"damaged_consignment", &"subtotal_claim", &"goods_unreturned", &"hazard_check"]


static var _path_docket_data_cache: Dictionary = {}

static func _get_path_docket_data() -> Dictionary:
	if not _path_docket_data_cache.is_empty():
		return _path_docket_data_cache
	var file := FileAccess.open("res://data/assignments/path_dockets.json", FileAccess.READ)
	if file == null:
		push_error("AssignmentGenerator: path docket content could not be opened.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_path_docket_data_cache = parsed
	else:
		push_error("AssignmentGenerator: path docket content is invalid JSON.")
	return _path_docket_data_cache


static func get_geographic_vector(docket_id: StringName) -> Dictionary:
	var content: Dictionary = _get_path_docket_data()
	var vectors: Dictionary = content.get("geographic_vectors", {})
	var key := String(docket_id)
	if vectors.has(key):
		return (vectors[key] as Dictionary).duplicate(true)
	var commodities: Dictionary = content.get("docket_commodities", {})
	return {"origin_id": "uruk", "destination_id": "uruk", "route_id": "uruk_internal", "commodity_id": StringName(commodities.get(key, "administrative_record")), "route_mode": "within Uruk"}

static func generate(world: WorldState, actor: PersonEntity, selected_path: StringName = &"", record_history: bool = true) -> Dictionary:
	if world == null or actor == null:
		return {}
	var path_id := selected_path
	if path_id == &"":
		for candidate in [&"path_civil", &"path_religious", &"path_martial", &"path_merchant"]:
			if actor.flags.has(candidate):
				path_id = candidate
				break
	if (_get_path_docket_data().get("dockets", {}) as Dictionary).has(String(path_id)):
		return _generate_path_docket(world, actor, path_id, record_history)
	var archetypes: Array[StringName] = []
	for item in ARCHETYPES:
		if not world.recent_archetypes.has(item):
			archetypes.append(item)
	if archetypes.is_empty():
		var previous_archetype := StringName(world.recent_archetypes.back()) if not world.recent_archetypes.is_empty() else &""
		for item in ARCHETYPES:
			if item != previous_archetype:
				archetypes.append(item)
		if archetypes.is_empty():
			archetypes = ARCHETYPES.duplicate()
	var archetype: StringName = archetypes[world.rng_narrative.randi_range(0, archetypes.size() - 1)]
	if archetype == &"hazard_check":
		var active_hazard := false
		for hazard_record in world.hazards:
			if bool(hazard_record.get("active", false)):
				active_hazard = true
				break
		var shortage_pressure := world.get_resource(&"barley") < 100 or world.get_resource(&"labor") < 8
		if not active_hazard and not shortage_pressure:
			var fallback_archetypes: Array[StringName] = []
			for fallback_id in archetypes:
				if fallback_id != &"hazard_check" and (world.recent_archetypes.is_empty() or fallback_id != StringName(world.recent_archetypes.back())):
					fallback_archetypes.append(fallback_id)
			if not fallback_archetypes.is_empty():
				archetype = fallback_archetypes[world.rng_narrative.randi_range(0, fallback_archetypes.size() - 1)]
	if record_history:
		world.recent_archetypes.append(archetype)
		while world.recent_archetypes.size() > 6:
			world.recent_archetypes.pop_front()
	var people: Array[PersonEntity] = []
	for person in world.people.values():
		if person == null or person.id == actor.id:
			continue
		if world.current_location_id != &"" and person.location_id != world.current_location_id:
			continue
		var office := String(person.office_id).to_lower()
		if person.office_id != &"" or office.contains("carrier") or office.contains("steward") or office.contains("trader") or office.contains("brewer") or office.contains("builder") or office.contains("grain_clerk") or office.contains("storehouse") or office.contains("clerk"):
			people.append(person)
	if people.size() < 2:
		return {}
	var left: PersonEntity = people[world.rng_narrative.randi_range(0, people.size() - 1)]
	var right: PersonEntity = left
	for attempt in range(12):
		right = people[world.rng_narrative.randi_range(0, people.size() - 1)]
		if right.id != left.id and not world.recent_npc_pairs.has("%s|%s" % [left.id, right.id]) and not world.recent_npc_pairs.has("%s|%s" % [right.id, left.id]):
			break
	var chosen_alternate: PersonEntity = null
	if right.id == left.id or world.recent_npc_pairs.has("%s|%s" % [left.id, right.id]) or world.recent_npc_pairs.has("%s|%s" % [right.id, left.id]):
		for candidate in people:
			if candidate.id == left.id:
				continue
			var candidate_pair := "%s|%s" % [left.id, candidate.id]
			var reverse_pair := "%s|%s" % [candidate.id, left.id]
			if not world.recent_npc_pairs.has(candidate_pair) and not world.recent_npc_pairs.has(reverse_pair):
				chosen_alternate = candidate
				break
		if chosen_alternate == null:
			var previous_pair := String(world.recent_npc_pairs.back()) if not world.recent_npc_pairs.is_empty() else ""
			for candidate in people:
				if candidate.id == left.id:
					continue
				var candidate_pair := "%s|%s" % [left.id, candidate.id]
				var reverse_pair := "%s|%s" % [candidate.id, left.id]
				if candidate_pair != previous_pair and reverse_pair != previous_pair:
					chosen_alternate = candidate
					break
	if chosen_alternate != null:
		right = chosen_alternate
	if right.id == left.id:
		for candidate in people:
			if candidate.id != left.id:
				right = candidate
				break
	var pair := "%s|%s" % [left.id, right.id]
	if record_history:
		world.recent_npc_pairs.append(pair)
		while world.recent_npc_pairs.size() > 6:
			world.recent_npc_pairs.pop_front()
	var place_id: StringName = world.current_location_id if world.current_location_id != &"" else &"uruk"
	var place_name := String(world.places.get(place_id, {}).get("name", String(place_id).replace("_", " ")))
	var good: StringName = GOODS[world.rng_narrative.randi_range(0, GOODS.size() - 1)]
	var good_name := String(good).replace("_", " ")
	var amount := maxi(1, world.get_resource(good))
	var dispatched := world.rng_narrative.randi_range(16, 36)
	var received := dispatched - world.rng_narrative.randi_range(1, 4)
	var line_a := world.rng_narrative.randi_range(4, 12)
	var line_b := world.rng_narrative.randi_range(4, 12)
	var line_c := world.rng_narrative.randi_range(4, 12)
	var discrepancy := world.rng_narrative.randi_range(1, 2)
	var sent := world.rng_narrative.randi_range(5, 18)
	var returned := world.rng_narrative.randi_range(1, maxi(2, sent - 1))
	var payload := {
		"title": "", "archetype": archetype, "npc_pair": pair, "place_id": place_id,
		"resource_id": good, "amount": amount, "hazard_id": &"",
		"left_card": {"title": "STOREHOUSE RECORD", "speaker_id": left.id, "quote": "", "facts": ""},
		"right_card": {"title": "CLAIM / WITNESS", "speaker_id": right.id, "quote": "", "facts": ""},
		"prompt": "What mark will you leave?", "choices": []
	}
	match archetype:
		&"delivery_mismatch":
			payload.title = "DELIVERY TALLY MISMATCH"
			payload.left_card.quote = "%s dispatched %d measures of %s from %s." % [left.display_name, dispatched, good_name, place_name]
			payload.left_card.facts = "DISPATCHED: %d\nLOADING WITNESS: %s" % [dispatched, "PRESENT" if world.rng_narrative.randf() < 0.5 else "NONE RECORDED"]
			payload.right_card.quote = "%s received %d. The missing measure is disputed." % [right.display_name, received]
			payload.right_card.facts = "RECEIVED: %d\nUNASSIGNED DIFFERENCE: %d" % [received, dispatched - received]
			payload.choices = [_choice("Record discrepancy", "The unassigned difference is entered.", good, -1, 1, 1, "arithmetic", 12, "", 1), _choice("Force acceptance on paper", "The docket balances; the missing goods do not.", good, 2, -2, 2, "law", 8, "complicit", 2), _choice("Dock the carrier", "The carrier bears the shortage pending review.", good, 1, 2, -2, "stewardship", 10, "severe", 1)]
		&"damaged_consignment":
			good = DAMAGED_GOODS[world.rng_narrative.randi_range(0, DAMAGED_GOODS.size() - 1)]
			good_name = String(good).replace("_", " ")
			amount = maxi(1, world.get_resource(good))
			payload.resource_id = good
			payload.amount = amount
			var damaged := maxi(1, int(round(float(amount) * 0.2)))
			payload.title = "DAMAGED CONSIGNMENT"
			payload.left_card.quote = "%s reports %s stored at %s." % [left.display_name, good_name, place_name]
			payload.left_card.facts = "STOCK ON HAND: %d\nAFFECTED SHARE: %d" % [amount, damaged]
			payload.right_card.quote = "%s found cracked seals or damp stains on the outer bundles." % right.display_name
			payload.right_card.facts = "CAUSE NOT CERTIFIED\nINSPECTION REQUIRED"
			payload.choices = [_choice("Quarantine damaged share", "The affected share is held.", good, -damaged, 1, 1, "stewardship", 12, "", 1), _choice("Release all goods", "The full load is released despite the damage.", good, -damaged, 2, -1, "law", 6, "pliable", 2), _choice("Turn away at gate", "The shipment returns without entry.", good, 0, -2, 2, "law", 10, "severe", 1)]
		&"subtotal_claim":
			payload.title = "ACCOUNT SUBTOTAL / CROSS-HOUSE CLAIM"
			payload.left_card.quote = "%s submits three lines for %s." % [left.display_name, place_name]
			payload.left_card.facts = "LINE I: %d\nLINE II: %d\nLINE III: %d\nWRITTEN TOTAL: %d" % [line_a, line_b, line_c, line_a + line_b + line_c + discrepancy]
			payload.right_card.quote = "%s claims the extra %d belongs to another household roll." % [right.display_name, discrepancy]
			payload.right_card.facts = "CALCULATED TOTAL: %d\nCLAIM NOT ON THIS ROLL" % [line_a + line_b + line_c]
			payload.choices = [_choice("Correct math; hold the line", "The sum is corrected and the claim held.", good, 0, -1, 2, "arithmetic", 14, "", 1), _choice("Quietly transfer the difference", "The claim is paid without proper entry.", good, -discrepancy, 2, 1, "stewardship", 7, "complicit", 2), _choice("Impound for adjudication", "Both rolls are held for a senior ruling.", good, 0, -1, -1, "law", 12, "severe", 1)]
		&"goods_unreturned":
			payload.title = "GOODS OUT, UNRETURNED"
			payload.left_card.quote = "%s took %d measures of %s from %s." % [left.display_name, sent, good_name, place_name]
			payload.left_card.facts = "DISPATCHED: %d %s\nRETURNED: %d %s" % [sent, good_name, returned, String(GOODS[(GOODS.find(good) + 1) % GOODS.size()]).replace("_", " ")]
			payload.right_card.quote = "%s recalls a spoken promise to settle after the next landing." % right.display_name
			payload.right_card.facts = "WRITTEN PROMISE: NONE\nSPOKEN CLAIM: DISPUTED"
			payload.choices = [_choice("Separate writing from claim", "The written balance stays open; testimony is attached.", good, 0, 1, 1, "law", 12, "", 1), _choice("Credit the carrier anyway", "The spoken promise is accepted as settlement.", good, returned - sent, 2, -2, "stewardship", 7, "pliable", 2), _choice("Freeze next dispatch", "No goods leave until the balance is answered.", good, 0, -1, -2, "arithmetic", 10, "severe", 1)]
		&"hazard_check":
			var hazard: Dictionary = {}
			for candidate in world.hazards:
				if bool(candidate.get("active", false)):
					hazard = candidate
					break
			if hazard.is_empty():
				payload.title = "HAZARD / MAINTENANCE CHECK"
				payload.left_card.quote = "%s requests preventive maintenance at %s." % [left.display_name, place_name]
				payload.left_card.facts = "LABOR: %d\nSILVER: %d" % [world.get_resource(&"labor"), world.get_resource(&"silver")]
				payload.right_card.quote = "%s says a crew can be assigned if the storehouse authorizes it." % right.display_name
				payload.right_card.facts = "NO ACTIVE HAZARD\nPREVENTIVE WORK"
				payload.choices = [_choice("Assign labor", "Labor is committed to maintenance.", &"labor", -2, 1, 1, "stewardship", 12, "", 2), _choice("Issue silver", "Silver is issued for repair materials.", &"silver", -2, 1, 1, "law", 10, "", 1), _choice("Record and defer", "Maintenance is recorded without allocation.", good, 0, -1, -1, "arithmetic", 5, "", 0)]
			else:
				var hz_place := StringName(hazard.get("place_id", ""))
				var hz_id := StringName(hazard.get("id", ""))
				payload.place_id = hz_place
				payload.hazard_id = hz_id
				payload.title = "HAZARD / MAINTENANCE CHECK"
				payload.left_card.quote = "%s reports active %s at %s." % [left.display_name, String(hz_id).replace("_", " "), String(world.places.get(hz_place, {}).get("name", hz_place))]
				payload.left_card.facts = "ONGOING LOSS: %d %s / PERIOD" % [int(hazard.get("rate", 0)), String(hazard.get("resource", "stock"))]
				payload.right_card.quote = "%s can provide a crew if labor or silver is assigned." % right.display_name
				payload.right_card.facts = "LABOR: %d\nSILVER: %d" % [world.get_resource(&"labor"), world.get_resource(&"silver")]
				var repair_resource: StringName = &"labor" if world.get_resource(&"labor") >= 3 else &"silver"
				var repair_cost := 3
				payload.choices = [_choice("Allocate %s and repair" % repair_resource, "The hazard is repaired and its ongoing loss stops.", repair_resource, -repair_cost, 2, 2, "stewardship", 15, "", 2, true), _choice("Record loss; defer repair", "The hazard remains active; loss continues.", good, 0, -1, -1, "arithmetic", 5, "", 1)]
	return payload

static func _generate_path_docket(world: WorldState, _actor: PersonEntity, path_id: StringName, record_history: bool = true) -> Dictionary:
	var path_data: Dictionary = _get_path_docket_data()
	var templates: Array = (path_data.get("dockets", {}) as Dictionary).get(String(path_id), [])
	if templates.is_empty():
		return {}
	var eligible: Array = []
	for template in templates:
		var candidate_archetype_id := StringName("path_%s" % template.get("id", "docket"))
		if not world.recent_archetypes.has(candidate_archetype_id):
			eligible.append(template)
	if eligible.is_empty():
		var previous_archetype := StringName(world.recent_archetypes.back()) if not world.recent_archetypes.is_empty() else &""
		for template in templates:
			var candidate_archetype_id := StringName("path_%s" % template.get("id", "docket"))
			if candidate_archetype_id != previous_archetype:
				eligible.append(template)
		if eligible.is_empty():
			eligible = templates
	var template: Dictionary = eligible[world.rng_narrative.randi_range(0, eligible.size() - 1)]
	var client_faction := StringName(template.get("client", ""))
	var opposing_faction := StringName(template.get("opposing", ""))
	var local_mode := world.current_location_id != &"" and world.current_location_id != &"uruk"
	var client_members: Array = []
	var opposing_members: Array = []
	if local_mode:
		for local_person in world.people.values():
			if local_person == null or local_person.id == _actor.id or local_person.location_id != world.current_location_id:
				continue
			client_members.append(local_person.id)
			opposing_members.append(local_person.id)
	else:
		client_members = (path_data.get("faction_members", {}) as Dictionary).get(String(client_faction), [])
		opposing_members = (path_data.get("faction_members", {}) as Dictionary).get(String(opposing_faction), [])
	if client_members.is_empty() or opposing_members.is_empty():
		push_warning("AssignmentGenerator: path docket has unresolved faction members: %s / %s" % [client_faction, opposing_faction])
		return {}
	var available_pairs: Array[Dictionary] = []
	for client_member in client_members:
		var candidate_client := StringName(client_member)
		if world.get_person(candidate_client) == null:
			continue
		for opposing_member in opposing_members:
			var candidate_opposing := StringName(opposing_member)
			if candidate_opposing == candidate_client or world.get_person(candidate_opposing) == null:
				continue
			var candidate_pair := "%s|%s" % [candidate_client, candidate_opposing]
			var reverse_pair := "%s|%s" % [candidate_opposing, candidate_client]
			if not world.recent_npc_pairs.has(candidate_pair) and not world.recent_npc_pairs.has(reverse_pair):
				available_pairs.append({"client": candidate_client, "opposing": candidate_opposing})
	if available_pairs.is_empty():
		for client_member in client_members:
			var candidate_client := StringName(client_member)
			if world.get_person(candidate_client) == null:
				continue
			for opposing_member in opposing_members:
				var candidate_opposing := StringName(opposing_member)
				if candidate_opposing != candidate_client and world.get_person(candidate_opposing) != null:
					available_pairs.append({"client": candidate_client, "opposing": candidate_opposing})
	if available_pairs.is_empty():
		return {}
	var selected_pair: Dictionary = available_pairs[world.rng_narrative.randi_range(0, available_pairs.size() - 1)]
	var client_id := StringName(selected_pair.client)
	var opposing_id := StringName(selected_pair.opposing)
	var pair := "%s|%s" % [client_id, opposing_id]
	var archetype_id := StringName("path_%s" % template.get("id", "docket"))
	if record_history:
		world.recent_npc_pairs.append(pair)
		while world.recent_npc_pairs.size() > 6:
			world.recent_npc_pairs.pop_front()
		world.recent_archetypes.append(archetype_id)
		while world.recent_archetypes.size() > 6:
			world.recent_archetypes.pop_front()
	var client_name := "LOCAL CLAIMANT" if local_mode else String((path_data.get("faction_display_names", {}) as Dictionary).get(String(client_faction), String(client_faction).replace("_", " ").capitalize()))
	var opposing_name := "LOCAL WITNESS" if local_mode else String((path_data.get("faction_display_names", {}) as Dictionary).get(String(opposing_faction), String(opposing_faction).replace("_", " ").capitalize()))
	var title := String(template.get("title", "LOCAL DOCKET"))
	var payload := {
		"title": title, "archetype": archetype_id, "docket_kind": "regional_local" if local_mode else "local_path",
		"path_id": path_id, "npc_pair": pair, "client_faction": client_faction,
		"opposing_faction": opposing_faction, "client_name": "CLIENT / " + client_name,
		"opposing_name": "OPPOSING PARTY / " + opposing_name,
		"left_card": {"title": "CLIENT", "speaker_id": client_id, "quote": String(template.get("left", "")), "facts": String(template.get("left_facts", ""))},
		"right_card": {"title": "OPPOSING PARTY", "speaker_id": opposing_id, "quote": String(template.get("right", "")), "facts": String(template.get("right_facts", ""))},
		"prompt": String(template.get("prompt", "What mark will you leave?")),
		"choices": [
			{"label": "Certify the client's record", "result_title": "CLIENT RECORD CERTIFIED", "result_text": "The client's entry is certified; the opposing claim remains attached.", "effects": {"opinion_left": 3, "opinion_right": -2, "epic_progress": 1, "skill": "law", "xp": 12}},
			{"label": "Hold both claims for corroboration", "result_title": "CLAIMS HELD", "result_text": "Neither claim is erased. A second witness is required before the record can be closed.", "effects": {"opinion_left": -1, "opinion_right": -1, "epic_progress": 0, "skill": "arithmetic", "xp": 10}},
			{"label": "Accept the opposing party's account", "result_title": "OPPOSING ACCOUNT ACCEPTED", "result_text": "The opposing account is entered. The client may appeal the mark.", "effects": {"opinion_left": -2, "opinion_right": 3, "epic_progress": 2, "skill": "rhetoric", "xp": 12}}
		]
	}
	if local_mode:
		for docket_choice in payload.get("choices", []):
			var choice_effects: Dictionary = docket_choice.get("effects", {})
			choice_effects["epic_progress"] = 0
			docket_choice["effects"] = choice_effects
	var geography := get_geographic_vector(StringName(template.get("id", "")))
	if local_mode:
		geography = {
			"origin_id": world.current_location_id,
			"destination_id": world.current_location_id,
			"route_id": StringName("%s_local" % world.current_location_id),
			"commodity_id": (path_data.get("docket_commodities", {}) as Dictionary).get(String(template.get("id", "")), "administrative_record"),
			"route_mode": "local",
			"transit_periods": 0,
		}
		payload["place_id"] = world.current_location_id
	payload.merge(geography, true)
	var origin_name := String((path_data.get("place_labels", {}) as Dictionary).get(String(geography.origin_id), String(geography.origin_id).replace("_", " ").capitalize()))
	var destination_name := String((path_data.get("place_labels", {}) as Dictionary).get(String(geography.destination_id), String(geography.destination_id).replace("_", " ").capitalize()))
	var route_line := "ORIGIN: %s  →  DESTINATION: %s" % [origin_name, destination_name]
	route_line += "\nTRANSIT: %s" % String(geography.route_mode).capitalize()
	if geography.has("transit_periods"):
		route_line += " · %d season%s" % [int(geography.transit_periods), "" if int(geography.transit_periods) == 1 else "s"]
	payload.left_card.facts = route_line + "\n" + String(payload.left_card.facts)
	payload.right_card.facts = route_line + "\n" + String(payload.right_card.facts)
	return payload


static func record_selection(world: WorldState, payload: Dictionary) -> void:
	if world == null or payload.is_empty():
		return
	var archetype_id := StringName(payload.get("archetype", ""))
	var pair := String(payload.get("npc_pair", ""))
	if archetype_id != &"":
		world.recent_archetypes.append(archetype_id)
		while world.recent_archetypes.size() > 6:
			world.recent_archetypes.pop_front()
	if not pair.is_empty():
		world.recent_npc_pairs.append(pair)
		while world.recent_npc_pairs.size() > 6:
			world.recent_npc_pairs.pop_front()

static func create_epic_summons() -> Dictionary:
	return {
		"title": "EMERGENCY REQUISITION / GREAT CANAL CUT",
		"archetype": &"epic_summons", "docket_kind": "epic_summons",
		"npc_pair": "ur_nanna|enlil_kisu",
		"client_faction": &"eanna_household", "opposing_faction": &"boatmens_guild",
		"client_name": "High Stewards of Eanna", "opposing_name": "Landing Boatmen & Guilds",
		"left_card": {"title": "CLIENT / HIGH STEWARDS", "speaker_id": &"ur_nanna", "quote": "The canal cut has bogged down in the silt basin. The ditch crews are refusing to dig without fresh rations.", "facts": "WORK HALTED\nEMERGENCY ALLOCATION REQUESTED"},
		"right_card": {"title": "OPPOSING PARTY / BOATMEN", "speaker_id": &"enlil_kisu", "quote": "The boatmen will not deliver stone until the ration promise is entered and the timber tally is answered.", "facts": "STONE DELIVERIES WITHHELD\nTIMBER BALANCE DISPUTED"},
		"prompt": "Your seal has a reputation at the landing. Settle this.",
		"choices": [
			{"label": "Release emergency barley / bind the ration promise", "result_title": "RATION REQUISITION SEALED", "result_text": "Fresh rations reach the ditch crews. The boatmen resume stone deliveries under a witnessed promise.", "effects": {"resource": &"barley", "resource_amount": -20, "resource_scope": "institution", "resource_institution": &"eanna_household", "epic_progress": 22, "opinion_left": 3, "opinion_right": 4, "skill": "stewardship", "xp": 20}},
			{"label": "Audit missing timber before authorizing delivery", "result_title": "TIMBER AUDIT ORDERED", "result_text": "The missing timber is entered as a disputed balance. Stone may move under a provisional tally.", "effects": {"resource": &"", "resource_amount": 0, "epic_progress": 16, "opinion_left": 2, "opinion_right": 2, "skill": "arithmetic", "xp": 18}},
			{"label": "Guarantee the crews' terms and break the strike", "result_title": "CREW TERMS WITNESSED", "result_text": "The crews return to the cut. The guarantee is costly in reputation, but work resumes.", "effects": {"resource": &"", "resource_amount": 0, "epic_progress": 19, "opinion_left": -2, "opinion_right": 5, "skill": "rhetoric", "xp": 20, "trait": "diplomatic"}}
		]
	}



static func make_opinion_consequence(person: PersonEntity, delta: int, reason: String) -> Dictionary:
	if person == null:
		return {}
	var title := String(person.office_id).replace("_", " ").capitalize() if person.office_id != &"" else "Official"
	return {"type": "opinion", "target_name": person.display_name, "target_title": title, "delta": delta, "reason": reason}

static func _choice(label: String, result: String, resource: StringName, amount: int, left_opinion: int, right_opinion: int, skill: String, xp: int, trait_name: String, epic_progress: int = 0, repair: bool = false) -> Dictionary:
	return {"label": label, "result_title": "MARK MADE", "result_text": result, "effects": {"resource": resource, "resource_amount": amount, "opinion_left": left_opinion, "opinion_right": right_opinion, "skill": skill, "xp": xp, "trait": trait_name, "epic_progress": epic_progress, "repair_hazard": repair}}
