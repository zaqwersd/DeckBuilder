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
	
	## 设置战斗背景图（优先使用配置的，其次使用层默认）
	_setup_background()
	
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.relics = relics
	_combat_started = false
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	_combat_started = true
	
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)


## 设置战斗背景图
func _setup_background() -> void:
	var bg_sprite := $Background as Sprite2D
	if bg_sprite == null:
		return
	
	## 优先使用战斗配置的背景图
	if battle_stats and battle_stats.background_texture:
		bg_sprite.texture = battle_stats.background_texture
		_setup_background_modulate()
		return
	
	## 其次使用层默认背景图
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		var act_bg := _get_default_background_for_act(run.current_act)
		if act_bg != null:
			bg_sprite.texture = act_bg
			_setup_background_modulate()


## 设置背景图色调（第1层调暗并偏蓝绿色）
func _setup_background_modulate() -> void:
	var bg_sprite := $Background as Sprite2D
	if bg_sprite == null:
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	
	match run.current_act:
		1:
			## 第1层：调暗并偏向蓝绿色调
			bg_sprite.modulate = Color(0.5, 0.7, 0.75, 1)
		2:
			## 第2层：正常亮度
			bg_sprite.modulate = Color(1, 1, 1, 1)
		3:
			## 第3层：正常亮度
			bg_sprite.modulate = Color(1, 1, 1, 1)
		_:
			bg_sprite.modulate = Color(1, 1, 1, 1)


## 获取对应层的默认背景图
func _get_default_background_for_act(act: int) -> Texture2D:
	match act:
		1:
			## 第1层使用专属背景图
			return preload("res://art/act1_background.png")
		2:
			## 第2层使用默认背景图
			return preload("res://art/background.png")
		3:
			## 第3层使用专属背景图
			return preload("res://art/act3_background.png")
	return preload("res://art/background.png")


## 控制台指令用：强制触发战斗胜利
func debug_force_win() -> void:
	if Events.is_combat_ended():
		return
	
	## 清除所有敌人
	for enemy in enemy_handler.get_children():
		if enemy is Enemy:
			enemy.queue_free()
	
	## 标记战斗结束并触发胜利
	Events.mark_combat_ended()
	
	## 激活战斗结束时的遗物效果
	if is_instance_valid(relics):
		relics.activate_relics_by_type(Relic.Type.END_OF_COMBAT)
	
	## 发射战斗胜利信号（Run._on_battle_won会处理后续）
	Events.battle_won.emit()


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
