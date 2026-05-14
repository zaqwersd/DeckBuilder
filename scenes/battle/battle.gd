class_name Battle
extends Node2D

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
@export var music: AudioStream
@export var relics: RelicHandler

@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler
@onready var enemy_handler: EnemyHandler = $EnemyHandler
@onready var player: Player = $Player

## 已为 `start_battle()` 布置过敌人；用于忽略换波时短暂的 `enemy_handler` 空子节点，避免误判战斗胜利。
var _combat_started: bool = false


func _ready() -> void:
	Events.reset_combat_flow()
	_combat_started = false
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(enemy_handler.start_turn)
	Events.player_died.connect(_on_player_died)


func start_battle() -> void:
	get_tree().paused = false
	MusicPlayer.play(music, true)
	
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.relics = relics
	_combat_started = false
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	_combat_started = true
	
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)


## 调试控制台：替换当前战斗的敌人布局（BattleStats），不重置牌库与遗物。
func debug_replace_battle(new_stats: BattleStats) -> void:
	if new_stats == null:
		return
	battle_stats = new_stats
	_combat_started = false
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	_combat_started = true


func _on_enemies_child_order_changed() -> void:
	if not _combat_started:
		return
	# 只有在玩家存活且战斗未结束时，才判定胜利
	if Events.is_combat_ended():
		return
	if not is_instance_valid(player) or not is_instance_valid(player.stats):
		return
	if player.stats.health <= 0:
		return
	if enemy_handler.get_child_count() == 0 and is_instance_valid(relics):
		Events.mark_combat_ended()
		relics.activate_relics_by_type(Relic.Type.END_OF_COMBAT)


func _on_enemy_turn_ended() -> void:
	# 敌人自爆等会在本帧 queue_free，须等一帧再数子节点；场上已无时不应再抽牌/进入玩家回合
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not is_instance_valid(enemy_handler) or enemy_handler.get_child_count() == 0:
		return
	if not is_instance_valid(player_handler):
		return
	## 须先判断 player 是否仍有效：若已 queue_free，`is_instance_valid(player) and health<=0` 会因短路不进入 return，会误开玩家回合。
	if not is_instance_valid(player) or not is_instance_valid(player.stats):
		return
	if player.stats.health <= 0:
		return
	if Events.is_combat_ended():
		return
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()


func _on_player_died() -> void:
	Events.mark_combat_ended()
	Events.battle_over_screen_requested.emit("游戏结束！", BattleOverPanel.Type.LOSE)
	SaveGame.delete_data()


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_COMBAT:
			player_handler.start_battle_prep(char_stats)
			battle_ui.initialize_card_pile_ui()
			player_handler.start_turn()
		Relic.Type.END_OF_COMBAT:
			Events.battle_over_screen_requested.emit("胜利！", BattleOverPanel.Type.WIN)
