class_name StatusEffect
extends Effect

var status: Status


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is Enemy or target is Player:
			## 直接添加 status（卡牌脚本中已调用 duplicate 并配置了属性）
			target.status_handler.add_status(status)
