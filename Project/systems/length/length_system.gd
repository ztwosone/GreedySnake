class_name LengthSystem
extends Node

var snake: Snake
var window_mgr: Node = null          # EffectWindowManager（T30 Lag Tail 用）
## 无身体倒计时：-1 表示未激活，>0 表示剩余 tick 数
var no_body_ticks: int = -1
## 倒计时总 tick 数（用于计算比例）
var no_body_total_ticks: int = 0
## 倒计时总时长（秒），从 config 读取，默认 10
var no_body_grace_seconds: float = 10.0
## tick 间隔缓存
var _tick_interval: float = 0.25


func _ready() -> void:
	EventBus.snake_food_eaten.connect(_on_food_eaten)
	EventBus.length_decrease_requested.connect(_on_decrease_requested)
	EventBus.snake_hit_boundary.connect(_on_death_collision)
	EventBus.snake_hit_self.connect(_on_death_collision)
	EventBus.tick_post_process.connect(_on_tick)
	EventBus.snake_length_increased.connect(_on_length_increased)

	var snake_cfg: Dictionary = ConfigManager.snake if ConfigManager else {}
	no_body_grace_seconds = float(snake_cfg.get("no_body_grace_seconds", 10.0))
	_tick_interval = ConfigManager.tick.get("base_interval", 0.25) if ConfigManager else 0.25


func get_current_length() -> int:
	if snake:
		return snake.body.size()
	return 0


func get_no_body_ticks_remaining() -> int:
	return no_body_ticks


func _on_food_eaten(_data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	var amount := 1
	snake.grow_pending += amount
	EventBus.snake_length_increased.emit({
		"amount": amount,
		"source": "food",
		"new_length": snake.body.size() + snake.grow_pending,
	})


func _on_length_increased(_data: Dictionary) -> void:
	# 长度恢复 > 1 段时取消倒计时
	if snake and snake.body.size() > 1 and no_body_ticks > 0:
		_cancel_countdown()


func _on_decrease_requested(data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	# T30 Lag Tail: 段丢失拦截
	if data.get("bypass_block") != true and window_mgr and window_mgr.get_rule("block_segment_loss", false):
		EventBus.segment_loss_deferred.emit(data)
		return
	var amount: int = data.get("amount", 1)
	var source: String = data.get("source", "unknown")
	var removed: int = 0
	for i in range(amount):
		if snake.body.size() <= 1:
			# 已经只剩蛇头，不再移除——倒计时会处理死亡
			break
		snake.remove_tail_segment()
		removed += 1

	# Emit length change if segments were removed
	if removed > 0:
		# === 掉段 VFX：浮动 "-1" + 屏幕震动 ===
		if not snake.body.is_empty():
			var tail_pos: Vector2 = GridWorld.grid_to_world(snake.body[-1])
			VFXManager.popup_text("-%d" % removed, tail_pos, Color(1.0, 0.3, 0.3))
			VFXManager.screen_shake(3.0, 0.1)
		EventBus.snake_length_decreased.emit({
			"amount": removed,
			"source": source,
			"new_length": snake.body.size(),
		})
		# 仅剩蛇头 → 启动倒计时
		if snake.is_alive and snake.body.size() <= 1 and no_body_ticks < 0:
			_start_no_body_countdown()


func _on_tick(_tick_index: int) -> void:
	if no_body_ticks <= 0:
		return
	if not snake or not snake.is_alive:
		no_body_ticks = -1
		return
	# 如果期间恢复了身体段，取消倒计时
	if snake.body.size() > 1:
		_cancel_countdown()
		return
	no_body_ticks -= 1
	# 广播倒计时进度
	var remaining_sec: float = no_body_ticks * _tick_interval
	EventBus.no_body_countdown_tick.emit({
		"remaining_seconds": remaining_sec,
		"total_seconds": no_body_grace_seconds,
		"ratio": float(no_body_ticks) / float(no_body_total_ticks) if no_body_total_ticks > 0 else 0.0,
	})
	if no_body_ticks <= 0:
		snake.die("no_body_timeout")


func _start_no_body_countdown() -> void:
	no_body_total_ticks = int(ceil(no_body_grace_seconds / _tick_interval))
	no_body_ticks = no_body_total_ticks
	EventBus.no_body_countdown_started.emit({
		"total_seconds": no_body_grace_seconds,
	})


func _cancel_countdown() -> void:
	no_body_ticks = -1
	no_body_total_ticks = 0
	EventBus.no_body_countdown_cancelled.emit()


func _on_death_collision(data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	var cause: String = "hit_boundary" if data.has("direction") else "hit_self"
	snake.die(cause)
