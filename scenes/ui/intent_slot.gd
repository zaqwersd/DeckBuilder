class_name IntentSlot
extends HBoxContainer


func setup(intent: Intent) -> void:
	var icon := get_node_or_null("Icon") as TextureRect
	var value_label := get_node_or_null("ValueLabel") as Label
	if intent == null or icon == null or value_label == null:
		hide()
		return
	var tex := intent.get_display_icon()
	icon.texture = tex
	icon.visible = tex != null
	if tex != null:
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 仅攻击：单段显示伤害数字；多段显示「伤害×段数」；格挡/强化/减益/侵蚀只显示图标
	if intent.kind == Intent.Kind.ATTACK:
		var has_num := intent.display_number != Intent.NUMBER_HIDDEN
		var has_txt := not intent.current_text.is_empty()
		value_label.visible = has_num or has_txt
		if has_txt:
			value_label.text = intent.current_text
		elif has_num:
			value_label.text = str(intent.display_number)
		else:
			value_label.text = ""
	else:
		value_label.visible = false
		value_label.text = ""
	show()
