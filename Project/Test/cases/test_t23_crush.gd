extends RefCounted
## T23 测试：蛇身碾压系统


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/combat/crush_system.gd")

	# --- CrushSystem 基本检查 ---
	var cs := CrushSystem.new()
	t.assert_true(cs.has_method("_on_snake_moved"), "has _on_snake_moved")
	t.assert_true(cs.has_method("_execute_crush"), "has _execute_crush")

	# --- EventBus 信号 ---
	t.assert_true(EventBus.has_signal("snake_body_crush"), "EventBus has snake_body_crush signal")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)

	var snake := Snake.new()
	Engine.get_main_loop().root.add_child(snake)
	snake.init_snake(Vector2i(10, 10), 6, Vector2i(1, 0))
	# snake body: [10,10], [9,10], [8,10], [7,10], [6,10], [5,10]

	cs.snake = snake

	# === 基本碾压：蛇身段位置有敌人 ===
	var enemy := Enemy.new()
	enemy.setup_from_config("wanderer")
	enemy.place_on_grid(Vector2i(8, 10))  # 与 body[2] 重叠
	# 断开 tick 防干扰
	if enemy._tick_connected:
		EventBus.tick_post_process.disconnect(enemy._on_tick_post_process)
		enemy._tick_connected = false

	var crush_fired: Array = []
	var crush_cb := func(data: Dictionary) -> void:
		crush_fired.append(data)
	EventBus.snake_body_crush.connect(crush_cb)

	var decrease_fired: Array = []
	var dec_cb := func(data: Dictionary) -> void:
		decrease_fired.append(data)
	EventBus.length_decrease_requested.connect(dec_cb)

	# 模拟蛇移动后调用
	cs._on_snake_moved({})

	t.assert_eq(crush_fired.size(), 1, "crush: signal fired once")
	if crush_fired.size() > 0:
		t.assert_eq(crush_fired[0].get("segment_index"), 2, "crush: segment_index == 2")
		t.assert_eq(crush_fired[0].get("cost"), 1, "crush: cost == 1")
	t.assert_eq(decrease_fired.size(), 1, "crush: length_decrease_requested fired")
	if decrease_fired.size() > 0:
		t.assert_eq(decrease_fired[0].get("source"), "crush", "crush: source == crush")
		t.assert_eq(decrease_fired[0].get("amount"), 1, "crush: decrease amount == 1")

	# 敌人应该被击杀（hp=1 - 1 = 0）
	t.assert_true(not is_instance_valid(enemy) or enemy.hp <= 0, "crush: enemy killed (hp=1)")

	EventBus.snake_body_crush.disconnect(crush_cb)
	EventBus.length_decrease_requested.disconnect(dec_cb)

	# === 蛇头不触发碾压 ===
	crush_fired.clear()
	decrease_fired.clear()
	EventBus.snake_body_crush.connect(crush_cb)
	EventBus.length_decrease_requested.connect(dec_cb)

	var enemy_head := Enemy.new()
	enemy_head.setup_from_config("wanderer")
	enemy_head.place_on_grid(Vector2i(10, 10))  # 蛇头位置 body[0]
	if enemy_head._tick_connected:
		EventBus.tick_post_process.disconnect(enemy_head._on_tick_post_process)
		enemy_head._tick_connected = false

	cs._on_snake_moved({})
	t.assert_eq(crush_fired.size(), 0, "head: no crush on snake head position")

	enemy_head.remove_from_grid()
	EventBus.snake_body_crush.disconnect(crush_cb)
	EventBus.length_decrease_requested.disconnect(dec_cb)

	# === 同一 tick 同一敌人不被重复碾压 ===
	# 创建 hp=2 的 bog_crawler 在两段蛇身重叠处（实际同一格只会有一个身体段，
	# 但测试逻辑：创建一个敌人在某位置，蛇身有段在该位置）
	crush_fired.clear()
	decrease_fired.clear()
	EventBus.snake_body_crush.connect(crush_cb)
	EventBus.length_decrease_requested.connect(dec_cb)

	var enemy_hp2 := Enemy.new()
	enemy_hp2.setup_from_config("bog_crawler")  # hp=2
	enemy_hp2.place_on_grid(Vector2i(7, 10))  # body[3]
	if enemy_hp2._tick_connected:
		EventBus.tick_post_process.disconnect(enemy_hp2._on_tick_post_process)
		enemy_hp2._tick_connected = false

	cs._on_snake_moved({})
	t.assert_eq(crush_fired.size(), 1, "dedup: only 1 crush per enemy per tick")
	t.assert_eq(enemy_hp2.hp, 1, "dedup: enemy took 1 damage (not 2)")

	enemy_hp2.remove_from_grid()
	EventBus.snake_body_crush.disconnect(crush_cb)
	EventBus.length_decrease_requested.disconnect(dec_cb)

	# === 多个敌人在不同蛇身段 → 多次碾压 ===
	crush_fired.clear()
	decrease_fired.clear()
	EventBus.snake_body_crush.connect(crush_cb)
	EventBus.length_decrease_requested.connect(dec_cb)

	var e_a := Enemy.new()
	e_a.setup_from_config("wanderer")
	e_a.place_on_grid(Vector2i(9, 10))  # body[1]
	if e_a._tick_connected:
		EventBus.tick_post_process.disconnect(e_a._on_tick_post_process)
		e_a._tick_connected = false

	var e_b := Enemy.new()
	e_b.setup_from_config("wanderer")
	e_b.place_on_grid(Vector2i(6, 10))  # body[4]
	if e_b._tick_connected:
		EventBus.tick_post_process.disconnect(e_b._on_tick_post_process)
		e_b._tick_connected = false

	cs._on_snake_moved({})
	t.assert_eq(crush_fired.size(), 2, "multi: 2 crushes for 2 enemies")
	t.assert_eq(decrease_fired.size(), 2, "multi: 2 length decreases")

	EventBus.snake_body_crush.disconnect(crush_cb)
	EventBus.length_decrease_requested.disconnect(dec_cb)

	# === 碾压时状态转移 ===
	crush_fired.clear()
	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if sem:
		var status_applied_fired: Array = []
		var sa_cb := func(data: Dictionary) -> void:
			status_applied_fired.append(data)
		EventBus.status_applied.connect(sa_cb)
		EventBus.snake_body_crush.connect(crush_cb)

		# 给蛇施加火焰状态
		sem.apply_status(snake, "fire", "test")

		var e_status := Enemy.new()
		e_status.setup_from_config("bog_crawler")  # hp=2, 不会立即死
		e_status.place_on_grid(Vector2i(5, 10))  # body[5] (tail)
		if e_status._tick_connected:
			EventBus.tick_post_process.disconnect(e_status._on_tick_post_process)
			e_status._tick_connected = false

		status_applied_fired.clear()
		cs._on_snake_moved({})

		# 应该有火焰状态转移给敌人
		var enemy_fire_applied := false
		for sa in status_applied_fired:
			if sa.get("target") == e_status and sa.get("type") == "fire":
				enemy_fire_applied = true
		t.assert_true(enemy_fire_applied, "status transfer: fire applied to enemy on crush")

		if crush_fired.size() > 0:
			var transferred: Array = crush_fired[0].get("status_transferred", [])
			t.assert_true("fire" in transferred, "status transfer: fire in status_transferred list")

		# 清理
		sem.remove_all_statuses(snake)
		e_status.remove_from_grid()
		EventBus.status_applied.disconnect(sa_cb)
		EventBus.snake_body_crush.disconnect(crush_cb)

	# === 蛇不活着时不碾压 ===
	crush_fired.clear()
	EventBus.snake_body_crush.connect(crush_cb)
	snake.is_alive = false
	var e_dead := Enemy.new()
	e_dead.setup_from_config("wanderer")
	e_dead.place_on_grid(Vector2i(8, 10))
	if e_dead._tick_connected:
		EventBus.tick_post_process.disconnect(e_dead._on_tick_post_process)
		e_dead._tick_connected = false

	cs._on_snake_moved({})
	t.assert_eq(crush_fired.size(), 0, "dead snake: no crush")

	e_dead.remove_from_grid()
	snake.is_alive = true
	EventBus.snake_body_crush.disconnect(crush_cb)

	# === 清理 ===
	cs.queue_free()
	snake._clear_segments()
	snake.queue_free()
	GridWorld.clear_all()
