extends Node
## 虚拟玩家编排器
## 连接感知、大脑、时序、注入四层
## 确定性模式：tick_pre_process 注入
## 人类模式：_process 累积延迟后注入

const PerceptionScript: GDScript = preload("res://Test/virtual_player/game_perception.gd")
const InjectorScript: GDScript = preload("res://Test/virtual_player/input_injector.gd")

var brain: RefCounted = null  # PlayerBrain
var timing: RefCounted = preload("res://Test/virtual_player/human_timing.gd").new()
var enabled: bool = true
var snake: Node = null  # 需要外部设置，用于 headless fallback 和 snapshot

var _decision_accumulator: float = 0.0
var _pending_direction: Vector2i = Vector2i.ZERO
var _reaction_timer: float = 0.0
var _has_pending_decision: bool = false


func _ready() -> void:
	if timing.deterministic:
		EventBus.tick_pre_process.connect(_on_tick_pre_process)


func _on_tick_pre_process(_tick_index: int) -> void:
	if not enabled or brain == null:
		return
	if snake and not snake.is_alive:
		return

	var snapshot: Dictionary = _take_snapshot()
	var decision: Dictionary = brain.decide(snapshot)
	var dir: Vector2i = decision.get("direction", Vector2i.ZERO)
	if dir != Vector2i.ZERO:
		InjectorScript.inject_direction(dir, snake)


func _process(delta: float) -> void:
	if timing.deterministic:
		return
	if not enabled or brain == null:
		return
	if snake and not snake.is_alive:
		return

	# 处理待执行的延迟输入
	if _has_pending_decision:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			InjectorScript.inject_direction(_pending_direction, snake)
			_has_pending_decision = false

	# 决策间隔累积
	_decision_accumulator += delta
	if timing.should_decide_this_frame(_decision_accumulator):
		_decision_accumulator = 0.0
		var snapshot: Dictionary = _take_snapshot()
		var decision: Dictionary = brain.decide(snapshot)
		var dir: Vector2i = decision.get("direction", Vector2i.ZERO)
		if dir != Vector2i.ZERO:
			_pending_direction = dir
			_reaction_timer = timing.get_reaction_delay_sec()
			_has_pending_decision = true


func _take_snapshot() -> Dictionary:
	if snake:
		return PerceptionScript.take_snapshot(snake)
	return {}
