class_name AssignmentGenerator
extends RefCounted

const GOODS: Array[StringName] = [&"barley", &"dates", &"fish", &"beer", &"wool", &"textiles", &"timber", &"copper"]
const DAMAGED_GOODS: Array[StringName] = [&"beer", &"wool", &"textiles"]
const ARCHETYPES: Array[StringName] = [&"delivery_mismatch", &"damaged_consignment", &"subtotal_claim", &"goods_unreturned", &"hazard_check"]


const PATH_FACTION_MEMBERS := {
	&"eanna_household": [&"shuruppak_ilu", &"ur_nanna", &"utu_mansum", &"enlil_kisu", &"lu_nanshe"],
	&"boatmens_guild": [&"enlil_kisu", &"ur_amas", &"enki_ili", &"geme_inana"],
	&"city_garrison": [&"utu_mansum", &"enlil_kisu", &"ur_amas"],
	&"council_of_elders": [&"shuruppak_ilu", &"lu_nanshe", &"utu_mansum"],
	&"agricultural_households": [&"ama_edin", &"geme_tur", &"ur_gula"]
}
const PATH_FACTION_DISPLAY_NAMES := {
	&"eanna_household": "Eanna Temple",
	&"boatmens_guild": "Landing Boatmen & Guilds",
	&"city_garrison": "City Garrison",
	&"council_of_elders": "Council of Elders",
	&"agricultural_households": "Agricultural Households"
}
const PATH_DOCKET_DATA := {
	&"path_merchant": [
		{"id":"timber_grade_dispute","title":"TIMBER GRADES / REJECTED LOAD","client":"boatmens_guild","opposing":"council_of_elders","left":"The timber was accepted at the landing by grade. The tablet now calls it inferior.","left_facts":"GRADE AT LANDING: ACCEPTED\nREVISED GRADE: DISPUTED","right":"The council's builder says the beams will not hold the cut's retaining frame.","right_facts":"STRUCTURAL USE: RETAINING FRAME\nREJECTION: REQUESTED","prompt":"Does the grade mark stand, or does the load return?"},
		{"id":"boat_demurrage","title":"BOAT DEMURRAGE / DELAYED UNLOADING","client":"boatmens_guild","opposing":"eanna_household","left":"Our boat waited three periods for the unloading crew. The charge is not charity; it is time spent tied to your quay.","left_facts":"WAIT: 3 PERIODS\nDEMURRAGE: UNSETTLED","right":"The household claims the boat arrived outside its assigned landing window.","right_facts":"LANDING WINDOW: DISPUTED\nCREW RECORD: INCOMPLETE","prompt":"Which account will carry the delay?"},
		{"id":"counterfeit_copper","title":"COPPER INGOTS / FALSE WEIGHT","client":"boatmens_guild","opposing":"council_of_elders","left":"These ingots passed the market balance yesterday. Today the council calls them light and counterfeit.","left_facts":"MARK: PRESENT\nWEIGHT: CHALLENGED","right":"The council asks that the entire batch be held until the source is named.","right_facts":"BATCH: 12 INGOTS\nSOURCE: UNVERIFIED","prompt":"Do you certify the mark, impound the batch, or split the risk?"},
		{"id":"missing_quay_sacks","title":"QUAYSIDE GRAIN / MISSING SACKS","client":"eanna_household","opposing":"boatmens_guild","left":"The storehouse tally records forty sacks sent to the quay. Only thirty-six were entered on the boat.","left_facts":"DISPATCHED: 40\nLOADED: 36","right":"The boatmen insist four sacks were moved to a second craft without a witness tablet.","right_facts":"SECOND CRAFT: UNWITNESSED\nSHORTAGE: 4 SACKS","prompt":"Do you charge the landing, amend the tally, or demand a second witness?"}
	],
	&"path_martial": [
		{"id":"ditch_guard_rations","title":"DITCH GUARD / RATION SHORTFALL","client":"city_garrison","opposing":"eanna_household","left":"The ditch guards received half their barley. They will not keep watch on empty stomachs.","left_facts":"RATION ISSUE: HALF\nWATCH: AT RISK","right":"The storehouse says the guard roll contains names not present at the ditch.","right_facts":"ROLL: DISPUTED\nMUSTER: NOT ATTACHED","prompt":"Do you certify the shortage, challenge the roll, or guarantee the watch?"},
		{"id":"spear_requisition","title":"SPEAR REQUISITION / UNMATCHED COUNT","client":"city_garrison","opposing":"council_of_elders","left":"The captain requisitioned twenty spearheads. The workshop delivered fourteen and claims the rest were never authorized.","left_facts":"REQUESTED: 20\nDELIVERED: 14","right":"The council's tablet bears a smaller order, but its seal impression is incomplete.","right_facts":"ORDER: 14 OR 20\nSEAL: INCOMPLETE","prompt":"Which requisition becomes the record?"},
		{"id":"watchtower_supply","title":"WATCHTOWER / SUPPLY GAP","client":"city_garrison","opposing":"boatmens_guild","left":"The tower has no lamp oil or rope. The captain says the supply boat never arrived.","left_facts":"OIL: MISSING\nROPE: MISSING","right":"The boatman has a receipt for delivery at the lower landing, not the tower.","right_facts":"LOWER LANDING: RECEIPT\nTOWER: NO ACKNOWLEDGMENT","prompt":"Do you hold the carrier, reroute the supply, or certify the receipt?"},
		{"id":"conscription_exemption","title":"CONSCRIPTION EXEMPTION / HOUSEHOLD CLAIM","client":"city_garrison","opposing":"council_of_elders","left":"The captain says this household's exemption was never entered on the muster tablet.","left_facts":"EXEMPTION: CLAIMED\nMUSTER: ACTIVE","right":"The council elder says the exemption was witnessed and the tablet misplaced.","right_facts":"WITNESS: NAMED\nENTRY: MISSING","prompt":"Does the missing entry cancel the exemption?"}
	],
	&"path_civil": [
		{"id":"boundary_stones","title":"BOUNDARY STONES / FARMER DISPUTE","client":"council_of_elders","opposing":"agricultural_households","left":"The boundary stone stands where the elder's copy places it. The household says it was moved after the flood.","left_facts":"STONE POSITION: DISPUTED\nOLDER COPY: PRESENT","right":"The household's field marks show a narrower strip than the council's levy map.","right_facts":"FIELD MARKS: PRESENT\nLEVY MAP: WIDER","prompt":"Which boundary does your seal recognize?"},
		{"id":"canal_water_sharing","title":"CANAL WATER / SHARED ALLOCATION","client":"council_of_elders","opposing":"agricultural_households","left":"The upper fields received three turns of water. The lower households say their turn was skipped.","left_facts":"UPPER: 3 TURNS\nLOWER: 0 RECORDED","right":"The canal keeper claims the lower gate was blocked with silt and could not be opened.","right_facts":"GATE: SILTED\nWATER TURN: UNSETTLED","prompt":"Do you assign a lost turn, a debt, or a new schedule?"},
		{"id":"inheritance_tablets","title":"INHERITANCE TABLETS / DOUBLE CLAIM","client":"council_of_elders","opposing":"eanna_household","left":"Two tablets name the same field allotment. One bears the father's seal; the other the household's later mark.","left_facts":"CLAIM A: OLDER SEAL\nCLAIM B: LATER MARK","right":"The household says the later mark records a settlement made before the father's death.","right_facts":"SETTLEMENT: ORAL\nWITNESS: NOT LISTED","prompt":"Which claim receives provisional recognition?"},
		{"id":"market_vendor_fine","title":"MARKET VENDOR / FINE APPEAL","client":"council_of_elders","opposing":"boatmens_guild","left":"The council imposed a fine for occupying the quay path. The vendor says the boatmen blocked the proper stall.","left_facts":"FINE: 2 SHEKELS\nOBSTRUCTION: CLAIMED","right":"The landing guild says the vendor's baskets narrowed the unloading lane.","right_facts":"LANE: OBSTRUCTED\nPRIOR WARNING: DISPUTED","prompt":"Do you uphold the fine, reduce it, or return the matter for witness? "}
	],
	&"path_religious": [
		{"id":"sacrificial_sheep","title":"SACRIFICIAL SHEEP / COUNT VARIANCE","client":"eanna_household","opposing":"agricultural_households","left":"The offering roll lists twelve sheep. The shepherd delivered ten and says two were rejected as unfit.","left_facts":"ROLL: 12\nDELIVERED: 10","right":"The household says no rejection mark was made at the gate.","right_facts":"REJECTION MARK: ABSENT\nDELIVERY WITNESS: DISPUTED","prompt":"Do you certify the rejection, charge the shortage, or require a witness?"},
		{"id":"ritual_beer","title":"RITUAL BEER / ALLOCATION DISPUTE","client":"eanna_household","opposing":"boatmens_guild","left":"The ritual brewer received less beer than the allocation tablet promised.","left_facts":"PROMISED: 8 JARS\nISSUED: 5 JARS","right":"The carrier claims three jars broke during unloading and were entered as loss.","right_facts":"BREAKAGE: CLAIMED\nLOSS TABLET: MISSING","prompt":"Does the loss stand against the carrier or the allocation?"},
		{"id":"storehouse_seal","title":"STOREHOUSE SEAL / INSPECTION","client":"eanna_household","opposing":"council_of_elders","left":"The seal on the offering storehouse is intact, but its clay impression does not match the archive copy.","left_facts":"SEAL: INTACT\nIMPRESSION: VARIANT","right":"The council asks whether the seal was replaced during the last inspection.","right_facts":"LAST INSPECTION: UNDATED\nREPLACEMENT: UNRECORDED","prompt":"Do you accept the seal, order a re-impression, or open an inquiry?"},
		{"id":"festival_tithes","title":"FESTIVAL TITHES / UNRECORDED SHARE","client":"eanna_household","opposing":"council_of_elders","left":"The festival tithe is short by one basket. The temple steward says the share was promised to the musicians.","left_facts":"EXPECTED: 9 BASKETS\nENTERED: 8","right":"The council says a promise is not a recorded exemption.","right_facts":"EXEMPTION: NONE\nPROMISE: ORAL","prompt":"Do you honor the promise, recover the tithe, or amend the next roll?"}
	]
}

static func generate(world: WorldState, actor: PersonEntity, selected_path: StringName = &"") -> Dictionary:
	if world == null or actor == null:
		return {}
	var path_id := selected_path
	if path_id == &"":
		for candidate in [&"path_civil", &"path_religious", &"path_martial", &"path_merchant"]:
			if actor.flags.has(candidate):
				path_id = candidate
				break
	if PATH_DOCKET_DATA.has(path_id):
		return _generate_path_docket(world, actor, path_id)
	var archetypes: Array[StringName] = []
	for item in ARCHETYPES:
		if world.recent_archetypes.is_empty() or StringName(world.recent_archetypes.back()) != item:
			archetypes.append(item)
	var archetype: StringName = archetypes[world.rng_narrative.randi_range(0, archetypes.size() - 1)]
	if archetype == &"hazard_check":
		var active_hazard := false
		for hazard_record in world.hazards:
			if bool(hazard_record.get("active", false)):
				active_hazard = true
				break
		var shortage_pressure := world.get_resource(&"barley") < 100 or world.get_resource(&"labor") < 8
		if not active_hazard and not shortage_pressure:
			archetype = &"delivery_mismatch"
	world.recent_archetypes.append(archetype)
	while world.recent_archetypes.size() > 6:
		world.recent_archetypes.pop_front()
	var people: Array[PersonEntity] = []
	for person in world.people.values():
		if person == null or person.id == actor.id:
			continue
		var office := String(person.office_id).to_lower()
		if office.contains("carrier") or office.contains("steward") or office.contains("trader") or office.contains("brewer") or office.contains("builder") or office.contains("grain_clerk") or office.contains("storehouse") or office.contains("clerk"):
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
	world.recent_npc_pairs.append(pair)
	while world.recent_npc_pairs.size() > 6:
		world.recent_npc_pairs.pop_front()
	var place_id: StringName = &"uruk"
	var place_keys: Array = world.places.keys()
	if not place_keys.is_empty():
		place_id = StringName(place_keys[world.rng_narrative.randi_range(0, place_keys.size() - 1)])
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

static func _generate_path_docket(world: WorldState, actor: PersonEntity, path_id: StringName) -> Dictionary:
	var templates: Array = PATH_DOCKET_DATA.get(path_id, [])
	if templates.is_empty():
		return {}
	var eligible: Array = []
	for template in templates:
		var archetype_id := StringName("path_%s" % template.get("id", "docket"))
		if world.recent_archetypes.is_empty() or StringName(world.recent_archetypes.back()) != archetype_id:
			eligible.append(template)
	if eligible.is_empty():
		eligible = templates
	var template: Dictionary = eligible[world.rng_narrative.randi_range(0, eligible.size() - 1)]
	var client_faction := StringName(template.get("client", ""))
	var opposing_faction := StringName(template.get("opposing", ""))
	var client_members: Array = PATH_FACTION_MEMBERS.get(client_faction, [])
	var opposing_members: Array = PATH_FACTION_MEMBERS.get(opposing_faction, [])
	if client_members.is_empty() or opposing_members.is_empty():
		push_warning("AssignmentGenerator: path docket has unresolved faction members: %s / %s" % [client_faction, opposing_faction])
		return {}
	var client_id := StringName(client_members[world.rng_narrative.randi_range(0, client_members.size() - 1)])
	var opposing_id := StringName(opposing_members[world.rng_narrative.randi_range(0, opposing_members.size() - 1)])
	if client_id == opposing_id and opposing_members.size() > 1:
		for member_id in opposing_members:
			if StringName(member_id) != client_id:
				opposing_id = StringName(member_id)
				break
	var pair := "%s|%s" % [client_id, opposing_id]
	world.recent_npc_pairs.append(pair)
	while world.recent_npc_pairs.size() > 6:
		world.recent_npc_pairs.pop_front()
	var archetype_id := StringName("path_%s" % template.get("id", "docket"))
	world.recent_archetypes.append(archetype_id)
	while world.recent_archetypes.size() > 6:
		world.recent_archetypes.pop_front()
	var client_name := String(PATH_FACTION_DISPLAY_NAMES.get(client_faction, String(client_faction).replace("_", " ").capitalize()))
	var opposing_name := String(PATH_FACTION_DISPLAY_NAMES.get(opposing_faction, String(opposing_faction).replace("_", " ").capitalize()))
	var title := String(template.get("title", "LOCAL DOCKET"))
	var payload := {
		"title": title, "archetype": archetype_id, "docket_kind": "local_path",
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
	return payload


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


static func _choice(label: String, result: String, resource: StringName, amount: int, left_opinion: int, right_opinion: int, skill: String, xp: int, trait_name: String, epic_progress: int = 0, repair: bool = false) -> Dictionary:
	return {"label": label, "result_title": "MARK MADE", "result_text": result, "effects": {"resource": resource, "resource_amount": amount, "opinion_left": left_opinion, "opinion_right": right_opinion, "skill": skill, "xp": xp, "trait": trait_name, "epic_progress": epic_progress, "repair_hazard": repair}}
