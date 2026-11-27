class_name OfficeRunner
extends RefCounted
## Generic one-tick LimboAI runner. Blackboard carries runtime context; BT resources own decisions.

const GRAIN_TREE = preload("res://data/behavior_trees/bt_grain_clerk_agenda.tres")
const CANAL_TREE = preload("res://data/behavior_trees/bt_canal_bailiff.tres")
const ARCHIVE_TREE = preload("res://data/behavior_trees/bt_archive_keeper.tres")
const FOREMAN_TREE = preload("res://data/behavior_trees/bt_carrier_foreman.tres")
const TREE_BY_OFFICE: Dictionary = {
	&"grain_clerk": GRAIN_TREE, &"granary_clerk": GRAIN_TREE, &"umma_granary_clerk": GRAIN_TREE,
	&"canal_bailiff": CANAL_TREE, &"archive_keeper": ARCHIVE_TREE,
	&"labor_foreman": FOREMAN_TREE, &"carrier_foreman": FOREMAN_TREE
}

static func tick_official(world: WorldState, actor: PersonEntity, institution_id: StringName) -> bool:
	if world == null or actor == null or institution_id == &"": return false
	var tree: BehaviorTree = TREE_BY_OFFICE.get(actor.office_id)
	if tree == null: return false
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		push_warning("OfficeRunner: agenda tick requires a SceneTree")
		return false
	var institution: Dictionary = world.institutions.get(institution_id, {}).duplicate(true)
	if institution.is_empty(): return false
	institution["agenda_evaluation_count"] = int(institution.get("agenda_evaluation_count", 0)) + 1
	institution["last_agenda_official_id"] = actor.id
	institution["last_agenda_office_id"] = actor.office_id
	world.institutions[institution_id] = institution
	var scene_tree := main_loop as SceneTree
	var agent := Node.new()
	agent.name = "OfficeAgent"
	scene_tree.root.add_child(agent)
	var player := BTPlayer.new()
	player.set_active(false)
	player.set_update_mode(BTPlayer.MANUAL)
	player.set_agent_node(NodePath(".."))
	player.set_scene_root_hint(agent)
	player.set_behavior_tree(tree)
	agent.add_child(player)
	var blackboard: Blackboard = player.get_blackboard()
	blackboard.set_var(&"actor", actor)
	blackboard.set_var(&"institution", institution)
	blackboard.set_var(&"world", world)
	blackboard.set_var(&"institution_id", institution_id)
	player.set_active(true)
	player.update(0.0)
	player.set_active(false)
	agent.free()
	return true
