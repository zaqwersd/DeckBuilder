class_name CrabEnemyStats
extends EnemyStats

const MAX_HEALTH := 48
const ART_SEQUENCE_DURATION := 0.5


func uses_multi_sequence_art() -> bool:
	return art_frames.size() >= 3


static func art_seq_short() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 0])


static func art_seq_long() -> PackedInt32Array:
	return PackedInt32Array([0, 2, 0])


func pick_art_sequence() -> PackedInt32Array:
	if RNG.instance.randi() % 2 == 0:
		return art_seq_short()
	return art_seq_long()


func frame_interval_for_sequence(seq: PackedInt32Array) -> float:
	return ART_SEQUENCE_DURATION / float(maxi(seq.size(), 1))


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	instance.max_health = MAX_HEALTH
	instance.health = MAX_HEALTH
	return instance
