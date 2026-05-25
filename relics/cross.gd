class_name CrossRelic
extends Relic

@export var heal_fraction := 0.5

@export var spent := false
var _relic_ui: RelicUI


func is_relic_spent() -> bool:
	return spent


func apply_spent_state_from_save(is_spent: bool) -> void:
	spent = is_spent


func initialize_relic(owner: RelicUI) -> void:
	_relic_ui = owner
	sync_relic_ui_visual(owner)


func try_trigger(player: Player) -> bool:
	if spent or player == null or not is_instance_valid(player) or player.stats == null:
		return false
	if player.stats.health > 0:
		return false
	var amount := ceili(float(player.stats.max_health) * heal_fraction)
	if amount <= 0:
		amount = 1
	player.stats.heal(amount)
	player.update_stats()
	mark_spent()
	return true


func mark_spent() -> void:
	if spent:
		return
	spent = true
	GameContent.invalidate_relic_template(id)
	if is_instance_valid(_relic_ui):
		sync_relic_ui_visual(_relic_ui)
		_relic_ui.flash()
