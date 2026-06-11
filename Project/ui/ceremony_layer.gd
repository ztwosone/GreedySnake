extends Control
## CeremonyLayer——仪式编排宿主（SpecKit 004 Phase P T102 骨架）
## 设计: Designs/Interactive/presentation_design.md §7（屏幕流仪式）/§8.3（选择仪式）/
## §11.3（kit 零编排红线的解除处：pause/dim/stagger/飞行编排全部从这里外部驱动）。
## 本卡只落 dim 原语 + settle 验收钩子；死亡/胜利仪式归 T103，选择仪式归 T104。
## 数值唯一来源 = presentation.ceremony（FR-001）；本层只听不驱动游戏状态（FR-002）。

var _dim_rect: ColorRect
var _tracked_tweens: Array = []


func _init() -> void:
	name = "CeremonyLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# §11.5 验收钩子：dim 层入 ui_dim 组 + ui_layer 元数据（几何探针层矩阵豁免）
	add_to_group("ui_dim")
	set_meta("ui_layer", "dim")


func _ready() -> void:
	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.color = ConfigManager.get_palette_color("bg_deep")
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.modulate.a = 0.0
	_dim_rect.visible = false
	add_child(_dim_rect)


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
