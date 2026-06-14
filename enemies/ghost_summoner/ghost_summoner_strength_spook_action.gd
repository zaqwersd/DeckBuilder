extends EnemyAction

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

@export var spook_strength_stacks := 5
@export var self_strength_stacks := 3


func perform_action() -> void:
	if not enemy:
		return
	var spook := _find_spook()
	var strength := STRENGTH_STATUS.duplicate()
	var recipients: Array[Node] = []
	if spook != null:
		strength.stacks = spook_strength_stacks
		recipients = [spook]
	else:
		strength.stacks = self_strength_stacks
		recipients = [enemy]
	var status_effect := StatusEffect.new()
	status_effect.status = strength
	status_effect.execute(recipients)
	SFXPlayer.play(sound)
	Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN


func _find_spook() -> Enemy:
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return null
	return handler.find_live_spook()
