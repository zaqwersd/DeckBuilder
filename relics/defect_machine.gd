extends Relic
class_name DefectMachineRelic

## 每场战斗第一张牌打出后，再结算一次效果（不再次扣费、不再次触发「打出」事件）。
## 计数在战斗开始时重置。
static var _echo_charges: int = 0


func activate_relic(_owner: RelicUI) -> void:
	if type == Type.START_OF_COMBAT:
		_echo_charges = 1


static func has_echo_pending() -> bool:
	return _echo_charges > 0


static func consume_echo() -> void:
	_echo_charges = maxi(0, _echo_charges - 1)
