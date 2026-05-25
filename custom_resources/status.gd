class_name Status
extends Resource

signal status_applied(status: Status)
signal status_changed

enum Type {START_OF_TURN, END_OF_TURN, EVENT_BASED}
enum StackType {NONE, INTENSITY, DURATION}
## 正面：层数/数值越高越有利（仅负值标红）。负面：越高越不利（正值标红）。
enum Polarity {POSITIVE, NEGATIVE}

@export_group("Status Data")
@export var id: String
@export var type: Type
@export var stack_type: StackType
@export var polarity: Polarity = Polarity.POSITIVE
@export var can_expire: bool
@export var duration: int : set = set_duration
@export var stacks: int : set = set_stacks

@export_group("Status Visuals")
@export var icon: Texture
## 中文显示名；悬停说明标题等用。留空则回退为 id 下划线转空格
@export var name: String = ""
@export_multiline var tooltip: String

## 敌人回合挂上：状态栏先显示图标，等持有者下一回合开始再 `initialize_status` 生效。
var awaits_turn_start: bool = false
## 激活当回合跳过首次 START_OF_TURN 扣 duration，使 duration=1 覆盖完整玩家回合。
var skip_next_start_of_turn_tick: bool = false


func get_display_name() -> String:
	var n := name.strip_edges()
	if not n.is_empty():
		return n
	return id.replace("_", " ")


func initialize_status(_target: Node) -> void:
	pass


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func get_tooltip() -> String:
	return tooltip


## 该角标数字是否对持有者不利（UI 标红、tooltip 红字）。
func counter_shows_as_harmful(value: int) -> bool:
	match polarity:
		Polarity.NEGATIVE:
			return value > 0
		_:
			return value < 0


func format_counter_for_tooltip(n: int) -> String:
	return format_tooltip_integer(n, polarity)


## 状态说明里嵌入的整数；按极性决定何时标红。
static func format_tooltip_integer(n: int, pol: Polarity = Polarity.POSITIVE) -> String:
	var harmful := false
	match pol:
		Polarity.NEGATIVE:
			harmful = n > 0
		_:
			harmful = n < 0
	if harmful:
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, n]
	return str(n)


func set_duration(new_duration: int) -> void:
	duration = new_duration
	status_changed.emit()


func set_stacks(new_stacks: int) -> void:
	stacks = new_stacks
	status_changed.emit()
