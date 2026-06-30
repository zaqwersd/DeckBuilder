class_name ActIntroOverlay
extends CanvasLayer

const ACT_NUMBERS := ["第一幕", "第二幕", "第三幕"]
const ACT_NAMES := ["河谷", "山脉", "神殿"]

const FADE_IN_DURATION := 0.5
const HOLD_DURATION := 1.0
const FADE_OUT_DURATION := 0.5
const CURTAIN_TOTAL_DURATION := FADE_IN_DURATION + HOLD_DURATION + FADE_OUT_DURATION
const CURTAIN_HALF_DURATION := CURTAIN_TOTAL_DURATION * 0.5

signal play_finished

@onready var _curtain_bar: ColorRect = %CurtainBar
@onready var _act_number_label: Label = %ActNumberLabel
@onready var _act_name_label: Label = %ActNameLabel


func _ready() -> void:
	layer = 5
	hide()
	_curtain_bar.modulate.a = 0.0


func play(act: int) -> void:
	var index := clampi(act - 1, 0, ACT_NUMBERS.size() - 1)
	_act_number_label.text = ACT_NUMBERS[index]
	_act_name_label.text = ACT_NAMES[index]
	_curtain_bar.modulate.a = 0.0
	show()

	var tween := create_tween()
	tween.tween_property(_curtain_bar, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(_curtain_bar, "modulate:a", 0.0, FADE_OUT_DURATION)
	await tween.finished
	hide()
	play_finished.emit()
