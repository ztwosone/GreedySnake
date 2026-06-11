extends Control
## CeremonyLayer——仪式编排宿主（SpecKit 004 Phase P T102 骨架 + T103 终局仪式）
## 设计: Designs/Interactive/presentation_design.md §7（屏幕流仪式）/§8.3（选择仪式）/
## §11.3（kit 零编排红线的解除处：pause/dim/stagger/飞行编排全部从这里外部驱动）。
## T103：play_end_ceremony——死亡 = hitstop → 蛇尾到头逐段消散 → 世界去饱和（§13 无
## shader，灰罩近似）→ dim → 死因中文一行 → on_finished；胜利 = 金色扩散环 → dim →
## on_finished。game_feel.enabled=false 整体旁路。选择仪式归 T104。
## 数值唯一来源 = presentation.ceremony（FR-001）；本层只听不驱动游戏状态（FR-002）。

const _KitPanelScript := preload("res://ui/kit/kit_panel.gd")

var _dim_rect: ColorRect
var _desat_rect: ColorRect
var _cause_label: Label
var _tracked_tweens: Array = []
## §8.3 选择仪式：本层是否持有 &"ceremony" 停拍 token（只解自己加的锁——
## FR-014 自动决议无 presented 时绝不幻影 resume）
var _choice_paused: bool = false


func _init() -> void:
	name = "CeremonyLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# §11.5 验收钩子：dim 层入 ui_dim 组 + ui_layer 元数据（几何探针层矩阵豁免）
	add_to_group("ui_dim")
	set_meta("ui_layer", "dim")


func _ready() -> void:
	theme = _KitPanelScript._get_shared_theme()

	# §7 世界去饱和近似罩（设计 §13：shader 不在本阶段范围）——中性灰压饱和观感
	_desat_rect = ColorRect.new()
	_desat_rect.name = "DesatRect"
	_desat_rect.color = ConfigManager.get_palette_color("text_dim")
	_desat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desat_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desat_rect.modulate.a = 0.0
	_desat_rect.visible = false
	add_child(_desat_rect)

	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.color = ConfigManager.get_palette_color("bg_deep")
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.modulate.a = 0.0
	_dim_rect.visible = false
	add_child(_dim_rect)

	# §7 死因中文一行（display 级居中，危险红）
	_cause_label = Label.new()
	_cause_label.name = "CauseLabel"
	_cause_label.theme_type_variation = "DisplayLabel"
	_cause_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("accent_danger"))
	_cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cause_label.set_anchors_preset(PRESET_CENTER)
	_cause_label.visible = false
	add_child(_cause_label)

	# 新局开始即清残留（重开局/T-Y 验收捷径都经 game_started）
	EventBus.game_started.connect(reset)
	# §8.1（T104a）：房间意图两段式——进房横幅展开，room_banner_sec 后收缩为 chip
	EventBus.room_entered.connect(_on_room_entered)
	# §8.3（T104b）：选择仪式——三模态 offer 共用（shop 非模态不参与，FR-015 对偶）
	EventBus.reward_presented.connect(_on_choice_presented)
	EventBus.scale_reward_presented.connect(_on_choice_presented)
	EventBus.floor_reward_presented.connect(_on_choice_presented)
	EventBus.reward_chosen.connect(_on_choice_resolved)
	EventBus.scale_reward_chosen.connect(_on_choice_resolved)
	EventBus.scale_option_discarded.connect(_on_choice_resolved)
	EventBus.floor_reward_chosen.connect(_on_choice_resolved)


## §7 终局仪式入口（main._on_game_over 委派；on_finished = 显示总结屏）。
## game_feel.enabled=false 直达 on_finished（宪法：重特效可禁用）。
func play_end_ceremony(data: Dictionary, on_finished: Callable) -> void:
	reset()
	if not bool(ConfigManager.get_game_feel().get("enabled", true)):
		on_finished.call()
		return
	if str(data.get("cause", "")) == "victory":
		_play_victory(on_finished)
	else:
		_play_death(str(data.get("cause", "unknown")), on_finished)


## 死亡仪式：hitstop → 逐段消散（尾→头）→ 去饱和 → dim → 死因一行 → 总结
func _play_death(cause: String, on_finished: Callable) -> void:
	var cfg: Dictionary = ConfigManager.get_ceremony_config()
	VFXManager.hit_stop(float(cfg.get("death_hitstop_sec", 0.0)))

	var tw: Tween = _track(create_tween())
	# ① 蛇尾到头逐段消散（蛇不在场——壳层测试/布景——跳过该段）
	var per_seg: float = float(cfg.get("dissolve_per_segment_sec", 0.0))
	var snake: Node = get_tree().get_first_node_in_group("snake")
	if snake != null and "segments" in snake:
		var segs: Array = snake.segments
		for i in range(segs.size() - 1, -1, -1):
			var seg = segs[i]
			if is_instance_valid(seg):
				tw.tween_property(seg, "modulate:a", 0.0, per_seg)
	# ② 世界去饱和灰罩
	tw.tween_callback(func() -> void: _desat_rect.visible = true)
	tw.tween_property(_desat_rect, "modulate:a",
		float(cfg.get("desaturate_alpha", 0.0)), float(cfg.get("desaturate_sec", 0.0)))
	# ③ dim
	tw.tween_callback(func() -> void: _dim_rect.visible = true)
	tw.tween_property(_dim_rect, "modulate:a",
		float(cfg.get("dim_alpha", 0.0)), float(cfg.get("dim_sec", 0.0)))
	# ④ 死因中文一行（JSON 映射）停留
	tw.tween_callback(func() -> void:
		_cause_label.text = ConfigManager.get_death_cause_text(cause)
		_cause_label.visible = true)
	tw.tween_interval(float(cfg.get("cause_hold_sec", 0.0)))
	# ⑤ 收场（残留全清）→ 总结屏
	tw.tween_callback(_clear_visuals)
	tw.tween_callback(on_finished)


## 胜利仪式：终点格金色扩散环（蛇头处）→ dim → 总结
func _play_victory(on_finished: Callable) -> void:
	var cfg: Dictionary = ConfigManager.get_ceremony_config()
	var snake: Node = get_tree().get_first_node_in_group("snake")
	if snake != null and "segments" in snake and not (snake.segments as Array).is_empty():
		var head = snake.segments[0]
		if is_instance_valid(head):
			VFXManager.ring_at(head.global_position, ConfigManager.get_palette_color(
				str(cfg.get("victory_ring_token", "accent_shedskin"))))
	var tw: Tween = _track(create_tween())
	tw.tween_callback(func() -> void: _dim_rect.visible = true)
	tw.tween_property(_dim_rect, "modulate:a",
		float(cfg.get("dim_alpha", 0.0)), float(cfg.get("dim_sec", 0.0)))
	tw.tween_interval(float(cfg.get("cause_hold_sec", 0.0)))
	tw.tween_callback(_clear_visuals)
	tw.tween_callback(on_finished)


## §8.1 房间意图两段式（T104a）：经 room_intent_panel 组驱动面板公共 API（§11.3
## 编排归本层）；game_feel 关闭直接 chip 态（无停留编排）
func _on_room_entered(_data: Dictionary) -> void:
	var panel: Node = get_tree().get_first_node_in_group("room_intent_panel")
	if panel == null:
		return
	if not bool(ConfigManager.get_game_feel().get("enabled", true)):
		if panel.has_method("collapse_banner"):
			panel.collapse_banner()
		return
	if panel.has_method("show_banner_stage"):
		panel.show_banner_stage()
	var tw: Tween = _track(create_tween())
	tw.tween_interval(float(ConfigManager.get_ceremony_config().get("room_banner_sec", 0.0)))
	tw.tween_callback(func() -> void:
		if is_instance_valid(panel) and panel.has_method("collapse_banner"):
			panel.collapse_banner())


## §8.3 选择仪式（T104b）：offer 呈现 → 停拍 + dim；floor_reward 两段式重呈现
## 单 token 原地保持（pause 集合语义幂等）。game_feel 关闭不仪式（FR-015 门控
## 仍由 RunProgression 把守，tick 照常——L3/L4 世界级行为不变）。
func _on_choice_presented(_data: Dictionary) -> void:
	if not bool(ConfigManager.get_game_feel().get("enabled", true)):
		return
	if _choice_paused:
		return
	_choice_paused = true
	TickManager.pause(&"ceremony")
	dim_in()


## 决议 → 只解自己持有的锁；选中确认 = 蛇头 acquire 环（§8.3「选中卡飞向蛇头」
## 的 v1 近似，整卡飞行/余卡坠落编排收 backlog）
func _on_choice_resolved(_data: Dictionary) -> void:
	if not _choice_paused:
		return
	_choice_paused = false
	TickManager.resume(&"ceremony")
	dim_out()
	var snake: Node = get_tree().get_first_node_in_group("snake")
	if snake != null and "segments" in snake and not (snake.segments as Array).is_empty():
		var head = snake.segments[0]
		if is_instance_valid(head):
			VFXManager.ring_at(head.global_position,
				ConfigManager.get_palette_color("accent_resonance"))


## 打断/清场：杀掉进行中编排并清全部视觉残留（重开局/回标题/新局路径调用，
## 防止挂起回调迟到污染下一局状态、防止 tween 引用已释放世界节点）
func reset() -> void:
	for tw in _tracked_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_tracked_tweens.clear()
	if _choice_paused:
		_choice_paused = false
		TickManager.resume(&"ceremony")
	_clear_visuals()


func _clear_visuals() -> void:
	if _dim_rect != null:
		_dim_rect.modulate.a = 0.0
		_dim_rect.visible = false
	if _desat_rect != null:
		_desat_rect.modulate.a = 0.0
		_desat_rect.visible = false
	if _cause_label != null:
		_cause_label.visible = false


## §8.3 dim 原语：bg_deep 罩淡入到 ceremony.dim_alpha（仪式聚焦；模态面板在其上层）
func dim_in() -> void:
	var cfg: Dictionary = ConfigManager.get_ceremony_config()
	var alpha: float = float(cfg.get("dim_alpha", 0.0))
	var sec: float = float(cfg.get("dim_sec", 0.0))
	_dim_rect.visible = true
	var tw: Tween = _track(create_tween())
	tw.tween_property(_dim_rect, "modulate:a", alpha, sec)


## dim 收场：淡出后隐藏（不可见即不进几何探测）
func dim_out() -> void:
	var sec: float = float(ConfigManager.get_ceremony_config().get("dim_sec", 0.0))
	var tw: Tween = _track(create_tween())
	tw.tween_property(_dim_rect, "modulate:a", 0.0, sec)
	tw.tween_callback(func() -> void: _dim_rect.visible = false)


func is_dimmed() -> bool:
	return _dim_rect.visible and _dim_rect.modulate.a > 0.0


## §11.5 settle()：全部追踪中 Tween 快进到终态（几何探针/体验驱动器只测沉降态）
func settle() -> void:
	for tw in _tracked_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.custom_step(INF)
	_tracked_tweens = _tracked_tweens.filter(
		func(tw) -> bool: return is_instance_valid(tw) and tw.is_valid()
	)


func _track(tw: Tween) -> Tween:
	_tracked_tweens.append(tw)
	return tw
