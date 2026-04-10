extends "res://scenes/game_world.gd"

## L2 验收场景：双阶段 Build 验证，14 项自动检测
##
## 地图布局 (40×22):
##   y=1-4:   Zone A — 装备验证区（走入即触发 equip 检测）
##   y=6-10:  Zone B — 击杀区（3 wanderers + 状态格）
##   y=12-16: Zone C — 防御区（4 chasers，会攻击蛇身）
##   y=18-21: Zone D — 恢复区（高压力敌人，触发段丢失/窗口）
##
## Phase 1: 攻击型 Build (hydra + salamander + flame_scale + thorn_scale)
##   → 修改器: hit_threshold -1, fire_aura_damage +1
##   → 共鸣: flame_thorn (fire + physical)
##
## Phase 2: 防御型 Build (bai_she + lag_tail + frost_scale + retaliation_scale)
##   → 修改器: attack_cooldown_bonus +2
##   → 共鸣: ice_spike (ice + physical)
##
## 按 N 键从 Phase 1 切换到 Phase 2（单向）

var _checklist: Dictionary = {}
var _checklist_label: RichTextLabel
var _zone_labels: Array[Label] = []
var _current_phase: int = 1

# Phase 1 tracking
var _p1_enemy_killed: bool = false
var _p1_length_grew: bool = false

# Phase 2 tracking
var _body_attacked_recently: bool = false
var _body_attacked_clear_timer: float = 0.0

# Manager shortcut references (created by super._ready)
var _snake_parts_mgr: Node
var _scale_slot_mgr: Node
var _resonance_mgr: Node


func _ready() -> void:
	super._ready()
	# start_game() called by main.gd


func start_game() -> void:
	# 1. Initialize Grid
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	# 2. Initialize snake: length 10, start in Zone A
	var start_pos := Vector2i(2, 2)
	snake.init_snake(start_pos, 10, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

	# 3. Obtain manager references (created in super._ready)
	_snake_parts_mgr = get_node("SnakePartsManager")
	_scale_slot_mgr = get_node("ScaleSlotManager")
	_resonance_mgr = get_node("ResonanceManager")

	# 4. Setup zones
	_setup_zone_a()
	_setup_zone_b()
	_setup_zone_c()
	_setup_zone_d()

	# 5. Some food for normal play
	food_manager.init_foods(3)

	# 6. Setup HUD
	_setup_checklist_hud()
	_setup_zone_label_hud()

	# 7. Connect checklist signals
	_connect_checklist_signals()

	# 8. Auto-equip Phase 1 build
	_auto_equip_phase_1()

	# 9. Start Tick
	TickManager.start_ticking()
	EventBus.game_started.emit()


# ═══════════════════════════════════════════
# Phase Management
# ═══════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# N key switches Phase 1 → Phase 2 (one-way)
	if event.keycode == KEY_N and _current_phase == 1:
		_switch_to_phase_2()


func _auto_equip_phase_1() -> void:
	_snake_parts_mgr.equip_head("hydra", 1)
	_snake_parts_mgr.equip_tail("salamander", 1)
	_scale_slot_mgr.equip_scale("middle", "flame_scale", 1)
	_scale_slot_mgr.equip_scale("back", "thorn_scale", 1)


func _switch_to_phase_2() -> void:
	_current_phase = 2

	# 1. Clear Phase 1 equipment (dependency order)
	_resonance_mgr.clear_all()
	_scale_slot_mgr.clear_all()
	_snake_parts_mgr.unequip_head()
	_snake_parts_mgr.unequip_tail()

	# 2. Verify cleanup correctness → mark #14
	var ht: float = StatusEffectManager.get_modifier("hit_threshold", snake, 0.0)
	var fad: float = StatusEffectManager.get_modifier("fire_aura_damage", snake, 0.0)
	if abs(ht) < 0.01 and abs(fad) < 0.01:
		_mark_passed("14_cleanup")

	# 3. Equip Phase 2 build
	_snake_parts_mgr.equip_head("bai_she", 1)
	_snake_parts_mgr.equip_tail("lag_tail", 1)
	_scale_slot_mgr.equip_scale("middle", "frost_scale", 1)
	_scale_slot_mgr.equip_scale("back", "retaliation_scale", 1)

	# 4. Spawn extra enemies for Phase 2 combat
	_spawn_phase_2_enemies()

	_update_checklist_display()


func _spawn_phase_2_enemies() -> void:
	# Additional enemies for Phase 2 testing
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(10, 8))
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(20, 8))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(12, 14))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(22, 14))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(10, 20))
	enemy_manager.spawn_enemy_at("bog_crawler", Vector2i(30, 20))


# ═══════════════════════════════════════════
# Zone A: 装备验证区 (y=1-4)
# ═══════════════════════════════════════════

func _setup_zone_a() -> void:
	# Fire tiles for steal_status testing
	for x in range(5, 11):
		status_tile_manager.place_tile(Vector2i(x, 2), "fire", 1)


# ═══════════════════════════════════════════
# Zone B: 击杀区 (y=6-10)
# ═══════════════════════════════════════════

func _setup_zone_b() -> void:
	# 3 wanderers (easy kills)
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(8, 8))
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(16, 8))
	enemy_manager.spawn_enemy_at("wanderer", Vector2i(24, 8))

	# Status tiles near each wanderer
	for x in range(7, 10):
		status_tile_manager.place_tile(Vector2i(x, 7), "fire", 1)
	for x in range(15, 18):
		status_tile_manager.place_tile(Vector2i(x, 7), "ice", 1)
	for x in range(23, 26):
		status_tile_manager.place_tile(Vector2i(x, 7), "poison", 1)


# ═══════════════════════════════════════════
# Zone C: 防御区 (y=12-16)
# ═══════════════════════════════════════════

func _setup_zone_c() -> void:
	# 4 chasers that will pursue and attack
	enemy_manager.spawn_enemy_at("chaser", Vector2i(10, 14))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(18, 14))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(26, 14))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(34, 14))


# ═══════════════════════════════════════════
# Zone D: 恢复区 (y=18-21)
# ═══════════════════════════════════════════

func _setup_zone_d() -> void:
	# High-pressure enemies
	enemy_manager.spawn_enemy_at("chaser", Vector2i(8, 20))
	enemy_manager.spawn_enemy_at("chaser", Vector2i(16, 20))
	enemy_manager.spawn_enemy_at("bog_crawler", Vector2i(28, 20))
	enemy_manager.spawn_enemy_at("bog_crawler", Vector2i(35, 20))

	# Status tiles for tactical use
	status_tile_manager.place_tile(Vector2i(12, 19), "fire", 1)
	status_tile_manager.place_tile(Vector2i(13, 19), "fire", 1)
	status_tile_manager.place_tile(Vector2i(24, 19), "poison", 1)
	status_tile_manager.place_tile(Vector2i(25, 19), "poison", 1)

	enemy_manager.max_enemy_count = 15


# ═══════════════════════════════════════════
# 验收清单 HUD (14 项)
# ═══════════════════════════════════════════

func _setup_checklist_hud() -> void:
	_checklist = {
		# Phase 1 — 攻击型 Build
		"01_head_equip": false,
		"02_scale_equip": false,
		"03_resonance_1": false,
		"04_modifier": false,
		"05_kill_grow": false,
		"06_body_hit": false,
		"07_recovery_win": false,
		"08_win_expire": false,
		# Phase 2 — 防御型 Build
		"09_baish_win": false,
		"10_lag_win": false,
		"11_frost_mod": false,
		"12_resonance_2": false,
		"13_retaliate": false,
		"14_cleanup": false,
	}

	_checklist_label = RichTextLabel.new()
	_checklist_label.bbcode_enabled = true
	_checklist_label.fit_content = true
	_checklist_label.scroll_active = false
	_checklist_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_checklist_label.position = Vector2(-340, 10)
	_checklist_label.size = Vector2(330, 540)
	_checklist_label.add_theme_font_size_override("normal_font_size", 13)
	$UI.add_child(_checklist_label)
	_update_checklist_display()


func _setup_zone_label_hud() -> void:
	var zones: Array = [
		{"text": "A-Equip", "pos": Vector2(2 * Constants.CELL_SIZE, 0.3 * Constants.CELL_SIZE)},
		{"text": "B-Kill", "pos": Vector2(5 * Constants.CELL_SIZE, 5.3 * Constants.CELL_SIZE)},
		{"text": "C-Defense", "pos": Vector2(14 * Constants.CELL_SIZE, 11.3 * Constants.CELL_SIZE)},
		{"text": "D-Recovery", "pos": Vector2(14 * Constants.CELL_SIZE, 17.3 * Constants.CELL_SIZE)},
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
	EventBus.snake_head_equipped.connect(_on_check_head_equipped)
	EventBus.snake_scale_equipped.connect(_on_check_scale_equipped)
	EventBus.resonance_activated.connect(_on_check_resonance)
	EventBus.enemy_killed.connect(_on_check_enemy_killed)
	EventBus.snake_body_attacked.connect(_on_check_body_attacked)
	EventBus.window_opened.connect(_on_check_window_opened)
	EventBus.window_expired.connect(_on_check_window_expired)
	EventBus.snake_length_increased.connect(_on_check_length_increased)


## #1 蛇头已装备
func _on_check_head_equipped(_data: Dictionary) -> void:
	_mark_passed("01_head_equip")


## #2 鳞片已装备 (需要 ≥2 片)
var _scale_equip_count: int = 0

func _on_check_scale_equipped(_data: Dictionary) -> void:
	_scale_equip_count += 1
	if _scale_equip_count >= 2:
		_mark_passed("02_scale_equip")


## #3 / #12 共鸣激活
func _on_check_resonance(data: Dictionary) -> void:
	var res_id: String = data.get("resonance_id", "")
	if res_id == "flame_thorn":
		_mark_passed("03_resonance_1")
	elif res_id == "ice_spike":
		_mark_passed("12_resonance_2")


## #5 击杀直接增长 — 需要 enemy_killed + length_increased 都发生
func _on_check_enemy_killed(_data: Dictionary) -> void:
	if _current_phase == 1:
		_p1_enemy_killed = true
		if _p1_length_grew:
			_mark_passed("05_kill_grow")

	# #13 反噬击杀: Phase 2 中受击后短时间内敌人死亡
	if _current_phase == 2 and _body_attacked_recently:
		_mark_passed("13_retaliate")


## #6 受击检测
func _on_check_body_attacked(_data: Dictionary) -> void:
	_mark_passed("06_body_hit")
	_body_attacked_recently = true
	_body_attacked_clear_timer = 2.0


## #7 / #9 / #10 窗口开启
func _on_check_window_opened(data: Dictionary) -> void:
	var wid: String = data.get("window_id", "")
	match wid:
		"salamander_recovery":
			_mark_passed("07_recovery_win")
		"bai_she_invincible":
			if _current_phase == 2:
				_mark_passed("09_baish_win")
		"lag_tail_delay":
			if _current_phase == 2:
				_mark_passed("10_lag_win")


## #8 窗口到期（salamander recovery 过期 = on_expire 触发 direct_grow）
func _on_check_window_expired(data: Dictionary) -> void:
	var wid: String = data.get("window_id", "")
	if wid == "salamander_recovery":
		_mark_passed("08_win_expire")


## #5 长度增长
func _on_check_length_increased(_data: Dictionary) -> void:
	if _current_phase == 1:
		_p1_length_grew = true
		if _p1_enemy_killed:
			_mark_passed("05_kill_grow")


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
		"01_head_equip":  "#1  [color=gray]A[/color]  蛇头已装备",
		"02_scale_equip": "#2  [color=gray]A[/color]  鳞片已装备 (x2)",
		"03_resonance_1": "#3  [color=gray]A[/color]  炎棘共鸣激活",
		"04_modifier":    "#4  [color=gray]A[/color]  修改器生效",
		"05_kill_grow":   "#5  [color=gray]B[/color]  击杀直接增长",
		"06_body_hit":    "#6  [color=gray]C[/color]  受击检测",
		"07_recovery_win":"#7  [color=gray]D[/color]  恢复窗口开启",
		"08_win_expire":  "#8  [color=gray]D[/color]  窗口到期恢复",
		"09_baish_win":   "#9  [color=gray]P2[/color] 白蛇无敌窗口",
		"10_lag_win":     "#10 [color=gray]P2[/color] 时滞延迟窗口",
		"11_frost_mod":   "#11 [color=gray]P2[/color] 冰霜修改器",
		"12_resonance_2": "#12 [color=gray]P2[/color] 冰刺共鸣激活",
		"13_retaliate":   "#13 [color=gray]P2[/color] 反噬击杀",
		"14_cleanup":     "#14 [color=gray]N[/color]  清空正确性",
	}

	var passed_count: int = 0
	var total: int = _checklist.size()
	var phase_color: String = "yellow" if _current_phase == 1 else "cyan"
	var phase_name: String = "攻击型" if _current_phase == 1 else "防御型"
	var text: String = "[b]L2 验收清单[/b]  [color=%s]Phase %d %s[/color]\n" % [phase_color, _current_phase, phase_name]

	# Snake status
	var seg_count: int = snake.segments.size() if snake else 0
	var hits: int = snake.hits_taken if snake else 0
	text += "[color=gray]长度:%d  受击:%d[/color]\n" % [seg_count, hits]
	if _current_phase == 1:
		text += "[color=gray]按 N → Phase 2[/color]\n"
	text += "\n"

	# Phase 1 items
	text += "[color=yellow][b]Phase 1 攻击型[/b][/color]\n"
	for key in ["01_head_equip", "02_scale_equip", "03_resonance_1", "04_modifier",
				 "05_kill_grow", "06_body_hit", "07_recovery_win", "08_win_expire"]:
		var passed: bool = _checklist[key]
		if passed:
			passed_count += 1
			text += "  [color=lime]V[/color] %s\n" % labels[key]
		else:
			text += "  [color=red]X[/color] %s\n" % labels[key]

	text += "\n[color=cyan][b]Phase 2 防御型[/b][/color]\n"
	for key in ["09_baish_win", "10_lag_win", "11_frost_mod", "12_resonance_2",
				 "13_retaliate", "14_cleanup"]:
		var passed: bool = _checklist[key]
		if passed:
			passed_count += 1
			text += "  [color=lime]V[/color] %s\n" % labels[key]
		else:
			text += "  [color=red]X[/color] %s\n" % labels[key]

	text += "\n[b]%d / %d[/b]" % [passed_count, total]
	if passed_count == total:
		text += "  [color=gold]ALL ACCEPTED![/color]"

	_checklist_label.text = text


func _process(delta: float) -> void:
	# #4 Modifier check (Phase 1: hit_threshold from hydra)
	if _current_phase == 1 and not _checklist.get("04_modifier", false):
		var ht: float = StatusEffectManager.get_modifier("hit_threshold", snake, 0.0)
		if abs(ht) > 0.01:
			_mark_passed("04_modifier")

	# #11 Frost modifier check (Phase 2: attack_cooldown_bonus from frost_scale)
	if _current_phase == 2 and not _checklist.get("11_frost_mod", false):
		var acb: float = StatusEffectManager.get_modifier("attack_cooldown_bonus", snake, 0.0)
		if abs(acb) > 0.01:
			_mark_passed("11_frost_mod")

	# Clear body_attacked flag after timeout
	if _body_attacked_recently:
		_body_attacked_clear_timer -= delta
		if _body_attacked_clear_timer <= 0.0:
			_body_attacked_recently = false

	_update_checklist_display()
