class_name RatEnemyStats
extends EnemyStats

const MIN_HEALTH := 33
const MAX_HEALTH := 39
const ART_SHORT_SEQUENCE_DURATION := 1.0
const ART_LONG_SEQUENCE_DURATION := 0.5
const ART_LONG_SEQUENCE_CHANCE := 0.2


func uses_multi_sequence_art() -> bool:
	return art_frames.size() >= 5


static func art_seq_short() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 0])


## 1-3-4-5-4-3-1（贴图索引 0~4）
static func art_seq_long() -> PackedInt32Array:
	return PackedInt32Array([0, 2, 3, 4, 3, 2, 0])


static func is_long_sequence(seq: PackedInt32Array) -> bool:
	return seq.size() == 7


func pick_art_sequence(was_long_last: bool = false) -> PackedInt32Array:
	if not was_long_last and RNG.instance.randf() < ART_LONG_SEQUENCE_CHANCE:
		return art_seq_long()
	return art_seq_short()


func frame_interval_for_sequence(seq: PackedInt32Array) -> float:
	var total := ART_LONG_SEQUENCE_DURATION if is_long_sequence(seq) else ART_SHORT_SEQUENCE_DURATION
	return total / float(maxi(seq.size(), 1))


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	var rolled := RNG.instance.randi_range(MIN_HEALTH, MAX_HEALTH)
	instance.max_health = rolled
	instance.health = rolled
	return instance
