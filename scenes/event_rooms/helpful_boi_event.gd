class_name HelpfulBoiEvent
extends EventRoom

@onready var duplicate_last_card_button: EventRoomButton = %DuplicateLastCardButton
@onready var plus_max_hp_button: EventRoomButton = %PlusMaxHPButton


func setup() -> void:
	_bind_event_buttons()
	var run := get_tree().get_first_node_in_group("run") as Run
	var used_dup := run != null and run.has_event_flag("helpful_boi_dup")
	var used_hp := run != null and run.has_event_flag("helpful_boi_hp")
	if _is_run_reload:
		duplicate_last_card_button.disabled = used_dup
		plus_max_hp_button.disabled = used_hp


func _bind_event_buttons() -> void:
	if not is_instance_valid(duplicate_last_card_button) or not is_instance_valid(plus_max_hp_button):
		return
	duplicate_last_card_button.event_button_callback = duplicate_last_card
	plus_max_hp_button.event_button_callback = plus_max_hp


func duplicate_last_card() -> void:
	if character_stats == null or character_stats.deck.cards.is_empty():
		return
	var last: Card = character_stats.deck.cards[character_stats.deck.cards.size() - 1]
	var dup: Card = last.duplicate(true) as Card
	var run := _find_run()
	if run:
		run.mark_event_flag("helpful_boi_dup")
		run.play_deck_gain_card_visual(dup, Vector2.ZERO)
	character_stats.deck.add_card(dup)
	Events.deck_card_added.emit(dup)
	duplicate_last_card_button.disabled = true


func _find_run() -> Run:
	var p := get_parent()
	while p:
		if p is Run:
			return p as Run
		p = p.get_parent()
	return null


func plus_max_hp() -> void:
	var run := _find_run()
	if run != null:
		run.mark_event_flag("helpful_boi_hp")
	character_stats.max_health += 5
	plus_max_hp_button.disabled = true
