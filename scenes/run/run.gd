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
	save_data.char_stats = character
	save_data.current_deck = character.deck
	save_data.current_health = character.health
	save_data.relics = relic_handler.get_all_relics()
	save_data.last_room = map.last_room
	save_data.map_data = map.map_data.duplicate()
	save_data.floors_climbed = map.floors_climbed
	save_data.was_on_map = was_on_map
	save_data.save_data()


func _load_run() -> void:
	save_data = SaveGame.load_data()
	assert(save_data, "无法加载上次的存档")
	
	RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
	stats = save_data.run_stats
	character = save_data.char_stats
	character.deck = save_data.current_deck
	character.health = save_data.current_health
	relic_handler.add_relics(save_data.relics, false)
	if save_data.campfire_leave_pending:
		save_data.apply_campfire_pending_rollback_to(character)
	_setup_top_bar()
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room)
	if save_data.last_room and not save_data.was_on_map:
		if save_data.campfire_leave_pending and save_data.last_room.type == Room.Type.CAMPFIRE:
			_change_view(
				CAMPFIRE_SCENE,
				func(n: Node) -> void:
					var cf := n as Campfire
					cf.char_stats = character
					cf.restore_leave_pending_campfire_ui()
			)
		else:
			_on_map_exited(save_data.last_room)


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


func _setup_top_bar():
	character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	gold_ui.run_stats = stats
	
	relic_handler.add_relic(character.starting_relic)
	Events.relic_tooltip_hover_show.connect(relic_tooltip.show_tooltip)
	Events.relic_tooltip_hover_hide.connect(relic_tooltip.hide)
	Events.status_tooltip_hover_show.connect(status_hover_tooltip.show_tooltip)
	Events.status_tooltip_hover_hide.connect(status_hover_tooltip.hide)
	Events.intent_tooltip_hover_show.connect(status_hover_tooltip.show_custom_bbcode)
	Events.intent_tooltip_hover_hide.connect(status_hover_tooltip.hide)
	Events.card_keyword_tooltip_show.connect(card_keyword_tooltip.show_keyword_blocks)
	Events.card_keyword_tooltip_hide.connect(card_keyword_tooltip.hide_tooltip)
	
	deck_button.card_pile = character.deck
	deck_view.card_pile = character.deck
	deck_button.pressed.connect(deck_view.show_current_view.bind("牌库"))
	if run_card_fx:
		run_card_fx.setup(deck_button)


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


func _show_regular_battle_rewards() -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character

	reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
	reward_scene.add_card_reward()


func _on_battle_room_entered(room: Room) -> void:
	var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
	battle_scene.char_stats = character
	battle_scene.battle_stats = room.battle_stats
	battle_scene.relics = relic_handler
	battle_scene.start_battle()


func _on_treasure_room_entered() -> void:
	var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
	treasure_scene.relic_handler = relic_handler
	treasure_scene.char_stats = character
	treasure_scene.generate_relic()


func _on_treasure_room_exited(relic: Relic) -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler

	var treasure_gold := RNG.instance.randi_range(25, 50)
	reward_scene.add_gold_reward(treasure_gold)
	reward_scene.add_relic_reward(relic)


func _on_campfire_entered() -> void:
	_change_view(
		CAMPFIRE_SCENE,
		func(n: Node) -> void:
			var cf := n as Campfire
			cf.char_stats = character
			cf.begin_fresh_campfire_visit(self)
	)


func _on_shop_entered() -> void:
	var shop := _change_view(SHOP_SCENE) as Shop
	shop.char_stats = character
	shop.run_stats = stats
	shop.relic_handler = relic_handler
	Events.shop_entered.emit(shop)
	shop.populate_shop()


func _on_event_room_entered(room: Room) -> void:
	var event_room: Node = _change_view(room.event_scene)
	# 避免 `as EventRoom` 在部分环境下为 null（根节点 type=Control 时转型失败），导致对 nil 赋值 character_stats
	event_room.set("character_stats", character)
	event_room.set("run_stats", stats)
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
	if map.floors_climbed == MapGenerator.FLOORS:
		var win_screen := _change_view(WIN_SCREEN_SCENE) as WinScreen
		win_screen.character = character
		SaveGame.delete_data()
	else:
		_show_regular_battle_rewards()


func _on_pause_save_and_quit() -> void:
	if save_data:
		_save_run(map.visible)
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_window_close_requested() -> void:
	if save_data:
		_save_run(map.visible)


func _on_map_exited(room: Room) -> void:
	_save_run(false)
	
	match room.type:
		Room.Type.MONSTER:
			_on_battle_room_entered(room)
		Room.Type.TREASURE:
			_on_treasure_room_entered()
		Room.Type.CAMPFIRE:
			_on_campfire_entered()
		Room.Type.SHOP:
			_on_shop_entered()
		Room.Type.BOSS:
			_on_battle_room_entered(room)
		Room.Type.EVENT:
			_on_event_room_entered(room)
