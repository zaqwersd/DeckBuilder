class_name Run
extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload("res://scenes/battle_reward/battle_reward.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/campfire/campfire.tscn")
const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCENE = preload("res://scenes/treasure/treasure.tscn")
const WIN_SCREEN_SCENE := preload("res://scenes/win_screen/win_screen.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const DEBUG_CONSOLE := preload("res://scenes/battle/battle_debug_console.gd")

@export var run_startup: RunStartup

@onready var map: Map = $Map
@onready var current_view: Node = $CurrentView
@onready var health_ui: HealthUI = %HealthUI
@onready var gold_ui: GoldUI = %GoldUI
@onready var relic_handler: RelicHandler = %RelicHandler
@onready var relic_tooltip: RelicTooltip = %RelicTooltip
@onready var status_hover_tooltip: StatusHoverTooltip = %StatusHoverTooltip
@onready var card_keyword_tooltip: CardKeywordTooltip = %CardKeywordTooltip
@onready var deck_button: CardPileOpener = %DeckButton
@onready var pause_button: Button = %PauseButton
@onready var deck_view: CardPileView = %DeckView
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var run_card_fx: RunCardFx = $RunCardFxLayer/RunCardFx

@onready var battle_button: Button = %BattleButton
@onready var campfire_button: Button = %CampfireButton
@onready var map_button: Button = %MapButton
@onready var rewards_button: Button = %RewardsButton
@onready var shop_button: Button = %ShopButton
@onready var treasure_button: Button = %TreasureButton

var stats: RunStats
var character: CharacterStats
var save_data: SaveGame


func _ready() -> void:
	if not run_startup:
		return
	
	pause_menu.save_and_quit.connect(_on_pause_save_and_quit)
	var win := get_window()
	if win and not win.close_requested.is_connected(_on_window_close_requested):
		win.close_requested.connect(_on_window_close_requested)
	
	match run_startup.type:
		RunStartup.Type.NEW_RUN:
			character = run_startup.picked_character.create_instance()
			_start_run()
		RunStartup.Type.CONTINUED_RUN:
			_load_run()
	
	_ensure_debug_console()
func _start_run() -> void:
	stats = RunStats.new()
	
	_setup_event_connections()
	_setup_top_bar()
	
	map.generate_new_map()
	map.unlock_floor(0)
	
	save_data = SaveGame.new()
	_save_run(true)


func _save_run(was_on_map: bool) -> void:
	save_data.rng_seed = RNG.instance.seed
	save_data.rng_state = RNG.instance.state
	save_data.run_stats = stats
	save_data.last_room = map.last_room
	save_data.map_data = map.map_data.duplicate()
	save_data.floors_climbed = map.floors_climbed
	save_data.was_on_map = was_on_map
	
	# 获取当前遗物列表
	var current_relics := relic_handler.get_all_relics()
	print("_save_run: 保存 %d 个遗物 (战斗快照=%s, was_on_map=%s)" % [
		current_relics.size(),
		"有" if save_data.combat_snapshot != null else "无",
		was_on_map
	])
	
	# 如果有战斗快照（战斗进行中），不覆盖角色状态
	# 这样中途退出后重进时可以恢复到战斗开始时的状态
	if save_data.combat_snapshot != null and not was_on_map:
		# 战斗中：保留快照中的状态，但遗物仍然需要保存（战斗中遗物不会改变）
		save_data.relics = current_relics
	else:
		# 正常保存：没有快照或在地图上
		save_data.char_stats = character
		save_data.current_deck = character.deck
		save_data.current_health = character.health
		save_data.relics = current_relics
	
	save_data.save_data()


func _load_run() -> void:
	save_data = SaveGame.load_data()
	assert(save_data, "无法加载上次的存档")
	
	stats = save_data.run_stats
	character = save_data.char_stats
	character.deck = save_data.current_deck
	character.health = save_data.current_health
	if save_data.campfire_leave_pending:
		save_data.apply_campfire_pending_rollback_to(character)
	
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room)
	
	if save_data.last_room and not save_data.was_on_map:
		# 不在地图上（战斗、商店、事件等房间）
		if save_data.campfire_leave_pending and save_data.last_room.type == Room.Type.CAMPFIRE:
			# 营火房间的特殊处理
			_load_relics_from_save_data()  # 加载遗物
			_setup_top_bar()
			_change_view(
				CAMPFIRE_SCENE,
				func(n: Node) -> void:
					var cf := n as Campfire
					cf.char_stats = character
					cf.restore_leave_pending_campfire_ui()
			)
		elif save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD:
			_load_relics_from_save_data()
			_setup_top_bar()
			RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
			var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
			reward_scene.run_stats = stats
			reward_scene.character_stats = character
			reward_scene.relic_handler = relic_handler
			reward_scene.setup_from_run(true)
			## 关闭任何子界面，确保回到奖励栏主界面
			reward_scene.restore_card_picker_if_pending()
		else:
			# 其他房间（战斗、商店等）
			if save_data.combat_snapshot != null:
				# 有战斗快照：先恢复快照，然后设置UI
				save_data.combat_snapshot.apply_to(character, relic_handler, save_data.relics)
				# 如果快照恢复后遗物仍为空，尝试从 save_data.relics 恢复
				if relic_handler.get_all_relics().is_empty() and not save_data.relics.is_empty():
					push_warning("战斗快照恢复后遗物仍为空，尝试从 save_data.relics 恢复...")
					relic_handler.add_relics(save_data.relics, false)
				_setup_top_bar()  # 快照恢复后才设置UI
				_on_battle_room_entered(save_data.combat_snapshot.room, true)
			else:
				# 没有战斗快照：正常加载遗物
				_load_relics_from_save_data()
				_setup_top_bar()
				RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
				_on_map_exited(save_data.last_room, true)
	else:
		# 在地图上
		_load_relics_from_save_data()
		_setup_top_bar()
		RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)


func _load_relics_from_save_data() -> void:
	"""从存档加载遗物，优先使用战斗快照中的遗物"""
	if save_data == null:
		return
	
	print("_load_relics_from_save_data: 战斗快照=%s, save_data.relics数量=%d" % [
		"有" if save_data.combat_snapshot != null else "无",
		save_data.relics.size()
	])
	
	# 如果有战斗快照，遗物会在后续通过 apply_to 恢复
	# 这里只处理没有快照的情况
	if save_data.combat_snapshot == null:
		# 没有战斗快照，直接从存档加载遗物
		if not save_data.relics.is_empty():
			print("从 save_data.relics 加载 %d 个遗物" % save_data.relics.size())
			relic_handler.add_relics(save_data.relics, false)
			print("加载完成，当前遗物数量: %d" % relic_handler.get_all_relics().size())
		else:
			# 存档中没有遗物（新游戏或bug），添加初始遗物
			print("存档中没有遗物，由 _setup_top_bar 添加初始遗物")
	else:
		print("有战斗快照，遗物将由 apply_to 恢复")


func _change_view(scene: PackedScene, configure_before_add: Callable = Callable()) -> Node:
	Events.relic_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	if configure_before_add.is_valid():
		configure_before_add.call(new_view)
	current_view.add_child(new_view)
	map.hide_map()
	
	return new_view


func _show_map() -> void:
	Events.relic_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()

	map.show_map()
	map.unlock_next_rooms()
	
	if save_data:
		if save_data.campfire_leave_pending:
			save_data.commit_campfire_pending_to(character)
		save_data.clear_campfire_pending_staging()
		save_data.clear_room_pending()
	_save_run(true)


func _setup_event_connections() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_reward_exited.connect(_show_map)
	Events.campfire_exited.connect(_show_map)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_show_map)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.event_room_exited.connect(_show_map)
	
	battle_button.pressed.connect(_change_view.bind(BATTLE_SCENE))
	campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCENE))
	map_button.pressed.connect(_show_map)
	rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARD_SCENE))
	shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
	treasure_button.pressed.connect(_change_view.bind(TREASURE_SCENE))


func _setup_top_bar() -> void:
	var top_bar := get_node_or_null("TopBar") as CanvasLayer
	if top_bar:
		top_bar.process_mode = Node.PROCESS_MODE_ALWAYS
	if status_hover_tooltip:
		status_hover_tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	if card_keyword_tooltip:
		card_keyword_tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	if not character.stats_changed.is_connected(health_ui.update_stats.bind(character)):
		character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	gold_ui.run_stats = stats
	
	# 只有在没有遗物时才添加初始遗物（避免加载存档时重复添加）
	var current_relics := relic_handler.get_all_relics()
	if current_relics.is_empty():
		print("_setup_top_bar: 没有遗物，添加初始遗物: %s" % character.starting_relic.id)
		relic_handler.add_relic(character.starting_relic)
	else:
		print("_setup_top_bar: 已有 %d 个遗物，跳过初始遗物添加" % current_relics.size())
	if not Events.relic_tooltip_hover_show.is_connected(relic_tooltip.show_tooltip):
		Events.relic_tooltip_hover_show.connect(relic_tooltip.show_tooltip)
	if not Events.relic_tooltip_hover_hide.is_connected(relic_tooltip.hide):
		Events.relic_tooltip_hover_hide.connect(relic_tooltip.hide)
	if not Events.status_tooltip_hover_show.is_connected(status_hover_tooltip.show_tooltip):
		Events.status_tooltip_hover_show.connect(status_hover_tooltip.show_tooltip)
	if not Events.status_tooltip_hover_hide.is_connected(status_hover_tooltip.hide):
		Events.status_tooltip_hover_hide.connect(status_hover_tooltip.hide)
	if not Events.intent_tooltip_hover_show.is_connected(status_hover_tooltip.show_custom_bbcode):
		Events.intent_tooltip_hover_show.connect(status_hover_tooltip.show_custom_bbcode)
	if not Events.intent_tooltip_hover_hide.is_connected(status_hover_tooltip.hide):
		Events.intent_tooltip_hover_hide.connect(status_hover_tooltip.hide)
	if not Events.card_keyword_tooltip_show.is_connected(_on_card_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.connect(_on_card_keyword_tooltip_show)
	if not Events.card_keyword_tooltip_hide.is_connected(_on_card_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.connect(_on_card_keyword_tooltip_hide)
	
	deck_button.card_pile = character.deck
	deck_view.card_pile = character.deck
	if not deck_button.pressed.is_connected(deck_view.show_current_view.bind("牌库")):
		deck_button.pressed.connect(deck_view.show_current_view.bind("牌库"))
	if run_card_fx:
		run_card_fx.setup(deck_button)
	if pause_button and not pause_button.pressed.is_connected(_on_pause_button_pressed):
		pause_button.pressed.connect(_on_pause_button_pressed)


func _on_pause_button_pressed() -> void:
	if pause_menu.visible:
		pause_menu.close()
	else:
		pause_menu.open()


func persist_event_card_reward_pending(scene_path: String, key: String, card_ids: PackedStringArray) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_EVENT
	save_data.pending_event_scene_path = scene_path
	save_data.pending_event_key = key
	save_data.pending_card_template_ids = card_ids
	_save_run(false)


func matches_pending_event(scene_path: String, key: String) -> bool:
	return (
		save_data != null
		and save_data.pending_room_kind == SaveGame.PENDING_EVENT
		and save_data.pending_event_scene_path == scene_path
		and save_data.pending_event_key == key
	)


func get_pending_card_templates() -> Array[Card]:
	if save_data == null:
		return []
	return GameContent.load_cards_by_ids(save_data.pending_card_template_ids)


func persist_treasure_pending(relic_id: String) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_TREASURE
	save_data.pending_relic_ids = PackedStringArray([relic_id])
	_save_run(false)


func get_pending_treasure_relic() -> Relic:
	if save_data == null or save_data.pending_room_kind != SaveGame.PENDING_TREASURE:
		return null
	if save_data.pending_relic_ids.is_empty():
		return null
	return GameContent.load_relic_template(save_data.pending_relic_ids[0])


func can_restore_shop_pending() -> bool:
	return save_data != null and save_data.pending_room_kind == SaveGame.PENDING_SHOP


func persist_shop_pending(
	card_ids: PackedStringArray,
	relic_ids: PackedStringArray,
	card_costs: PackedInt32Array,
	relic_costs: PackedInt32Array,
	card_sold: PackedInt32Array,
	relic_sold: PackedInt32Array
) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_SHOP
	save_data.pending_card_template_ids = card_ids
	save_data.pending_relic_ids = relic_ids
	var packed := PackedInt32Array()
	for v: int in card_costs:
		packed.append(v)
	for v: int in relic_costs:
		packed.append(v)
	for v: int in card_sold:
		packed.append(v)
	for v: int in relic_sold:
		packed.append(v)
	save_data.pending_shop_ints = packed
	_save_run(false)


func get_shop_pending_data() -> Dictionary:
	if not can_restore_shop_pending():
		return {}
	var ints := save_data.pending_shop_ints
	return {
		"card_ids": save_data.pending_card_template_ids,
		"relic_ids": save_data.pending_relic_ids,
		"card_costs": ints.slice(0, 3),
		"relic_costs": ints.slice(3, 6),
		"card_sold": ints.slice(6, 9),
		"relic_sold": ints.slice(9, 12),
	}


func persist_battle_reward_cards_pending(card_ids: PackedStringArray) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_BATTLE_REWARD
	save_data.pending_card_template_ids = card_ids
	_save_run(false)


func can_restore_battle_reward_cards() -> bool:
	return save_data != null and save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD


## 保存完整的战斗奖励画面初始状态（金币、遗物、卡牌）
func persist_battle_reward_full_state(gold: int, relics: Array[Relic]) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_BATTLE_REWARD
	save_data.battle_reward_gold = gold
	save_data.battle_reward_gold_taken = false
	save_data.battle_reward_relic_ids = PackedStringArray()
	for r: Relic in relics:
		if r != null:
			save_data.battle_reward_relic_ids.append(r.id)
	save_data.battle_reward_relics_taken = PackedInt32Array()
	for i: int in range(relics.size()):
		save_data.battle_reward_relics_taken.append(0)
	save_data.battle_reward_cards_taken = false
	_save_run(false)


## 更新奖励领取状态
func take_battle_reward_gold() -> void:
	if save_data == null:
		return
	save_data.battle_reward_gold_taken = true
	_save_run(false)


func take_battle_reward_relic(index: int) -> void:
	if save_data == null or index < 0 or index >= save_data.battle_reward_relics_taken.size():
		return
	save_data.battle_reward_relics_taken[index] = 1
	_save_run(false)


func take_battle_reward_cards() -> void:
	if save_data == null:
		return
	save_data.battle_reward_cards_taken = true
	_save_run(false)


## 获取战斗奖励状态
func get_battle_reward_state() -> Dictionary:
	if save_data == null:
		return {}
	return {
		"gold": save_data.battle_reward_gold,
		"gold_taken": save_data.battle_reward_gold_taken,
		"relic_ids": save_data.battle_reward_relic_ids,
		"relics_taken": save_data.battle_reward_relics_taken,
		"card_ids": save_data.pending_card_template_ids,
		"cards_taken": save_data.battle_reward_cards_taken,
	}


func clear_room_pending_and_save() -> void:
	if save_data == null:
		return
	save_data.clear_room_pending()
	_save_run(false)


func _on_card_keyword_tooltip_show(ids: PackedStringArray, near_to: Control) -> void:
	## 战斗选牌/升级等高层模态自带 tooltip；全局 TopBar tooltip 勿画在幕布下层。
	if Events.is_pointer_ui_obscured_for(card_keyword_tooltip):
		return
	card_keyword_tooltip.show_keyword_blocks(ids, near_to)


func _on_card_keyword_tooltip_hide() -> void:
	if Events.is_pointer_ui_obscured_for(card_keyword_tooltip):
		return
	card_keyword_tooltip.hide_tooltip()


func play_deck_gain_card_visual(card: Card, from_global: Vector2) -> void:
	if run_card_fx:
		run_card_fx.call_deferred("_deferred_animate_card_to_deck", card, from_global)


func await_deck_gain_card_visual(card: Card, from_global: Vector2 = Vector2.ZERO) -> void:
	if run_card_fx and card:
		await run_card_fx.animate_card_to_deck(card, from_global)


func play_deck_gain_card_visual_with_pick(picked: CardMenuUI, from_global: Vector2) -> void:
	if run_card_fx:
		run_card_fx.call_deferred("_deferred_animate_picked_to_deck", picked, from_global)


func play_deck_remove_card_shrink_remove_and_wait(card: Card) -> void:
	if run_card_fx:
		await run_card_fx.animate_card_center_shrink_remove(card)


func play_deck_remove_two_cards_fade_and_wait(card1: Card, card2: Card) -> void:
	if run_card_fx:
		await run_card_fx.animate_two_cards_center_fade_remove(card1, card2)


func _show_regular_battle_rewards() -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler
	reward_scene.setup_from_run(false)

	reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
	reward_scene.add_card_reward()
	## 所有奖励添加完成后，保存初始状态
	reward_scene.save_initial_state()


func _on_battle_room_entered(room: Room, is_reload: bool = false) -> void:
	# 如果不是重新加载（即新进入战斗），创建战斗快照
	if not is_reload:
		_save_combat_snapshot(room)
	
	var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
	if not is_instance_valid(battle_scene):
		push_error("无法实例化战斗场景")
		return
	battle_scene.char_stats = character
	battle_scene.battle_stats = room.battle_stats
	battle_scene.relics = relic_handler
	battle_scene.start_battle()


func _save_combat_snapshot(room: Room) -> void:
	if save_data == null:
		return
	var current_relics := relic_handler.get_all_relics()
	save_data.combat_snapshot = CombatSnapshot.create_from(character, current_relics, room)
	# 确保遗物也被保存到 save_data.relics（作为后备）
	save_data.relics = current_relics.duplicate()
	_save_run(false)


func _clear_combat_snapshot() -> void:
	if save_data == null:
		return
	save_data.combat_snapshot = null
	# 清除遗物缓存
	CombatSnapshot._relics_cache.clear()
	_save_run(false)


func _on_treasure_room_entered(is_reload: bool = false) -> void:
	var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
	treasure_scene.relic_handler = relic_handler
	treasure_scene.char_stats = character
	treasure_scene.populate_from_run(is_reload)


func _on_treasure_room_exited(relic: Relic) -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler
	reward_scene.setup_from_run(false)

	var treasure_gold := RNG.instance.randi_range(25, 50)
	reward_scene.add_gold_reward(treasure_gold)
	reward_scene.add_relic_reward(relic)
	## 所有奖励添加完成后，保存初始状态
	reward_scene.save_initial_state()


func _on_campfire_entered() -> void:
	_change_view(
		CAMPFIRE_SCENE,
		func(n: Node) -> void:
			var cf := n as Campfire
			cf.char_stats = character
			cf.begin_fresh_campfire_visit(self)
	)


func _on_shop_entered(is_reload: bool = false) -> void:
	var shop := _change_view(SHOP_SCENE) as Shop
	shop.char_stats = character
	shop.run_stats = stats
	shop.relic_handler = relic_handler
	Events.shop_entered.emit(shop)
	shop.populate_shop(is_reload)


func _on_event_room_entered(room: Room, is_reload: bool = false) -> void:
	var event_room: Node = _change_view(room.event_scene)
	event_room.set("character_stats", character)
	event_room.set("run_stats", stats)
	if event_room.has_method("set_run_reload"):
		event_room.call("set_run_reload", is_reload)
	if event_room.has_method("setup"):
		event_room.call("setup")


func debug_enter_event(id: String) -> String:
	var scene := _load_event_scene_by_id(id)
	if scene == null:
		return "找不到事件：%s（可用 scenes/event_rooms 下 .tscn 名或 res:// 完整路径）" % id
	var room := Room.new()
	room.type = Room.Type.EVENT
	room.event_scene = scene
	_on_event_room_entered(room)
	return "已进入事件：%s" % id.strip_edges()


func _load_event_scene_by_id(id: String) -> PackedScene:
	var t := id.strip_edges()
	if t.is_empty():
		return null
	if t.begins_with("res://") and t.ends_with(".tscn") and ResourceLoader.exists(t):
		return load(t) as PackedScene
	var base := t.get_file().trim_suffix(".tscn") if t.contains("/") else t.trim_suffix(".tscn")
	var path := "res://scenes/event_rooms/%s.tscn" % base
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


func _ensure_debug_console() -> void:
	if get_node_or_null("DebugConsoleLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DebugConsoleLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dbg := DEBUG_CONSOLE.new()
	dbg.name = "GameplayDebugConsole"
	layer.add_child(dbg)


func _on_battle_won() -> void:
	_clear_combat_snapshot()
	if map.floors_climbed == MapGenerator.FLOORS:
		var win_screen := _change_view(WIN_SCREEN_SCENE) as WinScreen
		win_screen.character = character
		SaveGame.delete_data()
	else:
		_show_regular_battle_rewards()


func _on_pause_save_and_quit() -> void:
	if save_data:
		# 如果在战斗中退出，保持现有的战斗快照（不覆盖为当前状态）
		_save_run(map.visible)
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_window_close_requested() -> void:
	if save_data:
		_save_run(map.visible)


func _on_map_exited(room: Room, is_reload: bool = false) -> void:
	_save_run(false)
	
	match room.type:
		Room.Type.MONSTER:
			_on_battle_room_entered(room, is_reload)
		Room.Type.TREASURE:
			_on_treasure_room_entered(is_reload)
		Room.Type.CAMPFIRE:
			_on_campfire_entered()
		Room.Type.SHOP:
			_on_shop_entered(is_reload)
		Room.Type.BOSS:
			_on_battle_room_entered(room, is_reload)
		Room.Type.EVENT:
			_on_event_room_entered(room, is_reload)
