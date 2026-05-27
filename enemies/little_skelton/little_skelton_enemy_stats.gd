class_name LittleSkeltonEnemyStats
extends EnemyStats

const MIN_HEALTH := 11
const MAX_HEALTH := 16
const SLOT_5_FIXED_HEALTH := 19
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


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	var rolled := RNG.instance.randi_range(MIN_HEALTH, MAX_HEALTH)
	instance.max_health = rolled
	instance.health = rolled
	return instance


## 遭遇布局：5 号槽位小骷髅开战血量固定为 19（其余槽位仍 11~16 随机）。
static func apply_initial_health_for_slot(stats: EnemyStats, slot: int) -> void:
	if stats == null or slot != 5:
		return
	stats.max_health = SLOT_5_FIXED_HEALTH
	stats.health = SLOT_5_FIXED_HEALTH
