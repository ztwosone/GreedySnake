extends PanelContainer
## 角括号框面板基类（SpecKit 004 T003，设计文档 presentation_design.md §3/§11.5）
## 无 class_name：消费方一律 preload 本文件（ScriptingLeading 附录 C.8）。
## 出生即带验收钩子：分组 ui_kit、ui_layer 元数据、settle() 快进、ui_allow_truncate 声明助手。
## 零编排（§11.3）：本层只有组件态；pause/dim/stagger/飞行编排属 Phase P CeremonyLayer。

const _ThemeBuilderScript := preload("res://ui/kit/theme_builder.gd")

## §11.5 合法 ui_layer 值（几何探针按层矩阵豁免重叠）
const UI_LAYERS: Array = ["hud", "modal", "dim", "toast"]

## §3 组件级反馈幅度（卡片选中态 scale 1.05；chip bounce 共用此幅度）
const FEEDBACK_SCALE: float = 1.05

## §5 缓动表：JSON easing 名 → Tween 常量
const _EASING_TABLE: Dictionary = {
	"quint_out": {"trans": Tween.TRANS_QUINT, "ease": Tween.EASE_OUT},
	"cubic_in": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN},
	"cubic_out": {"trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
	"back_out": {"trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT},
}

## 共享缓存 Theme：theme_builder 只构建一次，全部 kit 组件复用同一实例
static var _shared_theme: Theme = null

var _tracked_tweens: Array = []
var _frame_highlighted: bool = false


func _init(ui_layer: String = "hud") -> void:
	add_to_group("ui_kit")
	set_ui_layer(ui_layer)
	theme = _get_shared_theme()
	# 缩放/弹跳类反馈以中心为轴（pivot 跟随尺寸）
	resized.connect(_center_pivot)


static func _get_shared_theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = _ThemeBuilderScript.new().build()
	return _shared_theme


func _center_pivot() -> void:
	pivot_offset = size * 0.5


## §11.5：ui_layer 元数据（hud|modal|dim|toast），未知值回退 hud
func set_ui_layer(layer: String) -> void:
	if not UI_LAYERS.has(layer):
		push_warning("kit_panel: unknown ui_layer '%s', falling back to 'hud'" % layer)
		layer = "hud"
	set_meta("ui_layer", layer)


func get_ui_layer() -> String:
	return str(get_meta("ui_layer", ""))


## §3 签名母题：四角 8px L 形角标（frame_line 色 2px 粗），不画完整边框。
## 8px = 0.5 基准单位、2px = 0.125 基准单位（§6 base_unit=16）。
func _draw() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	if base_unit <= 0.0:
		return
	var arm: float = base_unit * 0.5
	var thickness: float = base_unit * 0.125
	var token: String = "accent_resonance" if _frame_highlighted else "frame_line"
	var color: Color = ConfigManager.get_palette_color(token)
	var s: Vector2 = size
	# 左上
	draw_rect(Rect2(0, 0, arm, thickness), color)
	draw_rect(Rect2(0, 0, thickness, arm), color)
	# 右上
	draw_rect(Rect2(s.x - arm, 0, arm, thickness), color)
	draw_rect(Rect2(s.x - thickness, 0, thickness, arm), color)
	# 左下
	draw_rect(Rect2(0, s.y - thickness, arm, thickness), color)
	draw_rect(Rect2(0, s.y - arm, thickness, arm), color)
	# 右下
	draw_rect(Rect2(s.x - arm, s.y - thickness, arm, thickness), color)
	draw_rect(Rect2(s.x - thickness, s.y - arm, thickness, arm), color)


## 选中/高亮态：角括号从 frame_line 切到 accent_resonance（§3 「外框亮起」）
func set_frame_highlighted(highlighted: bool) -> void:
	_frame_highlighted = highlighted
	queue_redraw()


func is_frame_highlighted() -> bool:
	return _frame_highlighted


## 子类创建的 Tween 必须经此登记，settle() 才能快进（§11.5）
func track_tween(tw: Tween) -> Tween:
	_tracked_tweens.append(tw)
	return tw


## §11.5 settle()：全部追踪中 Tween 快进到终态（几何探针只测沉降态）
func settle() -> void:
	for tw in _tracked_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.custom_step(INF)
	_tracked_tweens = _tracked_tweens.filter(
		func(tw) -> bool: return is_instance_valid(tw) and tw.is_valid()
	)


## §12.1：刻意省略号截断必须显式声明，几何探针据此豁免
static func set_allow_truncate(label: Label) -> void:
	label.set_meta("ui_allow_truncate", true)


## §6 最小命中目标 + ui_hit 分组（几何探针按组断言 ≥ min_hit_target）
func register_hit_target(control: Control) -> void:
	var min_hit: float = float(ConfigManager.get_layout_config().get("min_hit_target", 0))
	control.custom_minimum_size = Vector2(
		maxf(control.custom_minimum_size.x, min_hit),
		maxf(control.custom_minimum_size.y, min_hit)
	)
	if not control.is_in_group("ui_hit"):
		control.add_to_group("ui_hit")


## §5 标准缓动表：角色名（enter/exit/feedback/acquire）→ {trans, ease}
func get_easing(role: String) -> Dictionary:
	var easing_cfg: Dictionary = ConfigManager.get_motion().get("easing", {})
	var easing_name: String = str(easing_cfg.get(role, ""))
	if not _EASING_TABLE.has(easing_name):
		push_warning("kit_panel: unknown easing '%s' for role '%s', falling back to linear" % [easing_name, role])
		return {"trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT}
	return _EASING_TABLE[easing_name]
