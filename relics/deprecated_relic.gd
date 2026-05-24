class_name DeprecatedRelic
extends Relic

const TEMPLATE_PATH := "res://relics/deprecated_relic.tres"


static func create_for_legacy_id(legacy_id: String) -> Relic:
	var template := load(TEMPLATE_PATH) as Relic
	if template == null:
		return null
	var inst := template.duplicate(true) as Relic
	inst.relic_name = "已弃用"
	if legacy_id.is_empty():
		inst.id = "_deprecated"
		inst.tooltip = "该遗物已从游戏中移除。"
	else:
		inst.id = legacy_id
		inst.tooltip = "遗物「%s」已移除，仅作占位显示。" % legacy_id
	return inst


func can_appear_as_reward(_character: CharacterStats) -> bool:
	return false


func can_appear_in_shop(_character: CharacterStats) -> bool:
	return false
