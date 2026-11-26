class_name AssignmentGenerator
extends RefCounted

const GOODS: Array[StringName] = [&"barley", &"dates", &"fish", &"beer", &"wool", &"textiles", &"timber", &"copper"]
const DAMAGED_GOODS: Array[StringName] = [&"beer", &"wool", &"textiles"]
const ARCHETYPES: Array[StringName] = [&"delivery_mismatch", &"damaged_consignment", &"subtotal_claim", &"goods_unreturned", &"hazard_check"]

static func generate(world: WorldState, actor: PersonEntity) -> Dictionary:
	if world == null or actor == null:
		return {}
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

static func _choice(label: String, result: String, resource: StringName, amount: int, left_opinion: int, right_opinion: int, skill: String, xp: int, trait_name: String, epic_progress: int = 0, repair: bool = false) -> Dictionary:
	return {"label": label, "result_title": "MARK MADE", "result_text": result, "effects": {"resource": resource, "resource_amount": amount, "opinion_left": left_opinion, "opinion_right": right_opinion, "skill": skill, "xp": xp, "trait": trait_name, "epic_progress": epic_progress, "repair_hazard": repair}}
