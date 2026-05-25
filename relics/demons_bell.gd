class_name DemonsBellRelic
extends Relic

const DEMONS_BELL_SFX := preload("res://art/demons_bell.ogg")
const ACTIVATION_DELAY := 0.5

@export var damage := 67

@export var spent := false
var _relic_ui: RelicUI
var _activation_pending := false


func is_relic_spent() -> bool:
	return spent


func apply_spent_state_from_save(is_spent: bool) -> void:
	spent = is_spent
	_activation_pending = false


func initialize_relic(owner: RelicUI) -> void:
	_relic_ui = owner
	sync_relic_ui_visual(owner)


func try_handle_relic_ui_right_click(ui: RelicUI) -> bool:
	if spent or _activation_pending:
		return false
	_relic_ui = ui
	if not _is_in_active_combat():
		return false
	_activation_pending = true
	SFXPlayer.play(DEMONS_BELL_SFX)
	_run_activation_sequence()
	return true


func _run_activation_sequence() -> void:
	if _relic_ui == null or not is_instance_valid(_relic_ui):
		_activation_pending = false
		return
	var tree := _relic_ui.get_tree()
	if tree == null:
		_activation_pending = false
		return
	await tree.create_timer(ACTIVATION_DELAY).timeout
	_activation_pending = false
	if spent or not _is_in_active_combat():
		return
	_play_sweep_fx()
	_deal_damage_to_all_enemies()
	mark_spent()


func _is_in_active_combat() -> bool:
	if Events.is_combat_ended():
		return false
	if _relic_ui == null or not is_instance_valid(_relic_ui):
		return false
	var tree := _relic_ui.get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group("battle_player")
	return player != null and is_instance_valid(player)


func _play_sweep_fx() -> void:
	if _relic_ui == null or not is_instance_valid(_relic_ui):
		return
	var tree := _relic_ui.get_tree()
	if tree == null:
		return
	var fx := tree.get_first_node_in_group("battle_card_fx")
	if fx != null and fx.has_method("play_demons_bell_sweep"):
		fx.call("play_demons_bell_sweep")


func _deal_damage_to_all_enemies() -> void:
	if _relic_ui == null or not is_instance_valid(_relic_ui):
		return
	var tree := _relic_ui.get_tree()
	if tree == null:
		return
	var enemies := tree.get_nodes_in_group("enemies")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = damage
	damage_effect.receiver_modifier_type = Modifier.Type.DMG_TAKEN
	damage_effect.execute(enemies)


func mark_spent() -> void:
	if spent:
		return
	spent = true
	GameContent.invalidate_relic_template(id)
	if is_instance_valid(_relic_ui):
		sync_relic_ui_visual(_relic_ui)
		_relic_ui.flash()
