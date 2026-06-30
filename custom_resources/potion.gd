class_name Potion
extends Resource

enum Rarity {COMMON, UNCOMMON, RARE, SPECIAL}
enum TargetKind {SELF, SINGLE_ENEMY}

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.9, 0.9, 0.9),
	Rarity.UNCOMMON: Color(129.0 / 255.0, 212.0 / 255.0, 250.0 / 255.0),
	Rarity.RARE: Color.GOLD,
	Rarity.SPECIAL: Color(175.0 / 255.0, 191.0 / 255.0, 255.0 / 255.0),
}

const RARITY_DISPLAY_NAMES := {
	Rarity.COMMON: "普通",
	Rarity.UNCOMMON: "罕见",
	Rarity.RARE: "稀有",
	Rarity.SPECIAL: "特殊",
}

@export var potion_name: String
@export var id: String
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture
@export_multiline var tooltip: String
@export var target_kind: TargetKind = TargetKind.SELF
@export var use_only_in_battle: bool = true


func can_use_in_context(tree: SceneTree) -> bool:
	if not use_only_in_battle:
		return true
	return can_use_in_context_static(tree)


static func can_use_in_context_static(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var run := tree.get_first_node_in_group("run") as Run
	if run == null:
		return false
	return run.is_in_active_battle()


func perform_use(_targets: Array[Node]) -> void:
	pass


func perform_use_async(_tree: SceneTree, targets: Array[Node]) -> void:
	perform_use(targets)
