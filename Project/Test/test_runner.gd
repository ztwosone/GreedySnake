extends Node
## 轻量级测试框架
## 用法: Godot --headless --path Project res://test/test_runner.tscn

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""
var _test_suites: Array[GDScript] = []


func _ready() -> void:
	_discover_tests()
	_run_all()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


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
			var path := "res://test/cases/" + file_name
			var script = load(path)
			if script is GDScript:
				_test_suites.append(script)
			else:
				printerr("[TestRunner] Failed to load: %s" % path)
		file_name = dir.get_next()
	_test_suites.sort_custom(func(a: GDScript, b: GDScript) -> bool:
		return a.resource_path < b.resource_path
	)


func _run_all() -> void:
	print("\n========== GreedySnake QA Test Runner ==========\n")
	for script in _test_suites:
		var instance = script.new()
		if not instance.has_method("run"):
			printerr("[TestRunner] %s missing run() method, skipped" % script.resource_path)
			continue
		_current_suite = script.resource_path.get_file().trim_suffix(".gd")
		print("--- %s ---" % _current_suite)
		instance.run(self)
		if instance is Node:
			instance.queue_free()
		print("")


func assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % description)
	else:
		_fail_count += 1
		printerr("  FAIL: %s" % description)


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
	if _fail_count == 0:
		print("ALL PASSED: %d/%d tests" % [_pass_count, total])
	else:
		printerr("FAILED: %d passed, %d failed, %d total" % [_pass_count, _fail_count, total])
	print("=================================================\n")
