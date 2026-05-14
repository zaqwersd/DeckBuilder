class_name Status
extends Resource

signal status_applied(status: Status)
signal status_changed

enum Type {START_OF_TURN, END_OF_TURN, EVENT_BASED}
enum StackType {NONE, INTENSITY, DURATION}

@export_group("Status Data")
@export var id: String
@export var type: Type
@export var stack_type: StackType
@export var can_expire: bool
@export var duration: int : set = set_duration
@export var stacks: int : set = set_stacks

@export_group("Status Visuals")
@export var icon: Texture
## 中文显示名；悬停说明标题等用。留空则回退为 id 下划线转空格
@export var name: String = ""
@export_multiline var tooltip: String


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


## 状态说明里嵌入的整数（层数、回合等）；为负时用红色 BBCode，供 RichTextLabel 使用。
static func format_tooltip_integer(n: int) -> String:
	if n < 0:
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, n]
	return str(n)


func set_duration(new_duration: int) -> void:
	duration = new_duration
	status_changed.emit()


func set_stacks(new_stacks: int) -> void:
	stacks = new_stacks
	status_changed.emit()
