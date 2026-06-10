extends Node
## 轻量级测试框架
## 用法: Godot --headless --path Project res://test/test_runner.tscn

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""
var _test_suites: Array[GDScript] = []
var _discovered_count: int = 0
var _ran_count: int = 0


func _ready() -> void:
	_discover_tests()
	_run_after_scene_ready.call_deferred()


func _run_after_scene_ready() -> void:
	await get_tree().process_frame
	await _run_all()
	_disconnect_transient_event_bus_callbacks()
	_print_summary()
	await _flush_pending_cleanup()
	get_tree().quit(0 if _fail_count == 0 else 1)


func _flush_pending_cleanup() -> void:
	for _i in range(3):
		await get_tree().process_frame


func _disconnect_transient_event_bus_callbacks() -> void:
	for signal_info in EventBus.get_signal_list():
		var signal_name: StringName = signal_info.get("name", "")
		for connection in EventBus.get_signal_connection_list(signal_name):
			var callback: Callable = connection.get("callable")
			if not callback.is_null() and EventBus.is_connected(signal_name, callback):
				EventBus.disconnect(signal_name, callback)


func _discover_tests() -> void:
	var dir := DirAccess.open("res://test/cases/")
	if not dir:
		printerr("[TestRunner] Cannot open test/cases/ directory")
		get_tree().quit(1)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			_discovered_count += 1
			var path := "res://test/cases/" + file_name
			var script = load(path)
			if script is GDScript:
				_test_suites.append(script)
			else:
				_fail_count += 1
				printerr("  FAIL: suite failed to load: %s" % path)
		file_name = dir.get_next()
	_test_suites.sort_custom(func(a: GDScript, b: GDScript) -> bool:
		return a.resource_path < b.resource_path
	)


func _run_all() -> void:
	print("\n========== GreedySnake QA Test Runner ==========\n")
	for script in _test_suites:
		# 解析失败的脚本 load() 仍返回 GDScript；new() 会炸并中断后续全部套件，
		# 历史上曾因此出现"假绿"（summary ALL PASSED 但大半套件没跑）
		if not script.can_instantiate():
			_fail_count += 1
			printerr("  FAIL: broken suite (parse/compile error): %s" % script.resource_path)
			continue
		var instance = script.new()
		if not instance.has_method("run"):
			_fail_count += 1
			printerr("  FAIL: %s missing run() method" % script.resource_path)
			continue
		_current_suite = script.resource_path.get_file().trim_suffix(".gd")
		print("--- %s ---" % _current_suite)
		await instance.run(self)
		_ran_count += 1
		if instance is Node:
			instance.queue_free()
		print("")
	if _ran_count != _discovered_count:
		_fail_count += 1
		printerr("  FAIL: suite count mismatch - discovered %d, ran %d" % [_discovered_count, _ran_count])


func assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % description)
	else:
		_fail_count += 1
		printerr("  FAIL: %s" % description)


func assert_false(condition: bool, description: String) -> void:
	assert_true(not condition, description)


func assert_eq(actual: Variant, expected: Variant, description: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % description)
	else:
		_fail_count += 1
		printerr("  FAIL: %s (expected: %s, got: %s)" % [description, expected, actual])


func assert_has_signal(obj: Object, signal_name: String) -> void:
	var has_it := obj.has_signal(signal_name)
	if has_it:
		_pass_count += 1
		print("  PASS: signal '%s' exists" % signal_name)
	else:
		_fail_count += 1
		printerr("  FAIL: signal '%s' NOT found" % signal_name)


func assert_file_exists(path: String) -> void:
	var exists := FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	if exists:
		_pass_count += 1
		print("  PASS: '%s' exists" % path)
	else:
		_fail_count += 1
		printerr("  FAIL: '%s' NOT found" % path)


func assert_dir_exists(path: String) -> void:
	var exists := DirAccess.dir_exists_absolute(path)
	if exists:
		_pass_count += 1
		print("  PASS: dir '%s' exists" % path)
	else:
		_fail_count += 1
		printerr("  FAIL: dir '%s' NOT found" % path)


func _print_summary() -> void:
	var total := _pass_count + _fail_count
	print("=================================================")
	print("suites: %d discovered / %d ran" % [_discovered_count, _ran_count])
	if _fail_count == 0:
		print("ALL PASSED: %d/%d tests" % [_pass_count, total])
	else:
		printerr("FAILED: %d passed, %d failed, %d total" % [_pass_count, _fail_count, total])
	print("=================================================\n")
