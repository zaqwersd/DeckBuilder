extends Relic

const SCENT := preload("res://common_cards/scent.tres")
const SCENT_NAME_GREEN := "[color=#5dff7a]气息[/color]"


func get_tooltip() -> String:
	return "每场战斗开始时，将一张%s加入你的手牌。" % SCENT_NAME_GREEN


func create_battle_start_hand_card() -> Card:
	return SCENT.duplicate(true) as Card
