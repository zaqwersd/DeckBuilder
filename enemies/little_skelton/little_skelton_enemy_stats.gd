class_name LittleSkeltonEnemyStats
extends EnemyStats

const MIN_HEALTH_DEFAULT := 11
const MAX_HEALTH_DEFAULT := 16
const MIN_SPAWNED_HEALTH := 1
const SPAWN_HEALTH_DELTA_MIN := 5
const SPAWN_HEALTH_DELTA_MAX := 7

const SLOT_2_MIN_HEALTH := 11
const SLOT_2_MAX_HEALTH := 16
const SLOT_3_MIN_HEALTH := 14
const SLOT_3_MAX_HEALTH := 17
const SLOT_4_HEALTH := 18
const SLOT_5_HEALTH := 19

## 两套循环动画总时长（秒）
const ART_SEQUENCE_DURATION := 0.5
## 长套 1-3-4-5-1 的抽取概率（且不与上一套连续重复长套）
const ART_LONG_SEQUENCE_CHANCE := 0.1


func uses_multi_sequence_art() -> bool:
	return art_frames.size() >= 5


static func art_seq_short() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 0])


static func art_seq_long() -> PackedInt32Array:
	return PackedInt32Array([0, 2, 3, 4, 0])


static func is_long_sequence(seq: PackedInt32Array) -> bool:
	return seq.size() == 5


func pick_art_sequence(was_long_last: bool = false) -> PackedInt32Array:
	if not was_long_last and RNG.instance.randf() < ART_LONG_SEQUENCE_CHANCE:
		return art_seq_long()
	return art_seq_short()


func frame_interval_for_sequence(seq: PackedInt32Array) -> float:
	return ART_SEQUENCE_DURATION / float(maxi(seq.size(), 1))


func setup_battle_visual(enemy: Node) -> void:
	if enemy is Enemy:
		(enemy as Enemy).apply_fixed_hitbox_from_art_frames(art_frames)


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	var rolled := RNG.instance.randi_range(MIN_HEALTH_DEFAULT, MAX_HEALTH_DEFAULT)
	instance.max_health = rolled
	instance.health = rolled
	return instance


## 遭遇布局：按槽位设定开战血量（2:11~16，3:14~17，4:18，5:19）。
static func apply_initial_health_for_slot(stats: EnemyStats, slot: int) -> void:
	if stats == null:
		return
	var hp := _roll_initial_health_for_slot(slot)
	if stats is Stats:
		(stats as Stats).initialize_health(hp)


## 骨生召唤：比召唤者 max_health 少 5~7，下限 1。
static func apply_spawned_health_from_summoner(stats: EnemyStats, summoner: Enemy) -> void:
	if stats == null or summoner == null or not is_instance_valid(summoner.stats):
		return
	var delta := RNG.instance.randi_range(SPAWN_HEALTH_DELTA_MIN, SPAWN_HEALTH_DELTA_MAX)
	var hp := maxi(MIN_SPAWNED_HEALTH, summoner.stats.max_health - delta)
	if stats is Stats:
		(stats as Stats).initialize_health(hp)


static func _roll_initial_health_for_slot(slot: int) -> int:
	match slot:
		2:
			return RNG.instance.randi_range(SLOT_2_MIN_HEALTH, SLOT_2_MAX_HEALTH)
		3:
			return RNG.instance.randi_range(SLOT_3_MIN_HEALTH, SLOT_3_MAX_HEALTH)
		4:
			return SLOT_4_HEALTH
		5:
			return SLOT_5_HEALTH
		_:
			return RNG.instance.randi_range(MIN_HEALTH_DEFAULT, MAX_HEALTH_DEFAULT)
