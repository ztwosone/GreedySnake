extends Node

var base_tick_interval: float = Constants.BASE_TICK_INTERVAL
var tick_speed_modifier: float = 1.0
var is_ticking: bool = false
var current_tick: int = 0

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func start_ticking() -> void:
	current_tick = 0
	is_ticking = true
	_timer.wait_time = get_effective_interval()
	_timer.start()


func stop_ticking() -> void:
	is_ticking = false
	_timer.stop()


func pause() -> void:
	is_ticking = false
	_timer.paused = true


func resume() -> void:
	is_ticking = true
	_timer.paused = false


func get_effective_interval() -> float:
	return base_tick_interval / tick_speed_modifier


func _on_timer_timeout() -> void:
	if not is_ticking:
		return
	EventBus.tick_pre_process.emit(current_tick)
	EventBus.tick_input_collected.emit(current_tick)
	EventBus.tick_post_process.emit(current_tick)
	current_tick += 1
