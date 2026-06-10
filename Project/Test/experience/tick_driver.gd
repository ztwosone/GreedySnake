extends RefCounted
## 模态感知步进器（SpecKit 004 T008，设计文档 presentation_design.md §11.4 仪表缝 / §12.1）
## begin()/end() 包住 TickManager 手动步进；play() 在"无待决模态"时步拍，
## 有模态时把回合交给 ui_actor；任何无法推进的情况记 failure（套件可取），不崩溃。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。

var _failures: Array = []


func begin() -> void:
	## game_world.start_game() 可能已用自动 timer 启动 tick：先 stop 干净，
	## 否则 manual 模式下旧 timer 仍会自走拍（start_ticking 在 manual 下不碰 timer）
	_failures.clear()
	TickManager.stop_ticking()
	TickManager.manual_mode = true
	TickManager.start_ticking()


func play(n_ticks: int, recorder: RefCounted, ui_actor: RefCounted) -> int:
	## 设计 §12.1 主循环：pending 空 → step_once（false 即 failure）；
	## pending 非空 → ui_actor.respond（false 即 failure）；每个动作后等一帧。
	## 返回实际推进的 tick 数。
	var advanced: int = 0
	# 行动预算：防 playbook 与游戏状态错位时死循环（每 tick 留 4 次模态响应 + 余量）
	var budget: int = n_ticks * 4 + 16
	while advanced < n_ticks:
		budget -= 1
		if budget < 0:
			_fail("action budget exhausted at %d/%d ticks" % [advanced, n_ticks])
			break
		var pending: Array = recorder.pending_modals()
		if pending.is_empty():
			if not TickManager.step_once():
				_fail("step_once returned false (paused/stopped) at %d/%d ticks" % [advanced, n_ticks])
				break
			advanced += 1
		else:
			if ui_actor == null:
				_fail("pending modal without ui_actor: %s" % _pending_names(pending))
				break
			var resolved: bool = await ui_actor.respond(pending)
			if not resolved:
				_fail("ui_actor failed to resolve pending modals: %s" % _pending_names(pending))
				break
		await TickManager.get_tree().process_frame
	return advanced


func end() -> void:
	TickManager.manual_mode = false
	TickManager.stop_ticking()


func get_failures() -> Array:
	return _failures.duplicate()


func has_failures() -> bool:
	return not _failures.is_empty()


func _fail(message: String) -> void:
	_failures.append(message)


func _pending_names(pending: Array) -> String:
	var names: Array = []
	for entry in pending:
		names.append(str(entry.get("name", "?")))
	return str(names)
