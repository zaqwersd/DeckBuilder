class_name HelpfulBoiEvent
extends EventRoom

@onready var duplicate_last_card_button: EventRoomButton = %DuplicateLastCardButton
@onready var plus_max_hp_button: EventRoomButton = %PlusMaxHPButton


func _ready() -> void:
	duplicate_last_card_button.event_button_callback = duplicate_last_card
	plus_max_hp_button.event_button_callback = plus_max_hp


func setup() -> void:
	# 如果是重载，重置按钮为可用状态（场景快照已恢复角色状态）
	if _is_run_reload:
		duplicate_last_card_button.disabled = false
		plus_max_hp_button.disabled = false


func duplicate_last_card() -> void:
	if character_stats == null or character_stats.deck.cards.is_empty():
		return
	var last: Card = character_stats.deck.cards[character_stats.deck.cards.size() - 1]
	var dup: Card = last.duplicate(true) as Card
	var run := _find_run()
	if run:
		run.play_deck_gain_card_visual(dup, Vector2.ZERO)
	character_stats.deck.add_card(dup)


func _find_run() -> Run:
	var p := get_parent()
	while p:
		if p is Run:
			return p as Run
		p = p.get_parent()
	return null


func plus_max_hp() -> void:
	character_stats.max_health += 5
