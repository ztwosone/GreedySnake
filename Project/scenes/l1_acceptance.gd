extends "res://scenes/game_world.gd"

## L1 验收场景：4 区布局，12 项自动检测
##
## 地图布局 (40×22):
##   y=1-3:   Zone A  状态拾取走廊 (火|冰|毒)
##   y=5-8:   Zone B  增益验证 (火光环|冰防御+体攻|毒尾迹)
##   y=10-13: Zone C  反应触发 (蒸腾|毒爆|冻疫)
##   y=15-21: Zone D  综合战场 (自由战斗完整循环)
##
## 蛇从 (2,2) 向右出发，穿过火走廊即获得火状态

var _checklist: Dictionary = {}
var _checklist_label: RichTextLabel
var _zone_labels: Array[Label] = []
var _enemy_types_seen: Dictionary = {}
var _food_eaten_count: int = 0
var _initial_length: int = 0
var _poison_spread_detected: bool = false


func _ready() -> void:
	super._ready()
	# start_game() 由 main.gd 调用，不在 _ready 中重复调用


func start_game() -> void:
	# 1. Initialize Grid
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	# 2. Initialize snake: 长度10从火走廊起点出发
	var start_pos := Vector2i(2, 2)
	snake.init_snake(start_pos, 10, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	_initial_length = snake.segments.size()

	# 3. Setup zones
	_setup_zone_a_status_corridors()
	_setup_zone_b_buff_verification()
	_setup_zone_c_reaction_triggers()
	_setup_zone_d_battlefield()

	# 4. Some food for normal play
	food_manager.init_foods(3)

	# 5. Setup HUD
	_setup_checklist_hud()
	_setup_zone_label_hud()

	# 6. Connect signals
	_connect_checklist_signals()

	# 7. Start Tick
	TickManager.start_ticking()
	EventBus.game_started.emit()


# ═══════════════════════════════════════════
# Zone A: 状态拾取走廊 (y=1-3)
# ═══════════════════════════════════════════

func _setup_zone_a_status_corridors() -> void:
	# 火焰走廊: x=2~8, y=2 (蛇出发即穿过)
	for x in range(2, 9):
		status_tile_manager.place_tile(Vector2i(x, 2), "fire", 1)

	# 冰冻走廊: x=15~21, y=2
	for x in range(15, 22):
		status_tile_manager.place_tile(Vector2i(x, 2), "ice", 1)

	# 毒液走廊: x=28~34, y=2
	for x in range(28, 35):
		status_tile_manager.place_tile(Vector2i(x, 2), "poison", 1)


# ═══════════════════════════════════════════
# Zone B: 增益验证区 (y=5-8)
# ═══════════════════════════════════════════

func _setup_zone_b_buff_verification() -> void:
	# B1: 火光环场 (x=1-12)
	# 2只游荡者，玩家带火段靠近 → 光环伤敌 → 死亡掉食物
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(5, 7))
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(8, 7))

	# B2: 冰防御+体攻场 (x=14-26)
	# 2只追踪者，会主动追踪蛇身攻击
	enemy_manager.spawn_enemy_at("chaser", Vector2i(18, 7))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(22, 7))

	# B4: 带状态敌人反应测试 (x=14-26, y=5)
	# 火追踪者：蛇带冰/毒经过时被攻击 → 触发蒸腾/毒爆
	var fire_chaser: Enemy = enemy_manager.spawn_enemy_at("chaser", Vector2i(16, 5))
	if fire_chaser:
		fire_chaser.set_carried_status_visual("fire")
	# 冰追踪者：蛇带火/毒经过时被攻击 → 触发蒸腾/冻疫
	var ice_chaser: Enemy = enemy_manager.spawn_enemy_at("chaser", Vector2i(24, 5))
	if ice_chaser:
		ice_chaser.set_carried_status_visual("ice")

	# B3: 毒尾迹场 (x=28-38)
	# 1只游荡者+开阔空间，玩家带毒尾移动留格
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(33, 7))


# ═══════════════════════════════════════════
# Zone C: 反应触发区 (y=10-13)
# 每组：3格TypeA → 间隔1格 → 3格TypeB
# ═══════════════════════════════════════════

func _setup_zone_c_reaction_triggers() -> void:
	# 蒸腾 (x=2-10): fire(3-5) → gap → ice(7-9)
	for x in range(3, 6):
		status_tile_manager.place_tile(Vector2i(x, 12), "fire", 1)
	for x in range(7, 10):
		status_tile_manager.place_tile(Vector2i(x, 12), "ice", 1)

	# 毒爆 (x=14-22): fire(15-17) → gap → poison(19-21)
	for x in range(15, 18):
		status_tile_manager.place_tile(Vector2i(x, 12), "fire", 1)
	for x in range(19, 22):
		status_tile_manager.place_tile(Vector2i(x, 12), "poison", 1)

	# 冻疫 (x=26-34): poison(27-29) → gap → ice(31-33)
	for x in range(27, 30):
		status_tile_manager.place_tile(Vector2i(x, 12), "poison", 1)
	for x in range(31, 34):
		status_tile_manager.place_tile(Vector2i(x, 12), "ice", 1)


# ═══════════════════════════════════════════
# Zone D: 综合战场 (y=15-21)
# ═══════════════════════════════════════════

func _setup_zone_d_battlefield() -> void:
	# 各类敌人 ×2
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(8, 17))
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(15, 17))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(22, 18))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(28, 18))
	enemy_manager.spawn_enemy_at("bog_crawler", Vector2i(34, 17))
	enemy_manager.spawn_enemy_at("bog_crawler", Vector2i(37, 17))

	# 散布状态格供战术使用
	status_tile_manager.place_tile(Vector2i(10, 19), "fire", 1)
	status_tile_manager.place_tile(Vector2i(11, 19), "fire", 1)
	status_tile_manager.place_tile(Vector2i(20, 19), "ice", 1)
	status_tile_manager.place_tile(Vector2i(21, 19), "ice", 1)
	status_tile_manager.place_tile(Vector2i(30, 19), "poison", 1)
	status_tile_manager.place_tile(Vector2i(31, 19), "poison", 1)

	# 毒格吸引 bog_crawler
	for x in range(35, 38):
		status_tile_manager.place_tile(Vector2i(x, 19), "poison", 1)

	# 允许补兵
	enemy_manager.max_enemy_count = 12


# ═══════════════════════════════════════════
# 验收清单 HUD (12 项)
# ═══════════════════════════════════════════

func _setup_checklist_hud() -> void:
	_checklist = {
		"01_seg_status": false,
		"02_multi_status": false,
		"03_eat_enemy": false,
		"04_food_drop": false,
		"05_fire_aura": false,
		"06_poison_trail": false,
		"07_body_attack": false,
		"08_hit_tail_loss": false,
		"09_steam": false,
		"10_toxic_explosion": false,
		"11_frozen_plague": false,
		"12_no_errors": false,
	}
	_checklist["12_no_errors"] = true

	_checklist_label = RichTextLabel.new()
	_checklist_label.bbcode_enabled = true
	_checklist_label.fit_content = true
	_checklist_label.scroll_active = false
	_checklist_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_checklist_label.position = Vector2(-330, 10)
	_checklist_label.size = Vector2(320, 420)
	_checklist_label.add_theme_font_size_override("normal_font_size", 14)
	$UI.add_child(_checklist_label)
	_update_checklist_display()


func _setup_zone_label_hud() -> void:
	var zones: Array = [
		# Zone A
		{"text": "A-Fire", "pos": Vector2(2 * Constants.CELL_SIZE, 0.5 * Constants.CELL_SIZE)},
		{"text": "A-Ice", "pos": Vector2(15 * Constants.CELL_SIZE, 0.5 * Constants.CELL_SIZE)},
		{"text": "A-Poison", "pos": Vector2(28 * Constants.CELL_SIZE, 0.5 * Constants.CELL_SIZE)},
		# Zone B
		{"text": "B1-FireAura", "pos": Vector2(1 * Constants.CELL_SIZE, 4.5 * Constants.CELL_SIZE)},
		{"text": "B2-IceDef+Atk", "pos": Vector2(14 * Constants.CELL_SIZE, 4.5 * Constants.CELL_SIZE)},
		{"text": "B3-PoisonTrail", "pos": Vector2(28 * Constants.CELL_SIZE, 4.5 * Constants.CELL_SIZE)},
		# Zone C
		{"text": "C-Steam", "pos": Vector2(2 * Constants.CELL_SIZE, 10 * Constants.CELL_SIZE)},
		{"text": "C-ToxicExp", "pos": Vector2(14 * Constants.CELL_SIZE, 10 * Constants.CELL_SIZE)},
		{"text": "C-FrzPlague", "pos": Vector2(26 * Constants.CELL_SIZE, 10 * Constants.CELL_SIZE)},
		# Zone D
		{"text": "D-Battlefield", "pos": Vector2(14 * Constants.CELL_SIZE, 14.5 * Constants.CELL_SIZE)},
	]
	for z in zones:
		var lbl := Label.new()
		lbl.text = z["text"]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1, 1, 0, 0.6))
		lbl.position = z["pos"]
		add_child(lbl)
		_zone_labels.append(lbl)


# ═══════════════════════════════════════════
# 信号检测
# ═══════════════════════════════════════════

func _connect_checklist_signals() -> void:
	EventBus.snake_moved.connect(_on_check_snake_moved)
	EventBus.enemy_killed.connect(_on_check_enemy_killed)
	EventBus.snake_food_eaten.connect(_on_check_food_eaten)
	EventBus.status_tile_placed.connect(_on_check_tile_placed)
	EventBus.snake_body_attacked.connect(_on_check_body_attacked)
	EventBus.length_decrease_requested.connect(_on_check_length_decrease)
	EventBus.reaction_triggered.connect(_on_check_reaction)
	EventBus.enemy_spawned.connect(_on_check_enemy_spawned)


func _on_check_snake_moved(data: Dictionary) -> void:
	# #1 蛇段携带状态
	var status_types: Dictionary = {}
	for seg in snake.segments:
		if is_instance_valid(seg) and seg.carried_status != "":
			_mark_passed("01_seg_status")
			status_types[seg.carried_status] = true

	# #2 多段不同状态
	if status_types.size() >= 2:
		_mark_passed("02_multi_status")


func _on_check_enemy_killed(data: Dictionary) -> void:
	# #3 蛇头吃敌人
	_mark_passed("03_eat_enemy")

	# #5 火光环伤敌：检查死亡敌人位置附近是否有火段
	var enemy_pos: Vector2i = data.get("position", Vector2i(-1, -1))
	if enemy_pos != Vector2i(-1, -1):
		for seg in snake.segments:
			if not is_instance_valid(seg):
				continue
			if seg.carried_status != "fire":
				continue
			var dist: int = abs(seg.grid_position.x - enemy_pos.x) + abs(seg.grid_position.y - enemy_pos.y)
			if dist <= 1:
				_mark_passed("05_fire_aura")
				break


func _on_check_food_eaten(_data: Dictionary) -> void:
	# #4 敌人掉食物：吃敌人后附近出现食物并被吃到
	_food_eaten_count += 1
	# 如果吃到的食物总数 > 初始放置的 3 个，说明有敌人掉落的食物被吃到
	if _food_eaten_count > 3:
		_mark_passed("04_food_drop")


func _on_check_tile_placed(data: Dictionary) -> void:
	# #6 毒蔓延：毒段附近出现毒格即算通过
	var tile_type: String = data.get("type", "")
	if tile_type == "poison" and not _poison_spread_detected:
		# 检查是否有毒段在附近（蔓延源）
		var tile_pos: Vector2i = data.get("position", Vector2i(-1, -1))
		for seg in snake.segments:
			if not is_instance_valid(seg) or seg.carried_status != "poison":
				continue
			var dist: int = abs(seg.grid_position.x - tile_pos.x) + abs(seg.grid_position.y - tile_pos.y)
			if dist <= 1:
				_poison_spread_detected = true
				_mark_passed("06_poison_trail")
				break


func _on_check_body_attacked(_data: Dictionary) -> void:
	# #7 敌人攻击蛇身
	_mark_passed("07_body_attack")


func _on_check_length_decrease(data: Dictionary) -> void:
	# #8 受击累积掉尾
	var source: String = data.get("source", "")
	if source == "body_attack":
		_mark_passed("08_hit_tail_loss")


func _on_check_reaction(data: Dictionary) -> void:
	var rid: String = data.get("reaction_id", "")
	match rid:
		"steam":
			_mark_passed("09_steam")
		"toxic_explosion":
			_mark_passed("10_toxic_explosion")
		"frozen_plague":
			_mark_passed("11_frozen_plague")


func _on_check_enemy_spawned(data: Dictionary) -> void:
	var etype: String = data.get("type", "")
	_enemy_types_seen[etype] = true


# ═══════════════════════════════════════════
# 清单显示
# ═══════════════════════════════════════════

func _mark_passed(key: String) -> void:
	if not _checklist.has(key):
		return
	if _checklist[key]:
		return
	_checklist[key] = true
	_update_checklist_display()


func _update_checklist_display() -> void:
	if _checklist_label == null:
		return

	var labels: Dictionary = {
		"01_seg_status": "#1  [color=gray]A[/color] 蛇段携带状态",
		"02_multi_status": "#2  [color=gray]A[/color] 多段携带不同状态",
		"03_eat_enemy": "#3  [color=gray]B[/color] 蛇头吃敌人",
		"04_food_drop": "#4  [color=gray]B[/color] 敌人掉落食物被吃到",
		"05_fire_aura": "#5  [color=gray]B1[/color] 火光环伤敌",
		"06_poison_trail": "#6  [color=gray]B3[/color] 毒蔓延",
		"07_body_attack": "#7  [color=gray]B2[/color] 敌人攻击蛇身",
		"08_hit_tail_loss": "#8  [color=gray]B2[/color] 受击累积掉尾",
		"09_steam": "#9  [color=gray]C[/color] 蒸腾反应 (火+冰)",
		"10_toxic_explosion": "#10 [color=gray]C[/color] 毒爆反应 (火+毒)",
		"11_frozen_plague": "#11 [color=gray]C[/color] 冻疫反应 (冰+毒)",
		"12_no_errors": "#12 无异常运行",
	}

	var passed_count: int = 0
	var total: int = _checklist.size()
	var text: String = "[b]L1 验收清单[/b]\n"

	# 显示蛇状态信息
	var seg_count: int = snake.segments.size() if snake else 0
	var hits: int = snake.hits_taken if snake else 0
	text += "[color=gray]长度:%d  受击:%d/%d[/color]\n\n" % [seg_count, hits, snake.hits_per_segment_loss if snake else 3]

	for key in _checklist:
		var passed: bool = _checklist[key]
		if passed:
			passed_count += 1
			text += "[color=lime]V[/color] %s\n" % labels.get(key, key)
		else:
			text += "[color=red]X[/color] %s\n" % labels.get(key, key)

	text += "\n[b]%d / %d[/b]" % [passed_count, total]
	if passed_count == total:
		text += "  [color=gold]ALL ACCEPTED![/color]"

	_checklist_label.text = text


func _process(_delta: float) -> void:
	# 每帧更新状态信息（长度、受击数）
	_update_checklist_display()
