class_name HelpfulBoiEvent
extends EventRoom

@onready var duplicate_last_card_button: EventRoomButton = %DuplicateLastCardButton
@onready var plus_max_hp_button: EventRoomButton = %PlusMaxHPButton


func _ready() -> void:
	duplicate_last_card_button.event_button_callback = duplicate_last_card
	plus_max_hp_button.event_button_callback = plus_max_hp


func duplicate_last_card() -> void:
	var dup: Card = character_stats.deck.cards[-1].duplicate() as Card
	var run := _find_run()
	if run:
		await run.play_deck_gain_card_visual(dup, Vector2.ZERO)
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
