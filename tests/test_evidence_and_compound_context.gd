extends SceneTree

const Pipeline = preload("res://systems/assignment_pipeline.gd")
const Narrator = preload("res://systems/assignment_narrator.gd")
const CompoundContext = preload("res://systems/compound_context.gd")
const SaveCodec = preload("res://systems/save_codec.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ResourceLoader.exists("res://assets/fonts/NotoSansCuneiform-Regular.ttf"), "Cuneiform font exists")
	_check(Pipeline._live_stock_facts({"offerings": 24}, {}).contains("OFFERINGS: 24"), "Custom shrine offerings are displayed")
	_check(not Pipeline._live_stock_facts({"offerings": 24}, {}).contains("BARLEY: 0"), "Shrines do not invent barley")
	_check(Pipeline._live_stock_facts({}, {}).contains("None on record"), "Empty inventory reports none on record")
	var clean_evidence := Pipeline._sanitize_evidence_text("CAPABILITY APPLIED: inspect_source\\nFORM: pension_roll / form_000005")
	_check(not clean_evidence.contains("CAPABILITY APPLIED:") and not clean_evidence.contains("form_00000"), "Evidence strips capability diagnostics and internal form IDs")
	var clean_dossier := Narrator._clean_display("FORM: pension_roll", "Fallback")
	_check(clean_dossier.contains("RECORD TYPE: Pension Ledger"), "Dossier translates raw form labels into authored titles")
	var world := WorldState.new()
	world.places[&"uruk"] = {"parent": &""}
	world.places[&"umma"] = {"parent": &""}
	world.places[&"nippur"] = {"parent": &""}
	world.institutions[&"eanna_household"] = {"place_id": &"uruk", "members": []}
	world.institutions[&"umma_canal_bailiff"] = {"place_id": &"umma", "members": [&"character_0013"]}
	world.institutions[&"umma_granary"] = {"place_id": &"umma", "members": [&"character_0012"]}
	world.institutions[&"nippur_shrine"] = {"place_id": &"nippur", "members": []}
	var bailiff := PersonEntity.new()
	bailiff.id = &"character_0013"
	bailiff.display_name = "Ur-Mes"
	bailiff.office_id = &"canal_bailiff"
	world.people[bailiff.id] = bailiff
	var clerk := PersonEntity.new()
	clerk.id = &"character_0012"
	clerk.display_name = "Nin-Enlil"
	clerk.office_id = &"grain_clerk"
	world.people[clerk.id] = clerk
	var umma_ids := CompoundContext.institution_ids(world, &"umma")
	var officials := CompoundContext.officials(world, umma_ids)
	_check(umma_ids.has(&"umma_canal_bailiff") and umma_ids.has(&"umma_granary"), "Umma returns its institutions")
	_check(not umma_ids.has(&"eanna_household"), "Uruk institutions are excluded in Umma")
	_check(officials.has(bailiff) and officials.has(clerk), "Umma returns seated officials")
	var nippur_ids := CompoundContext.institution_ids(world, &"nippur")
	_check(nippur_ids.has(&"nippur_shrine") and not nippur_ids.has(&"umma_granary"), "Nippur remains location-scoped")
	var player := PersonEntity.new()
	player.id = &"delta_save_player"
	player.display_name = "Delta Save Player"
	world.set_player(player)
	world.last_period_deltas = [{"category": "upkeep", "text": "Upkeep paid: -2 silver"}]
	var encoded := SaveCodec.encode_world(world)
	var decoded := SaveCodec.decode_save(encoded)
	var restored: WorldState = decoded.get("world") as WorldState
	_check(bool(decoded.get("success", false)) and restored != null, "SaveCodec round-trip succeeds")
	if restored != null:
		_check(restored.last_period_deltas.size() == 1, "SaveCodec restores period deltas")
	var legacy: Dictionary = encoded.duplicate(true)
	legacy["world"].erase("last_period_deltas")
	var legacy_result := SaveCodec.decode_save(legacy)
	var legacy_world: WorldState = legacy_result.get("world") as WorldState
	_check(bool(legacy_result.get("success", false)) and legacy_world != null and legacy_world.last_period_deltas.is_empty(), "Legacy saves default deltas to empty")
	if failures.is_empty():
		print("PASS: %d evidence and compound-context checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d/%d checks failed" % [failures.size(), checks])
		for failure in failures:
			printerr(" - " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
