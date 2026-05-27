class_name Relic
extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}
enum CharacterType {ALL, ASSASSIN, BLADE, WIZARD}
enum Rarity {STARTER, COMMON, UNCOMMON, RARE, SPECIAL, SHOP}

const RARITY_COLORS := {
	Rarity.STARTER: Color.GRAY,
	Rarity.COMMON: Color(0.9, 0.9, 0.9),
	Rarity.UNCOMMON: Color(129.0 / 255.0, 212.0 / 255.0, 250.0 / 255.0),
	Rarity.RARE: Color.GOLD,
	Rarity.SPECIAL: Color(175.0 / 255.0, 191.0 / 255.0, 255.0 / 255.0),
	Rarity.SHOP: Color(114.0 / 255.0, 213.0 / 255.0, 114.0 / 255.0),
}

const RARITY_DISPLAY_NAMES := {
	Rarity.STARTER: "初始",
	Rarity.COMMON: "普通",
	Rarity.UNCOMMON: "罕见",
	Rarity.RARE: "稀有",
	Rarity.SPECIAL: "特殊",
	Rarity.SHOP: "商店",
}

const SPENT_TOOLTIP := "这个遗物已失效。"
const SPENT_ICON_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

@export var relic_name: String
@export var id: String
@export var type: Type
@export var character_type: CharacterType
@export var rarity: Rarity = Rarity.COMMON
@export var starter_relic: bool = false
@export var icon: Texture
@export_multiline var tooltip: String


func initialize_relic(_owner: RelicUI) -> void:
	pass


## 仅在玩家「新获得」该遗物时调用一次（商店/奖励/开局遗物）；读档还原列表时不调用。
## 实参为 `groups` 含 `"run"` 的 Run 节点（避免此处引用 `Run` 造成脚本循环依赖）。
func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	pass


## 读档/取消领取时撤销尚未确认的 apply_persistent_pickup_on_acquire 效果
func revert_persistent_pickup_on_rollback(ch: CharacterStats) -> void:
	pass


## 为 true 时：先挂到遗物栏再执行拾起效果（如大礼包，购买后立即可见）
func add_to_bar_before_persistent_pickup() -> bool:
	return false


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


## 遗物栏右键；返回 true 表示已处理（如恶魔铃铛主动使用）。
func try_handle_relic_ui_right_click(_ui: RelicUI) -> bool:
	return false


func is_relic_spent() -> bool:
	return false


func apply_spent_state_from_save(spent: bool) -> void:
	pass


## 从模板/存档加载实例时先清零，再由 apply_spent_relic_ids 按存档写入
func reset_spent_state_for_load() -> void:
	apply_spent_state_from_save(false)


func sync_relic_ui_visual(ui: RelicUI) -> void:
	if ui == null or not is_instance_valid(ui.icon):
		return
	if is_relic_spent():
		ui.icon.modulate = SPENT_ICON_MODULATE
	else:
		ui.icon.modulate = Color.WHITE


func get_tooltip() -> String:
	if is_relic_spent():
		return SPENT_TOOLTIP
	return tooltip


## 非 null 时：本场战斗首次 `start_turn`、抽牌前加入手牌最左侧（每场一次）。
func create_battle_start_hand_card() -> Card:
	return null


func get_rarity_display_name() -> String:
	return RARITY_DISPLAY_NAMES.get(rarity, "")


func _matches_character(character: CharacterStats) -> bool:
	if character_type == CharacterType.ALL:
		return true
	var relic_char_name: String = CharacterType.keys()[character_type].to_lower()
	var char_key := character.relic_match_id.strip_edges().to_lower()
	if char_key.is_empty():
		char_key = character.character_name.to_lower()
	return relic_char_name == char_key


func can_appear_as_reward(character: CharacterStats) -> bool:
	if starter_relic or rarity == Rarity.STARTER or rarity == Rarity.SHOP or rarity == Rarity.SPECIAL:
		return false
	return _matches_character(character)


func can_appear_in_shop(character: CharacterStats) -> bool:
	if starter_relic or rarity == Rarity.STARTER or rarity == Rarity.SPECIAL:
		return false
	return _matches_character(character)
