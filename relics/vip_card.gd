class_name VipCardRelic
extends Relic

@export_range(1, 100) var discount := 50

var relic_ui: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	Events.shop_entered.connect(add_shop_modifier)
	relic_ui = owner


func deactivate_relic(_owner: RelicUI) -> void:
	if Events.shop_entered.is_connected(add_shop_modifier):
		Events.shop_entered.disconnect(add_shop_modifier)


func add_shop_modifier(shop: Shop) -> void:
	var shop_cost_modifier := shop.modifier_handler.get_modifier(Modifier.Type.SHOP_COST)
	assert(shop_cost_modifier, "No shop cost modifier in shop!")

	var vip_modifier_value := shop_cost_modifier.get_value("vip_card")

	if not vip_modifier_value:
		vip_modifier_value = ModifierValue.create_new_modifier("vip_card", ModifierValue.Type.PERCENT_BASED)
		vip_modifier_value.percent_value = -1 * discount / 100.0
		shop_cost_modifier.add_new_value(vip_modifier_value)

	if is_instance_valid(relic_ui):
		relic_ui.flash()
