class_name Relic
extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}
enum CharacterType {ALL, ASSASSIN, BLADE, WIZARD}

@export var relic_name: String
@export var id: String
@export var type: Type
@export var character_type: CharacterType
@export var starter_relic: bool = false
@export var icon: Texture
@export_multiline var tooltip: String


func initialize_relic(_owner: RelicUI) -> void:
	pass


## 仅在玩家「新获得」该遗物时调用一次（商店/奖励/开局遗物）；读档还原列表时不调用。
## 实参为 `groups` 含 `"run"` 的 Run 节点（避免此处引用 `Run` 造成脚本循环依赖）。
func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	pass


## 异步版本的 apply_persistent_pickup_on_acquire
## 对于有UI交互的遗物（如无上宝石），此方法会被异步等待直到效果完成
func apply_persistent_pickup_on_acquire_async(_run: Node) -> void:
	## 默认实现：调用同步版本
	apply_persistent_pickup_on_acquire(_run)


func activate_relic(_owner: RelicUI) -> void:
	pass


# This method should be implemented by event-based relics
# which connect to the EventBus to make sure that they are
# disconnected when a relic gets removed.
func deactivate_relic(_owner: RelicUI) -> void:
	pass


func get_tooltip() -> String:
	return tooltip


func can_appear_as_reward(character: CharacterStats) -> bool:
	if starter_relic:
		return false

	if character_type == CharacterType.ALL:
		return true

	var relic_char_name: String = CharacterType.keys()[character_type].to_lower()
	var char_key := character.relic_match_id.strip_edges().to_lower()
	if char_key.is_empty():
		char_key = character.character_name.to_lower()

	return relic_char_name == char_key
