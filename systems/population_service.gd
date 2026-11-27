class_name PopulationService
extends RefCounted

const NAME_TABLE_PATH := "res://data/tables/era1_sumerian_names.csv"
const CORE_SKILLS: Array[StringName] = [
	&"literacy", &"arithmetic", &"law", &"rhetoric", &"intrigue", &"stewardship"
]

var _names_by_culture: Dictionary = {}

func load_name_table(path: String = NAME_TABLE_PATH) -> bool:
	_names_by_culture.clear()
	if not FileAccess.file_exists(path):
		push_warning("PopulationService: missing name table '%s'" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("PopulationService: cannot read name table '%s'" % path)
		return false
	var header := file.get_csv_line()
	if header.size() < 6:
		push_warning("PopulationService: name table needs name,culture,era_id,gender,provenance,source columns")
		return false
	var columns: Dictionary = {}
	for index in range(header.size()):
		columns[String(header[index]).strip_edges()] = index
	for required in ["name", "culture", "era_id", "gender", "provenance", "source"]:
		if not columns.has(required):
			push_warning("PopulationService: name table missing column '%s'" % required)
			return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size():
			continue
		var name := String(row[columns["name"]]).strip_edges()
		var culture := StringName(row[columns["culture"]].strip_edges())
		if name.is_empty() or culture == &"":
			continue
		if not _names_by_culture.has(culture):
			_names_by_culture[culture] = []
		_names_by_culture[culture].append({
			"name": name,
			"era_id": StringName(row[columns["era_id"]].strip_edges()),
			"gender": StringName(row[columns["gender"]].strip_edges()),
			"provenance": StringName(row[columns["provenance"]].strip_edges()),
			"source": String(row[columns["source"]]).strip_edges()
		})
	return not _names_by_culture.is_empty()

func generate_people(
	world: WorldState,
	definitions: DefinitionRegistry,
	location_id: StringName,
	culture_id: StringName,
	era_id: StringName,
	count: int,
	generation_key: StringName
) -> Array[PersonEntity]:
	var generated: Array[PersonEntity] = []
	if world == null or definitions == null or location_id == &"" or culture_id == &"" or era_id == &"" or count <= 0:
		return generated
	if not world.places.has(location_id):
		push_warning("PopulationService: unknown location '%s'" % location_id)
		return generated
	if generation_key == &"":
		push_warning("PopulationService: generation_key is required for idempotent generation")
		return generated
	var batch_key := StringName("%s|%s|%s|%s" % [location_id, culture_id, era_id, generation_key])
	if world.population_batches.has(batch_key):
		for person_id in world.population_batches[batch_key]:
			var existing := world.get_person(StringName(person_id))
			if existing != null:
				generated.append(existing)
		return generated
	if _names_by_culture.is_empty() and not load_name_table():
		return generated

	var occupations: Array[OccupationDef] = []
	for resource in definitions.get_definitions("occupations"):
		var occupation := resource as OccupationDef
		if occupation != null and _occupation_matches(occupation, culture_id, era_id):
			occupations.append(occupation)
	var templates: Array[CharacterTemplate] = []
	for resource in definitions.get_definitions("character_templates"):
		var template := resource as CharacterTemplate
		if template != null and template.culture_id == culture_id and _era_matches(template.era_ids, era_id):
			var template_occupation := definitions.get_definition(template.occupation_id) as OccupationDef
			if template_occupation != null and _occupation_matches(template_occupation, culture_id, era_id):
				templates.append(template)
	if occupations.is_empty() or templates.is_empty():
		push_warning("PopulationService: no eligible occupations/templates for %s in %s" % [culture_id, era_id])
		return generated
	var name_entries: Array = _eligible_names(culture_id, era_id)
	if name_entries.is_empty():
		push_warning("PopulationService: no eligible names for %s in %s" % [culture_id, era_id])
		return generated

	var used_names: Dictionary = {}
	for person in world.people.values():
		if person != null:
			used_names[String(person.display_name).to_lower()] = true
	var batch_ids: Array[StringName] = []
	for index in range(count):
		var template := _weighted_pick_template(templates, definitions, world.rng_people)
		if template == null:
			continue
		var occupation := definitions.get_definition(template.occupation_id) as OccupationDef
		if occupation == null:
			continue
		var entry: Dictionary = _pick_unique_name(name_entries, used_names, world.rng_people)
		if entry.is_empty():
			push_warning("PopulationService: exhausted unique name entries for %s" % culture_id)
			break
		var person := PersonEntity.new()
		person.id = world.allocate_person_id()
		person.display_name = String(entry["name"])
		person.location_id = location_id
		person.template_id = template.id
		person.occupation_id = occupation.id
		person.generation_source = &"tier2"
		person.generation_key = batch_key
		person.name_provenance = StringName(entry["provenance"])
		person.name_source = String(entry["source"])
		person.name_gender = StringName(entry["gender"])
		person.office_id = occupation.office_id
		for skill_id in CORE_SKILLS:
			person.skills.levels[skill_id] = 1
		for skill_id in occupation.skill_ranges:
			var bounds: Vector2i = occupation.skill_ranges[skill_id]
			person.skills.levels[StringName(skill_id)] = world.rng_people.randi_range(bounds.x, bounds.y)
		for skill_id in template.skill_bonuses:
			var skill := StringName(skill_id)
			person.skills.levels[skill] = maxi(0, int(person.skills.levels.get(skill, 1)) + int(template.skill_bonuses[skill]))
		var trait_candidates: Array[StringName] = []
		trait_candidates.append_array(occupation.trait_ids)
		trait_candidates.append_array(template.trait_ids)
		for trait_id in trait_candidates:
			var trait_def := definitions.get_definition(trait_id) as TraitDef
			if trait_def != null and _trait_matches(trait_def, culture_id, era_id) and trait_id not in person.traits:
				person.traits.append(trait_id)
		world.people[person.id] = person
		batch_ids.append(person.id)
		generated.append(person)
	world.population_batches[batch_key] = batch_ids
	return generated

func _occupation_matches(occupation: OccupationDef, culture_id: StringName, era_id: StringName) -> bool:
	return (occupation.culture_tags.is_empty() or culture_id in occupation.culture_tags) and _era_matches(occupation.era_ids, era_id)

func _era_matches(era_ids: Array[StringName], era_id: StringName) -> bool:
	return era_ids.is_empty() or era_id in era_ids

func _trait_matches(trait_def: TraitDef, culture_id: StringName, era_id: StringName) -> bool:
	return (trait_def.culture_tags.is_empty() or culture_id in trait_def.culture_tags) and _era_matches(trait_def.era_ids, era_id)

func _eligible_names(culture_id: StringName, era_id: StringName) -> Array:
	var result: Array = []
	for entry in _names_by_culture.get(culture_id, []):
		var entry_era: StringName = entry.get("era_id", &"")
		if entry_era == &"" or entry_era == era_id:
			result.append(entry)
	return result

func _pick_unique_name(entries: Array, used_names: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	for entry in entries:
		if not used_names.has(String(entry["name"]).to_lower()):
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	used_names[String(picked["name"]).to_lower()] = true
	return picked

func _weighted_pick_template(templates: Array[CharacterTemplate], definitions: DefinitionRegistry, rng: RandomNumberGenerator) -> CharacterTemplate:
	var total := 0
	for template in templates:
		var occupation := definitions.get_definition(template.occupation_id) as OccupationDef
		if occupation != null:
			total += maxi(1, template.weight) * maxi(1, occupation.weight)
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for template in templates:
		var occupation := definitions.get_definition(template.occupation_id) as OccupationDef
		if occupation == null:
			continue
		roll -= maxi(1, template.weight) * maxi(1, occupation.weight)
		if roll <= 0:
			return template
	return templates.back()


func seat_institution_staff(world: WorldState, definitions: DefinitionRegistry) -> void:
	if world == null or definitions == null:
		return
	var institution_ids: Array[StringName] = []
	for key in world.institutions.keys():
		institution_ids.append(StringName(key))
	institution_ids.sort()
	for institution_id in institution_ids:
		var institution: Dictionary = world.institutions.get(institution_id, {})
		var place_id := StringName(institution.get("place_id", ""))
		var offices: Array[StringName] = []
		for office_value in institution.get("staffed_offices", []):
			offices.append(StringName(office_value))
		offices.sort()
		if place_id == &"" or offices.is_empty():
			continue
		var members: Array = institution.get("members", []).duplicate()
		var office_map: Dictionary = institution.get("offices", {}).duplicate(true)
		for office_id in offices:
			var filled := false
			for member_value in members:
				var member := world.get_person(StringName(member_value))
				if member != null and member.office_id == office_id:
					filled = true
					break
			if filled:
				continue
			var candidates: Array[PersonEntity] = []
			for person in world.people.values():
				if person != null and person.location_id == place_id and person.office_id == &"" and person.generation_source == &"tier2":
					candidates.append(person)
			candidates.sort_custom(func(a: PersonEntity, b: PersonEntity) -> bool:
					var a_score := a.skills.get_level(&"stewardship") + a.skills.get_level(&"arithmetic") + a.skills.get_level(&"literacy") + a.skills.get_level(&"law")
					var b_score := b.skills.get_level(&"stewardship") + b.skills.get_level(&"arithmetic") + b.skills.get_level(&"literacy") + b.skills.get_level(&"law")
					if a_score == b_score:
						return String(a.id) < String(b.id)
					return a_score > b_score
			)
			if candidates.is_empty():
				continue
			var selected := candidates[0]
			selected.office_id = office_id
			members.append(selected.id)
			office_map[office_id] = selected.id
		institution["members"] = members
		institution["offices"] = office_map
		world.institutions[institution_id] = institution
