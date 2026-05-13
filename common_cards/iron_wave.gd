extends Card

var base_damage := 6
var base_block := 6


func get_default_tooltip() -> String:
	return tooltip_text % [base_block, base_damage]


func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_dmg := base_damage
	if player_modifiers:
		modified_dmg = player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	var dmg_bb := bbcode_for_modified_number(modified_dmg, base_damage)
	var block_bb := bbcode_for_modified_number(base_block, base_block)
	return tooltip_text % [block_bb, dmg_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var tree: SceneTree = null
	for t: Node in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			tree = t.get_tree()
			break
	var player_nodes: Array[Node] = []
	if tree:
		player_nodes.append_array(tree.get_nodes_in_group("player"))
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.execute(player_nodes)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
