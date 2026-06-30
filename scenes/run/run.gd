class_name Run
extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload("res://scenes/battle_reward/battle_reward.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/campfire/campfire.tscn")
const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCENE = preload("res://scenes/treasure/treasure.tscn")
const RELIC_REWARD_POOL := preload("res://relics/relic_reward_pool.tres")
const POTION_REWARD_POOL := preload("res://potions/potion_reward_pool.tres")
const WIN_SCREEN_SCENE := preload("res://scenes/win_screen/win_screen.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const DEBUG_CONSOLE := preload("res://scenes/battle/battle_debug_console.gd")
const MAP_ROOM_TOOLTIP := preload("res://global/map_room_tooltip_util.gd")
const UNKNOWN_ROOM_EVENT_WEIGHT := 5.0
const UNKNOWN_ROOM_BATTLE_WEIGHT := 3.0
const UNKNOWN_ROOM_SHOP_WEIGHT := 2.0

@export var run_startup: RunStartup

@onready var map: Map = $Map
@onready var current_view: Node = $CurrentView
@onready var health_ui: HealthUI = %HealthUI
@onready var gold_ui: GoldUI = %GoldUI
@onready var relic_handler: RelicHandler = %RelicHandler
@onready var potion_handler: PotionHandler = %PotionHandler
@onready var potion_bar_ui: PotionBarUI = %PotionBarUI
@onready var game_tooltip: GameTooltip = %GameTooltip
@onready var deck_button: CardPileOpener = %DeckButton
@onready var pause_button: TextureButton = %PauseButton
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
var current_act: int = 1  ## 当前层数（1-3），用于三层游戏结构
## 失败/通关界面出现后：禁止再写入存档，退出主菜单时删除存档。
var run_finished: bool = false
## Act Boss 奖励关闭时跳过 battle_reward_exited 触发的旧地图展示。
var _skip_battle_reward_map := false
var _run_bgm_sync_serial := 0
var _load_bgm_instant_overlays := false


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
			_begin_continued_run()
	
	call_deferred("_warmup_battle_assets")
	_ensure_debug_console()


func _begin_continued_run() -> void:
	await MusicPlayer.ensure_act1_streams_ready()
	_load_run()


func _start_run() -> void:
	stats = RunStats.new()
	current_act = 1
	
	_setup_event_connections()
	_setup_top_bar()
	
	map.generate_new_map(current_act)
	
	save_data = SaveGame.new()
	save_data.sync_potion_ids_for_save(potion_handler.get_ids_for_save())
	MusicPlayer.after_run_exit_fade(_finish_start_run_bgm)


func _finish_start_run_bgm() -> void:
	if not is_inside_tree():
		return
	MusicPlayer.prepare_for_run_sync()
	await MusicPlayer.ensure_act1_streams_ready()
	_enter_act_with_intro(current_act)
	_sync_run_bgm()
	call_deferred("_warmup_battle_assets")


func mark_run_finished() -> void:
	if run_finished:
		return
	run_finished = true
	RunBgm.on_run_exit()


## 从失败/通关界面返回主菜单：删除存档并结束本局。
func abandon_finished_run_to_main_menu() -> void:
	mark_run_finished()
	SaveGame.delete_data()
	get_tree().paused = false
	MusicPlayer.stop_for_menu_transition()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _write_save_file() -> void:
	if run_finished or save_data == null:
		return
	save_data.save_data()


func _save_run(was_on_map: bool) -> void:
	if run_finished or save_data == null:
		return
	save_data.rng_seed = RNG.instance.seed
	save_data.rng_state = RNG.instance.state
	save_data.run_stats = stats
	save_data.map_data = SaveGame.duplicate_map_data(map.map_data)
	save_data.last_room = SaveGame.resolve_room_in_map_data(save_data.map_data, map.last_room)
	SaveGame.sync_saved_map_room_refs(save_data)
	SaveGame.reconcile_map_visited_flags(save_data)
	save_data.floors_climbed = map.floors_climbed
	save_data.was_on_map = was_on_map
	save_data.act_number = current_act
	
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
		# 战斗中：只同步遗物 id；药水/快照内遗物均保持「进战瞬间」，读档由 combat_snapshot 回退
		save_data.sync_relic_ids_for_save(current_relics)
		_sync_combat_snapshot_battle_ai_from_battle()
	else:
		# 正常保存：没有快照或在地图上
		if was_on_map:
			save_data.combat_snapshot = null
		save_data.char_stats = character
		save_data.current_deck = character.deck
		save_data.current_health = character.health
		save_data.current_max_health = character.max_health
		save_data.sync_relics_for_save(current_relics)
		save_data.sync_potion_ids_for_save(potion_handler.get_ids_for_save())
	
	_write_save_file()


func _load_run() -> void:
	GameContent.clear_relic_template_cache()
	save_data = SaveGame.load_data()
	assert(save_data, "无法加载上次的存档")
	_restore_rng_for_loaded_run()
	
	stats = save_data.run_stats
	character = save_data.char_stats
	character.deck = save_data.current_deck
	if save_data.current_max_health >= 0:
		character.max_health = save_data.current_max_health
	character.health = save_data.current_health
	
	## 加载当前层数（默认为1，兼容旧存档）
	current_act = save_data.act_number if save_data.act_number > 0 else 1
	
	if save_data.campfire_leave_pending:
		save_data.apply_campfire_pending_rollback_to(character)
	
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room, current_act)
	SaveGame.sync_saved_map_room_refs(save_data)
	
	if save_data.last_room and not save_data.was_on_map:
		# 不在地图上（战斗、商店、事件等房间）
		if save_data.campfire_leave_pending and save_data.last_room.type == Room.Type.CAMPFIRE:
			# 营火房间的特殊处理
			_load_relics_from_save_data()  # 加载遗物
			_load_potions_from_save_data()
			_setup_top_bar()
			_change_view(
				CAMPFIRE_SCENE,
				func(n: Node) -> void:
					var cf := n as Campfire
					cf.char_stats = character
					cf.restore_leave_pending_campfire_ui()
			)
		elif save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD:
			dismiss_modal_sub_overlays()
			
			## 回到「战斗刚结束、尚未领取任何奖励」的状态（精英/普通战/宝箱后续奖励栏均适用）
			if save_data.battle_reward_entry_staged:
				if save_data.battle_reward_pending_kind == SaveGame.BATTLE_REWARD_PENDING_RELIC:
					## 点了遗物但拾取效果未完成：回滚到点击前（含牌组/遗物栏），而非整屏奖励重置
					save_data.apply_battle_reward_pending_rollback_to(character, relic_handler, potion_handler)
				else:
					save_data.apply_battle_reward_entry_rollback_to(
						character, relic_handler, potion_handler
					)
				save_data.clear_battle_reward_pending_staging()
				stats = save_data.run_stats
				RNG.set_from_save_data(
					save_data.battle_reward_entry_pre_rng_seed,
					save_data.battle_reward_entry_pre_rng_state
				)
			elif (
				save_data.battle_reward_gold_taken
				and save_data.battle_reward_gold > 0
				and stats != null
			):
				stats.set_gold(maxi(0, stats.gold - save_data.battle_reward_gold))
				save_data.run_stats = stats
			else:
				## 旧存档：遗物领取异步中途退出
				if save_data.battle_reward_pending_kind == SaveGame.BATTLE_REWARD_PENDING_RELIC:
					save_data.apply_battle_reward_pending_rollback_to(character, relic_handler, potion_handler)
					save_data.clear_battle_reward_pending_staging()
				else:
					_load_relics_from_save_data()
				_load_potions_from_save_data()
				RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
			
			_setup_top_bar()
			_restore_battle_victory_backdrop_for_reward()
			var reward_scene := _open_battle_reward_overlay()
			reward_scene.setup_from_run(true)
			## 关闭任何子界面，确保回到奖励栏主界面
			reward_scene.restore_card_picker_if_pending()
		else:
			# 其他房间（战斗、商店、事件、宝藏等）
			if save_data.combat_snapshot != null:
				# 有战斗快照：先恢复快照，然后设置UI
				var snap := save_data.combat_snapshot
				var relic_ids := snap.relic_ids
				if relic_ids.is_empty():
					relic_ids = save_data.get_effective_relic_ids()
				if relic_ids.is_empty():
					push_warning("战斗读档：快照与存档均无 relic_ids")
				else:
					snap.relic_ids = relic_ids
				var combat_spent_ids := save_data.get_combat_spent_relic_ids()
				snap.apply_to(character, relic_handler, potion_handler)
				if relic_handler.get_all_relics().is_empty() and not relic_ids.is_empty():
					push_warning("战斗快照恢复后遗物仍为空，尝试从 save_data 恢复...")
					relic_handler.restore_relics_from_ids(
						relic_ids,
						false,
						true,
						combat_spent_ids
					)
				call_deferred("_apply_spent_relic_state_from_save")
				_setup_top_bar()  # 快照恢复后才设置UI
				_on_battle_room_entered(save_data.combat_snapshot.room, true)
			else:
				# 检查是否有场景进入快照需要恢复（商店、事件、宝藏）
				var should_apply_snapshot := (
					save_data.has_scene_entry_snapshot
					and save_data.last_room != null
					and save_data.scene_entry_room_type == save_data.last_room.type
					and _is_scene_entry_reload_room(save_data.last_room)
				)
				
				if should_apply_snapshot:
					# 应用场景进入快照，恢复到刚进入场景时的状态
					# 注意：apply_scene_entry_snapshot 已经恢复了遗物和RNG状态
					save_data.apply_scene_entry_snapshot(
						character, relic_handler, potion_handler
					)
					_reset_scene_room_reload_state()
					_setup_top_bar()
					_on_map_exited(save_data.last_room, true)
				else:
					# 没有场景快照：正常加载遗物和RNG
					_load_relics_from_save_data()
					_load_potions_from_save_data()
					_setup_top_bar()
					RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
					## 旧存档可能无 scene_entry_snapshot，仍须清掉事件/商店内未完成的选牌 pending
					_reset_scene_room_reload_state()
					_on_map_exited(save_data.last_room, true)
	else:
		# 在地图上
		_load_relics_from_save_data()
		_load_potions_from_save_data()
		_setup_top_bar()
		call_deferred("_apply_spent_relic_state_from_save")
		RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
		map.show_map()

	MusicPlayer.after_run_exit_fade(_finish_load_run_bgm)


func _finish_load_run_bgm() -> void:
	if not is_inside_tree():
		return
	MusicPlayer.prepare_for_run_sync()
	await RunBgm.sync_for_run_after_load(self)


func _sync_run_bgm() -> void:
	RunBgm.sync_for_run(self, _load_bgm_instant_overlays)
	_schedule_deferred_run_bgm_sync()


func _schedule_deferred_run_bgm_sync() -> void:
	_run_bgm_sync_serial += 1
	var serial := _run_bgm_sync_serial
	call_deferred("_deferred_sync_run_bgm", serial)


func _deferred_sync_run_bgm(serial: int) -> void:
	if serial != _run_bgm_sync_serial:
		return
	if not is_inside_tree():
		return
	RunBgm.sync_for_run(self, _load_bgm_instant_overlays)
	_load_bgm_instant_overlays = false


func dismiss_modal_sub_overlays() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var to_close: Array[Node] = []
	for node: Node in tree.root.get_children():
		if node is CanvasLayer:
			for child: Node in node.get_children():
				if (
					child is DeckPickerOverlay
					or child is HandCardPickOverlay
					or child is CardPickOverlay
					or child is CardUpgradeFlow
				):
					to_close.append(node)
					break
		elif (
			node is DeckPickerOverlay
			or node is HandCardPickOverlay
			or node is CardPickOverlay
			or node is CardUpgradeFlow
		):
			to_close.append(node)
	for node: Node in to_close:
		node.queue_free()


## 关闭遗物拾取效果可能打开的模态层（无上宝石选牌/升级、三选一等），含战斗奖励栏
func dismiss_reward_flow_overlays() -> void:
	var tree := get_tree()
	if tree == null:
		return
	dismiss_modal_sub_overlays()
	BattleReward.dismiss_all_on_tree(tree)


## 读档/保存退出回到事件、商店、宝藏「刚进房间」：关掉选牌层并丢弃未完成 pending。
func _reset_scene_room_reload_state() -> void:
	dismiss_reward_flow_overlays()
	if save_data != null:
		save_data.clear_room_pending()


func _apply_spent_relic_state_from_save() -> void:
	if save_data == null or relic_handler == null:
		return
	if save_data.combat_snapshot != null:
		relic_handler.apply_spent_relic_ids(save_data.get_combat_spent_relic_ids())
	else:
		relic_handler.apply_spent_relic_ids(save_data.get_map_spent_relic_ids())


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
		var ids := save_data.get_effective_relic_ids()
		if not ids.is_empty():
			print("从 save_data.saved_relic_ids 加载 %d 个遗物" % ids.size())
			relic_handler.restore_relics_from_ids(
				ids, false, true, save_data.get_map_spent_relic_ids()
			)
			print("加载完成，当前遗物数量: %d" % relic_handler.get_all_relics().size())
		else:
			# 存档中没有遗物（新游戏或bug），添加初始遗物
			print("存档中没有遗物，由 _setup_top_bar 添加初始遗物")
	else:
		print("有战斗快照，遗物将由 apply_to 恢复")


## 预加载战斗场景脚本与资源，减轻首次进战卡顿。
func _warmup_battle_assets() -> void:
	if not is_inside_tree():
		return
	var battle := BATTLE_SCENE.instantiate()
	battle.free()


func _change_view(scene: PackedScene, configure_before_add: Callable = Callable()) -> Node:
	Events.relic_tooltip_hover_hide.emit()
	Events.potion_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	Events.map_room_tooltip_hover_hide.emit()
	
	## 清理旧场景前先断开其信号连接
	if current_view.get_child_count() > 0:
		var old_view := current_view.get_child(0)
		## 如果是 Battle 场景，断开其信号
		if old_view is Battle:
			var old_battle := old_view as Battle
			if is_instance_valid(old_battle.enemy_handler):
				if Events.player_hand_discarded.is_connected(old_battle.enemy_handler.start_turn):
					Events.player_hand_discarded.disconnect(old_battle.enemy_handler.start_turn)
			
			if is_instance_valid(old_battle.player_handler):
				if Events.player_turn_ended.is_connected(old_battle.player_handler.end_turn):
					Events.player_turn_ended.disconnect(old_battle.player_handler.end_turn)
		
		## 须在信号/动画回调返回后再释放，不能用 free()（会触发 locked object）
		old_view.queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	if configure_before_add.is_valid():
		configure_before_add.call(new_view)
	current_view.add_child(new_view)
	map.hide_map()

	return new_view


func _show_map() -> void:
	if _skip_battle_reward_map:
		_skip_battle_reward_map = false
		return

	Events.relic_tooltip_hover_hide.emit()
	Events.potion_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	Events.map_room_tooltip_hover_hide.emit()
	BattleReward.dismiss_all_on_tree(get_tree())
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()

	map.show_map()
	map.reconcile_visited_flags()
	map.unlock_next_rooms()
	
	if save_data:
		if save_data.campfire_leave_pending:
			save_data.commit_campfire_pending_to(character)
		save_data.clear_campfire_pending_staging()
		save_data.clear_room_pending()
		save_data.clear_scene_entry_snapshot()  # 清除场景进入快照
	_save_run(true)
	_sync_run_bgm()


func _enter_act_with_intro(act: int) -> void:
	RunBgm.on_act_entered(act)
	Events.relic_tooltip_hover_hide.emit()
	Events.potion_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	Events.map_room_tooltip_hover_hide.emit()
	BattleReward.dismiss_all_on_tree(get_tree())
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()

	map.reconcile_visited_flags()
	map.unlock_floor(0)
	map.begin_act_intro(act)

	if save_data:
		if save_data.campfire_leave_pending:
			save_data.commit_campfire_pending_to(character)
		save_data.clear_campfire_pending_staging()
		save_data.clear_room_pending()
		save_data.clear_scene_entry_snapshot()
	_save_run(true)


func _setup_event_connections() -> void:
	if not Events.battle_won.is_connected(_on_battle_won):
		Events.battle_won.connect(_on_battle_won)
	if not Events.battle_reward_exited.is_connected(_show_map):
		Events.battle_reward_exited.connect(_show_map)
	if not Events.campfire_exited.is_connected(_show_map):
		Events.campfire_exited.connect(_show_map)
	if not Events.map_exited.is_connected(_on_map_exited):
		Events.map_exited.connect(_on_map_exited)
	if not Events.shop_exited.is_connected(_show_map):
		Events.shop_exited.connect(_show_map)
	if not Events.treasure_room_exited.is_connected(_on_treasure_room_exited):
		Events.treasure_room_exited.connect(_on_treasure_room_exited)
	if not Events.event_room_exited.is_connected(_show_map):
		Events.event_room_exited.connect(_show_map)
	
	if not battle_button.pressed.is_connected(_change_view.bind(BATTLE_SCENE)):
		battle_button.pressed.connect(_change_view.bind(BATTLE_SCENE))
	if not campfire_button.pressed.is_connected(_change_view.bind(CAMPFIRE_SCENE)):
		campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCENE))
	if not map_button.pressed.is_connected(_show_map):
		map_button.pressed.connect(_show_map)
	if not rewards_button.pressed.is_connected(_debug_open_battle_reward):
		rewards_button.pressed.connect(_debug_open_battle_reward)
	if not shop_button.pressed.is_connected(_change_view.bind(SHOP_SCENE)):
		shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
	if not treasure_button.pressed.is_connected(_change_view.bind(TREASURE_SCENE)):
		treasure_button.pressed.connect(_change_view.bind(TREASURE_SCENE))


func is_in_active_battle() -> bool:
	return current_view.get_child_count() > 0 and current_view.get_child(0) is Battle


func _load_potions_from_save_data() -> void:
	if save_data == null:
		return
	if save_data.combat_snapshot != null:
		return
	potion_handler.restore_from_ids(save_data.get_effective_potion_ids())


func _should_persist_potion_slots_to_save() -> bool:
	if save_data == null:
		return false
	if save_data.combat_snapshot != null and not save_data.was_on_map:
		return false
	if save_data.has_scene_entry_snapshot and not save_data.was_on_map:
		return false
	if save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD:
		return false
	return true


func _on_potion_slots_changed() -> void:
	if run_finished or save_data == null:
		return
	if _should_persist_potion_slots_to_save():
		var on_map := map != null and map.visible
		_save_run(on_map)


func _refresh_top_bar_gold() -> void:
	if gold_ui != null and stats != null:
		gold_ui.set_run_stats(stats)


func _setup_top_bar() -> void:
	var top_bar := get_node_or_null("TopBar") as CanvasLayer
	if top_bar:
		top_bar.process_mode = Node.PROCESS_MODE_ALWAYS
	if game_tooltip:
		game_tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	if not character.stats_changed.is_connected(health_ui.update_stats.bind(character)):
		character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	_refresh_top_bar_gold()
	if potion_bar_ui:
		potion_bar_ui.bind_handler(potion_handler)
		potion_bar_ui.refresh_from_handler()
	if not potion_handler.slots_changed.is_connected(_on_potion_slots_changed):
		potion_handler.slots_changed.connect(_on_potion_slots_changed)
	if not Events.potion_tooltip_hover_show.is_connected(game_tooltip.show_potion_tooltip):
		Events.potion_tooltip_hover_show.connect(game_tooltip.show_potion_tooltip)
	if not Events.potion_tooltip_hover_hide.is_connected(game_tooltip.hide_tooltip):
		Events.potion_tooltip_hover_hide.connect(game_tooltip.hide_tooltip)
	
	# 只有在没有遗物时才添加初始遗物（避免加载存档时重复添加）
	var current_relics := relic_handler.get_all_relics()
	if current_relics.is_empty():
		print("_setup_top_bar: 没有遗物，添加初始遗物: %s" % character.starting_relic.id)
		relic_handler.add_relic(character.starting_relic)
	else:
		print("_setup_top_bar: 已有 %d 个遗物，跳过初始遗物添加" % current_relics.size())
	if not Events.relic_tooltip_hover_show.is_connected(_on_run_relic_tooltip_hover_show):
		Events.relic_tooltip_hover_show.connect(_on_run_relic_tooltip_hover_show)
	if not Events.relic_tooltip_hover_hide.is_connected(game_tooltip.hide_tooltip):
		Events.relic_tooltip_hover_hide.connect(game_tooltip.hide_tooltip)
	if not Events.status_tooltip_hover_show.is_connected(_on_run_status_tooltip_hover_show):
		Events.status_tooltip_hover_show.connect(_on_run_status_tooltip_hover_show)
	if not Events.status_tooltip_hover_hide.is_connected(_on_run_status_tooltip_hover_hide):
		Events.status_tooltip_hover_hide.connect(_on_run_status_tooltip_hover_hide)
	if not Events.intent_tooltip_hover_show.is_connected(game_tooltip.show_custom_bbcode):
		Events.intent_tooltip_hover_show.connect(game_tooltip.show_custom_bbcode)
	if not Events.intent_tooltip_hover_hide.is_connected(game_tooltip.hide_tooltip):
		Events.intent_tooltip_hover_hide.connect(game_tooltip.hide_tooltip)
	if not Events.card_keyword_tooltip_show.is_connected(_on_card_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.connect(_on_card_keyword_tooltip_show)
	if not Events.card_keyword_tooltip_hide.is_connected(_on_card_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.connect(_on_card_keyword_tooltip_hide)
	if not Events.map_room_tooltip_hover_show.is_connected(_on_map_room_tooltip_hover_show):
		Events.map_room_tooltip_hover_show.connect(_on_map_room_tooltip_hover_show)
	if not Events.map_room_tooltip_hover_reposition.is_connected(_on_map_room_tooltip_hover_reposition):
		Events.map_room_tooltip_hover_reposition.connect(_on_map_room_tooltip_hover_reposition)
	if not Events.map_room_tooltip_hover_hide.is_connected(_on_map_room_tooltip_hover_hide):
		Events.map_room_tooltip_hover_hide.connect(_on_map_room_tooltip_hover_hide)
	
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


func has_event_flag(flag: String) -> bool:
	if save_data == null or flag.is_empty():
		return false
	return save_data.pending_event_flags.has(flag)


func mark_event_flag(flag: String) -> void:
	if save_data == null or flag.is_empty():
		return
	if not save_data.pending_event_flags.has(flag):
		save_data.pending_event_flags.append(flag)
	_save_run(false)


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


const SHOP_PENDING_INT_COUNT := 23


func persist_shop_pending(
	card_ids: PackedStringArray,
	relic_ids: PackedStringArray,
	potion_ids: PackedStringArray,
	card_costs: PackedInt32Array,
	relic_costs: PackedInt32Array,
	potion_costs: PackedInt32Array,
	card_sold: PackedInt32Array,
	relic_sold: PackedInt32Array,
	potion_sold: PackedInt32Array,
	remove_count: int = 0
) -> void:
	if save_data == null:
		return
	save_data.pending_room_kind = SaveGame.PENDING_SHOP
	save_data.pending_card_template_ids = card_ids
	save_data.pending_relic_ids = relic_ids
	save_data.pending_potion_ids = potion_ids
	var packed := PackedInt32Array()
	for v: int in card_costs:
		packed.append(v)
	for v: int in relic_costs:
		packed.append(v)
	for v: int in potion_costs:
		packed.append(v)
	for v: int in card_sold:
		packed.append(v)
	for v: int in relic_sold:
		packed.append(v)
	for v: int in potion_sold:
		packed.append(v)
	packed.append(remove_count)
	save_data.pending_shop_ints = packed
	_save_run(false)


func get_shop_pending_data() -> Dictionary:
	if not can_restore_shop_pending():
		return {}
	var ints := save_data.pending_shop_ints
	if ints.size() < SHOP_PENDING_INT_COUNT:
		return {"format_version": 0}
	return {
		"format_version": 2,
		"card_ids": save_data.pending_card_template_ids,
		"relic_ids": save_data.pending_relic_ids,
		"potion_ids": save_data.pending_potion_ids,
		"card_costs": ints.slice(0, 5),
		"relic_costs": ints.slice(5, 8),
		"potion_costs": ints.slice(8, 11),
		"card_sold": ints.slice(11, 16),
		"relic_sold": ints.slice(16, 19),
		"potion_sold": ints.slice(19, 22),
		"remove_count": ints[22],
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
func _is_pending_battle_reward() -> bool:
	return save_data != null and save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD


## 商店/事件/宝藏等：保存并退出时回到进入房间时的状态（与读档 apply_scene_entry_snapshot 一致）
func _persist_scene_room_quit_snapshot() -> void:
	if save_data == null:
		return
	if not save_data.has_scene_entry_snapshot:
		_reset_scene_room_reload_state()
		_save_run(map.visible if map != null else false)
		return
	save_data.apply_scene_entry_snapshot(character, relic_handler, potion_handler)
	stats = save_data.run_stats
	RNG.set_from_save_data(save_data.scene_entry_rng_seed, save_data.scene_entry_rng_state)
	_refresh_top_bar_gold()
	_reset_scene_room_reload_state()
	save_data.was_on_map = false
	save_data.char_stats = character
	save_data.current_deck = character.deck
	save_data.current_health = character.health
	save_data.current_max_health = character.max_health
	save_data.sync_relics_for_save(relic_handler.get_all_relics())
	save_data.sync_potion_ids_for_save(potion_handler.get_ids_for_save())
	if potion_bar_ui:
		potion_bar_ui.refresh_from_handler()
	save_data.run_stats = stats
	save_data.map_data = SaveGame.duplicate_map_data(map.map_data)
	save_data.floors_climbed = map.floors_climbed
	save_data.last_room = SaveGame.resolve_room_in_map_data(save_data.map_data, map.last_room)
	SaveGame.sync_saved_map_room_refs(save_data)
	SaveGame.reconcile_map_visited_flags(save_data)
	save_data.act_number = current_act
	_write_save_file()


func _reset_shop_pending_sold_flags() -> void:
	if save_data == null or save_data.pending_shop_ints.size() < SHOP_PENDING_INT_COUNT:
		return
	var ints := save_data.pending_shop_ints.duplicate()
	for i: int in range(11, 22):
		ints[i] = 0
	save_data.pending_shop_ints = ints


## 战斗奖励栏「保存并退出」：回到进入奖励栏时的状态，不保留未确认的领取
func _persist_battle_reward_quit_snapshot() -> void:
	if save_data == null:
		return
	dismiss_reward_flow_overlays()
	if save_data.battle_reward_pending_kind == SaveGame.BATTLE_REWARD_PENDING_RELIC:
		save_data.apply_battle_reward_pending_rollback_to(character, relic_handler, potion_handler)
		stats = save_data.run_stats
	elif save_data.battle_reward_entry_staged:
		save_data.apply_battle_reward_entry_rollback_to(
			character, relic_handler, potion_handler
		)
		stats = save_data.run_stats
	elif (
		save_data.battle_reward_gold_taken
		and save_data.battle_reward_gold > 0
		and stats != null
	):
		## 旧档/未 stage：至少回退已领取的金币奖励
		stats.set_gold(maxi(0, stats.gold - save_data.battle_reward_gold))
		save_data.run_stats = stats
	_refresh_top_bar_gold()
	save_data.clear_battle_reward_pending_staging()
	save_data.battle_reward_gold_taken = false
	save_data.battle_reward_cards_taken = false
	save_data.battle_reward_upgrade_taken = false
	save_data.battle_reward_potion_taken = false
	## 保留 card_offered / pending_card_template_ids，读档仍能看见选牌入口与同一批候选
	for i: int in range(save_data.battle_reward_relics_taken.size()):
		save_data.battle_reward_relics_taken[i] = 0
	save_data.pending_room_kind = SaveGame.PENDING_BATTLE_REWARD
	save_data.was_on_map = false
	save_data.rng_seed = save_data.battle_reward_entry_pre_rng_seed
	save_data.rng_state = save_data.battle_reward_entry_pre_rng_state
	RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
	save_data.char_stats = character
	save_data.current_deck = character.deck
	save_data.current_health = character.health
	save_data.current_max_health = character.max_health
	save_data.sync_relics_for_save(relic_handler.get_all_relics())
	save_data.sync_potion_ids_for_save(potion_handler.get_ids_for_save())
	save_data.run_stats = stats
	save_data.map_data = SaveGame.duplicate_map_data(map.map_data)
	save_data.floors_climbed = map.floors_climbed
	save_data.last_room = SaveGame.resolve_room_in_map_data(save_data.map_data, map.last_room)
	SaveGame.sync_saved_map_room_refs(save_data)
	SaveGame.reconcile_map_visited_flags(save_data)
	save_data.act_number = current_act
	_write_save_file()


func persist_battle_reward_full_state(
	gold: int,
	relics: Array[Relic],
	card_offered: bool = false,
	upgrade_offered: bool = false,
	potion_id: String = ""
) -> void:
	if save_data == null:
		return
	save_data.run_stats = stats
	save_data.pending_room_kind = SaveGame.PENDING_BATTLE_REWARD
	save_data.stage_battle_reward_entry_snapshot(
		character,
		relic_handler,
		RNG.instance.seed,
		RNG.instance.state,
		potion_handler
	)
	save_data.battle_reward_card_offered = card_offered
	save_data.battle_reward_upgrade_offered = upgrade_offered
	save_data.battle_reward_upgrade_taken = false
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
	save_data.battle_reward_potion_id = potion_id
	save_data.battle_reward_potion_taken = false
	save_data.rng_seed = RNG.instance.seed
	save_data.rng_state = RNG.instance.state
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


func take_battle_reward_upgrade() -> void:
	if save_data == null:
		return
	save_data.battle_reward_upgrade_taken = true
	_save_run(false)


func take_battle_reward_potion() -> void:
	if save_data == null:
		return
	save_data.battle_reward_potion_taken = true
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
		"card_offered": save_data.battle_reward_card_offered,
		"upgrade_offered": save_data.battle_reward_upgrade_offered,
		"upgrade_taken": save_data.battle_reward_upgrade_taken,
		"potion_id": save_data.battle_reward_potion_id,
		"potion_taken": save_data.battle_reward_potion_taken,
	}


func clear_room_pending_and_save() -> void:
	if save_data == null:
		return
	save_data.clear_room_pending()
	_save_run(false)


func _current_view_is_battle() -> bool:
	if current_view == null:
		return false
	for child in current_view.get_children():
		if child is Battle:
			return true
	return false


func _on_run_status_tooltip_hover_show(
	status: Status,
	near_to: Control,
	open_to_right: bool
) -> void:
	if _current_view_is_battle():
		return
	game_tooltip.show_status_tooltip(status, near_to, open_to_right)


func _on_run_status_tooltip_hover_hide() -> void:
	if _current_view_is_battle():
		return
	game_tooltip.hide_tooltip()


func _on_card_keyword_tooltip_show(ids: PackedStringArray, near_to: Control) -> void:
	## 战斗手牌 / ManaUI / 战斗牌堆由 BattleUI 内嵌 GameTooltip 处理（无颜色说明）。
	if CardKeywordBbcode.is_combat_tooltip_anchor(near_to):
		return
	## 高层模态（选牌/升级等）由各自 elevated GameTooltip 处理。
	if Events.is_pointer_ui_obscured_for(game_tooltip):
		return
	game_tooltip.show_keyword_blocks(ids, near_to)


func _on_card_keyword_tooltip_hide() -> void:
	if _current_view_is_battle():
		return
	if Events.is_pointer_ui_obscured_for(game_tooltip):
		return
	game_tooltip.hide_tooltip()


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


func _get_current_battle_view() -> Battle:
	if current_view == null or current_view.get_child_count() == 0:
		return null
	return current_view.get_child(0) as Battle


## 读档战斗奖励：恢复「刚打完、背景与玩家仍在」的定格画面（宝箱奖励仍保持宝藏房视图）。
func _restore_battle_victory_backdrop_for_reward() -> void:
	if save_data == null or save_data.last_room == null:
		return
	var room_type: Room.Type = save_data.last_room.type
	if room_type not in [Room.Type.MONSTER, Room.Type.ELITE, Room.Type.BOSS]:
		return
	var battle := _get_current_battle_view()
	if battle == null:
		battle = _change_view(
			BATTLE_SCENE,
			func(n: Node) -> void:
				var b := n as Battle
				b.char_stats = character
				b.battle_stats = save_data.last_room.battle_stats
				b.relics = relic_handler
		) as Battle
	else:
		battle.char_stats = character
		battle.battle_stats = save_data.last_room.battle_stats
		battle.relics = relic_handler
	if battle != null:
		battle.enter_post_victory_backdrop(true)


func _open_battle_reward_overlay() -> BattleReward:
	Events.relic_tooltip_hover_hide.emit()
	Events.potion_tooltip_hover_hide.emit()
	Events.status_tooltip_hover_hide.emit()
	Events.intent_tooltip_hover_hide.emit()
	Events.card_keyword_tooltip_hide.emit()
	Events.map_room_tooltip_hover_hide.emit()
	map.hide_map()
	var reward_scene := BattleReward.open_on_tree(get_tree())
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler
	reward_scene.potion_handler = potion_handler
	return reward_scene


func _debug_open_battle_reward() -> void:
	var reward_scene := _open_battle_reward_overlay()
	reward_scene.setup_from_run(false)


## 大礼包等：在当前界面叠层发放战斗奖励（卡牌/药水/遗物/升级）
func run_inline_reward_pack_flow() -> void:
	var reward_scene := _open_battle_reward_overlay()
	reward_scene.begin_inline_reward_pack()
	await reward_scene.inline_flow_finished


func _try_add_potion_reward(reward_scene: BattleReward) -> void:
	if stats == null or reward_scene == null:
		return
	## 本场为新战斗胜利生成奖励，勿沿用上一场未离开奖励屏时写入的 potion_id
	if save_data != null:
		save_data.battle_reward_potion_id = ""
	GameContent.clear_potion_template_cache()
	var potion_offered := false
	if stats.roll_battle_potion_drop():
		var potion := POTION_REWARD_POOL.roll_reward(
			potion_handler,
			save_data.act_number if save_data else 1,
			stats
		)
		if potion:
			reward_scene.add_potion_reward(potion)
			potion_offered = true
	stats.adjust_battle_potion_drop_chance_after_reward(potion_offered)


func _show_elite_battle_rewards() -> void:
	var reward_scene := _open_battle_reward_overlay()
	reward_scene.setup_from_run(false)
	
	if map.last_room != null and map.last_room.battle_stats != null:
		reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward(current_act))
	else:
		reward_scene.add_gold_reward(BattleGoldRewards.roll(current_act, 2))
	
	var relic: Relic = RELIC_REWARD_POOL.roll_reward(
		character,
		relic_handler,
		save_data.act_number if save_data else 1,
		stats
	)
	if relic:
		reward_scene.add_relic_reward(relic)
	
	_try_add_potion_reward(reward_scene)
	reward_scene.add_card_reward()
	reward_scene.add_card_upgrade_reward()
	reward_scene.save_initial_state()


func _show_regular_battle_rewards() -> void:
	var reward_scene := _open_battle_reward_overlay()
	reward_scene.setup_from_run(false)

	## 添加金币奖励（如果有战斗配置）
	if map.last_room != null and map.last_room.battle_stats != null:
		reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward(current_act))
	else:
		## 回退到默认金币奖励（控制台强制胜利时使用）
		reward_scene.add_gold_reward(BattleGoldRewards.roll(current_act, 0))
	
	_try_add_potion_reward(reward_scene)
	reward_scene.add_card_reward()
	## 所有奖励添加完成后，保存初始状态
	reward_scene.save_initial_state()


## 层BOSS奖励：给予100-150金币和必定Rare的卡牌奖励
func _show_act_boss_rewards() -> void:
	_skip_battle_reward_map = true
	var gold_reward := BattleGoldRewards.roll(current_act, 3)
	var reward_scene := _open_battle_reward_overlay()
	reward_scene.setup_from_run(false)
	reward_scene.add_gold_reward(gold_reward)
	_try_add_potion_reward(reward_scene)
	## 添加必定Rare的卡牌奖励
	reward_scene.add_rare_card_reward()
	
	## 保存初始状态，并连接退出信号以进入下一层
	reward_scene.save_initial_state()
	reward_scene.tree_exited.connect(_on_act_reward_finished, CONNECT_ONE_SHOT)


## 层BOSS奖励领取完毕后进入下一层
func _on_act_reward_finished() -> void:
	current_act += 1
	character.health = character.max_health

	## 保存当前层数到存档
	if save_data != null:
		save_data.act_number = current_act
	
	## 生成新的地图（新的一层），传递当前层数以加载对应内容池
	map.generate_new_map(current_act)

	## 重置已攀爬层数（新的一层从0开始）
	map.floors_climbed = 0

	_enter_act_with_intro(current_act)


func _ensure_room_battle_assigned(room: Room) -> void:
	if room == null or room.battle_stats != null:
		return
	var tier := MapGenerator.battle_tier_for_room(room)
	var act_pool := BattleStatsPool.get_pool_for_act(current_act)
	if act_pool == null:
		push_error("Run: battle_stats_pool 未加载，无法分配战斗")
		return
	room.battle_stats = act_pool.draw_battle_for_tier(tier)


func _restore_combat_room_battle_stats(room: Room) -> void:
	if room == null or save_data == null or save_data.combat_snapshot == null:
		return
	var snap := save_data.combat_snapshot
	if snap.battle_stats != null:
		room.battle_stats = snap.battle_stats
		return
	var snap_room := snap.room
	if snap_room != null and snap_room.battle_stats != null:
		room.battle_stats = snap_room.battle_stats


func _restore_rng_for_loaded_run() -> void:
	if save_data == null:
		return
	if (
		save_data.combat_snapshot != null
		and save_data.last_room != null
		and not save_data.was_on_map
		and save_data.pending_room_kind != SaveGame.PENDING_BATTLE_REWARD
		and not save_data.campfire_leave_pending
	):
		RNG.set_from_save_data(
			save_data.combat_snapshot.rng_seed,
			save_data.combat_snapshot.rng_state
		)
	else:
		RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)


func _on_battle_room_entered(room: Room, is_reload: bool = false) -> void:
	if is_reload:
		_restore_combat_room_battle_stats(room)
	_ensure_room_battle_assigned(room)
	if not is_reload and save_data != null:
		## 已进新战斗：若仍残留上一场战斗奖励 pending，清掉以免读档/roll 沿用旧药水
		if save_data.pending_room_kind == SaveGame.PENDING_BATTLE_REWARD:
			save_data.clear_room_pending()
	if not is_reload:
		_save_combat_snapshot(room)
	
	var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
	if not is_instance_valid(battle_scene):
		push_error("无法实例化战斗场景")
		return
	
	battle_scene.char_stats = character
	battle_scene.battle_stats = room.battle_stats
	battle_scene.relics = relic_handler
	battle_scene.skip_initial_battle_music = is_reload
	battle_scene.combat_reload = is_reload
	battle_scene.start_battle()
	if is_reload:
		_restore_combat_setup_rng()
	else:
		if save_data.combat_snapshot != null and not save_data.combat_snapshot.has_setup_rng:
			_sync_combat_snapshot_post_setup(battle_scene)
			_save_run(false)
	_sync_combat_snapshot_battle_ai_from_battle()
	if not is_reload:
		_schedule_deferred_run_bgm_sync()


func _sync_combat_snapshot_post_setup(battle: Battle) -> void:
	if save_data == null or save_data.combat_snapshot == null:
		return
	if battle == null or not is_instance_valid(battle.player_handler):
		return
	var ph := battle.player_handler
	if ph.character == null:
		return
	save_data.combat_snapshot.capture_post_setup(ph.character)


func _restore_combat_setup_rng() -> void:
	if save_data == null or save_data.combat_snapshot == null:
		return
	var snap := save_data.combat_snapshot
	if not snap.has_setup_rng:
		return
	RNG.set_from_save_data(snap.setup_rng_seed, snap.setup_rng_state)


func _sync_combat_snapshot_battle_ai_from_battle() -> void:
	if save_data == null or save_data.combat_snapshot == null:
		return
	if current_view.get_child_count() == 0:
		return
	var battle := current_view.get_child(0) as Battle
	if battle == null or not is_instance_valid(battle.enemy_handler):
		return
	var elemental_enemies: Array[Enemy] = []
	for child in battle.enemy_handler.get_children():
		if child is Enemy:
			elemental_enemies.append(child as Enemy)
	ElementalAISnapshot.write_spawn_stat_paths(elemental_enemies)
	for enemy in elemental_enemies:
		var picker := enemy.enemy_action_picker
		if picker is ShadowSamuraiAI:
			(picker as ShadowSamuraiAI).write_cycle_to_snapshot(save_data.combat_snapshot)
		elif picker is ElementalIceAI:
			(picker as ElementalIceAI).write_state_to_snapshot()
		elif picker is ElementalAlternatingRandomAI:
			(picker as ElementalAlternatingRandomAI).write_state_to_snapshot()


func _sync_combat_snapshot_shadow_samurai_from_battle() -> void:
	_sync_combat_snapshot_battle_ai_from_battle()


func _save_combat_snapshot(room: Room) -> void:
	if save_data == null:
		return
	var current_relics := relic_handler.get_all_relics()
	save_data.combat_snapshot = CombatSnapshot.create_from(
		character, current_relics, room, potion_handler
	)
	# 确保遗物 id 也被写入存档（作为后备）
	save_data.sync_relics_for_save(current_relics)
	_save_run(false)


func _clear_combat_snapshot() -> void:
	if save_data == null:
		return
	save_data.combat_snapshot = null
	_save_run(false)


func _on_treasure_room_entered(is_reload: bool = false) -> void:
	if not is_reload and RunBgm.is_row8_tense_treasure_room(self):
		RunBgm.on_row8_tense_treasure_entered()
	var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
	treasure_scene.relic_handler = relic_handler
	treasure_scene.char_stats = character
	treasure_scene.populate_from_run(is_reload)


func _on_treasure_room_exited(relic: Relic) -> void:
	RunBgm.try_unlock_tense_from_treasure(self)
	var reward_scene := _open_battle_reward_overlay()
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
	shop.potion_handler = potion_handler
	Events.shop_entered.emit(shop)
	shop.populate_shop(is_reload)


func _on_event_room_entered(room: Room, is_reload: bool = false) -> void:
	if room.event_scene == null:
		push_error("_on_event_room_entered: room.event_scene 为 null，无法进入事件房间")
		## 回退到显示地图，避免游戏卡住
		_show_map()
		return

	if is_reload:
		_reset_scene_room_reload_state()

	var event_room: Node = _change_view(room.event_scene)
	event_room.set("character_stats", character)
	event_room.set("run_stats", stats)
	if event_room.has_method("set_run_reload"):
		event_room.call("set_run_reload", is_reload)
	# 须在节点 _ready（@onready）之后执行，否则事件按钮回调未绑定会点不动。
	if event_room.has_method("setup"):
		event_room.call_deferred("setup")


func debug_enter_event(id: String) -> String:
	var t := id.strip_edges().to_lower()
	
	# 特殊选项：快速进入商店
	if t == "shop":
		_on_shop_entered(false)
		return "已进入商店"
	
	# 特殊选项：快速进入营火
	if t == "campfire":
		_on_campfire_entered()
		return "已进入营火"
	
	# 默认：加载事件场景
	var scene := _load_event_scene_by_id(id)
	if scene == null:
		return "找不到事件：%s（可用 scenes/event_rooms 下 .tscn 名或 res:// 完整路径，或特殊选项 shop/campfire）" % id
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
	
	## 检查是否是BOSS房间
	if map.last_room != null and map.last_room.type == Room.Type.BOSS:
		if current_act < 3:
			## 第1或第2层BOSS，给予奖励并进入下一层
			_show_act_boss_rewards()
		else:
			## 第3层（最终）BOSS，通关
			mark_run_finished()
			var win_screen := _change_view(WIN_SCREEN_SCENE) as WinScreen
			win_screen.character = character
	elif map.last_room != null and map.last_room.type == Room.Type.ELITE:
		_show_elite_battle_rewards()
	else:
		## 普通战斗，显示常规奖励
		_show_regular_battle_rewards()


func _should_persist_scene_room_quit() -> bool:
	if save_data == null or save_data.was_on_map:
		return false
	if save_data.combat_snapshot != null:
		return false
	if _is_pending_battle_reward():
		return false
	return save_data.has_scene_entry_snapshot


func _on_pause_save_and_quit() -> void:
	if run_finished:
		abandon_finished_run_to_main_menu()
		return
	if save_data:
		if _is_pending_battle_reward():
			_persist_battle_reward_quit_snapshot()
		elif _should_persist_scene_room_quit():
			_persist_scene_room_quit_snapshot()
		else:
			# 战斗中：保持 combat_snapshot，不覆盖为当前状态
			_save_run(map.visible)
	RunBgm.on_run_exit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_window_close_requested() -> void:
	if run_finished:
		SaveGame.delete_data()
		return
	if save_data:
		if _is_pending_battle_reward():
			_persist_battle_reward_quit_snapshot()
		elif _should_persist_scene_room_quit():
			_persist_scene_room_quit_snapshot()
		else:
			_save_run(map.visible)


func _on_run_relic_tooltip_hover_show(relic: Relic, near_to: Control) -> void:
	if map != null and map.visible:
		map.dismiss_room_tooltip_hover()
	if game_tooltip != null:
		game_tooltip.show_tooltip(relic, near_to)


func _on_map_room_tooltip_hover_show(room: Room, map_room: MapRoom) -> void:
	if game_tooltip == null or room == null or map_room == null:
		return
	var bbcode := MAP_ROOM_TOOLTIP.get_tooltip_bbcode(room)
	if bbcode.is_empty():
		return
	game_tooltip.show_titled_bbcode_at_screen_rect(
		bbcode,
		map_room.get_tooltip_screen_rect(),
		GameTooltip.Placement.ICON_RIGHT
	)


func _on_map_room_tooltip_hover_reposition(map_room: MapRoom) -> void:
	if game_tooltip == null or map_room == null:
		return
	game_tooltip.update_follow_screen_rect(map_room.get_tooltip_screen_rect())


func _on_map_room_tooltip_hover_hide() -> void:
	if game_tooltip == null:
		return
	game_tooltip.hide_tooltip()


func _is_scene_entry_reload_room(room: Room) -> bool:
	if room.type == Room.Type.TREASURE:
		return true
	if room.type == Room.Type.SHOP:
		return true
	if room.type == Room.Type.EVENT:
		return true
	if room.type == Room.Type.UNKNOWN:
		return room.unknown_resolved_type in [Room.Type.SHOP, Room.Type.EVENT]
	return false


func _resolve_unknown_room_if_needed(room: Room) -> void:
	if room == null or room.type != Room.Type.UNKNOWN:
		return
	if room.unknown_resolved_type != Room.Type.NOT_ASSIGNED:
		return
	var total := (
		UNKNOWN_ROOM_EVENT_WEIGHT
		+ UNKNOWN_ROOM_BATTLE_WEIGHT
		+ UNKNOWN_ROOM_SHOP_WEIGHT
	)
	var roll := RNG.instance.randf_range(0.0, total)
	if roll < UNKNOWN_ROOM_EVENT_WEIGHT:
		room.unknown_resolved_type = Room.Type.EVENT
		var pool := map.map_generator.event_room_pool
		if pool != null:
			room.event_scene = pool.get_random_for_act(current_act)
	elif roll < UNKNOWN_ROOM_EVENT_WEIGHT + UNKNOWN_ROOM_BATTLE_WEIGHT:
		room.unknown_resolved_type = Room.Type.MONSTER
	else:
		room.unknown_resolved_type = Room.Type.SHOP


func _on_map_exited(room: Room, is_reload: bool = false) -> void:
	if not is_reload:
		_resolve_unknown_room_if_needed(room)
	_save_run(false)
	
	# 如果不是重载（即新进入场景），保存场景进入快照
	if not is_reload:
		_save_scene_entry_snapshot(room)
	
	match room.type:
		Room.Type.MONSTER, Room.Type.ELITE:
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
		Room.Type.UNKNOWN:
			match room.unknown_resolved_type:
				Room.Type.EVENT:
					_on_event_room_entered(room, is_reload)
				Room.Type.SHOP:
					_on_shop_entered(is_reload)
				Room.Type.MONSTER:
					_on_battle_room_entered(room, is_reload)
				_:
					push_error("Run: UNKNOWN 房间未能解析，回退地图")
					_show_map()


func _save_scene_entry_snapshot(room: Room) -> void:
	"""进入场景前保存完整状态快照"""
	if save_data == null or character == null:
		return
	
	var current_relics := relic_handler.get_all_relics()
	save_data.save_scene_entry_snapshot(
		room.type,
		character,
		current_relics,
		RNG.instance.seed,
		RNG.instance.state,
		potion_handler
	)
	_save_run(false)
