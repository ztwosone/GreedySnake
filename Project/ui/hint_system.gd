extends "res://ui/kit/kit_panel.gd"
## 认知轻度引导（SpecKit 004 Phase P T106，presentation_design.md §8.8）
## 无教程屏：首次事件 → 底中一行 caption（hint_hold_sec 后收起）。
## ≤1 条新概念/房间（被压掉的不标已见——下个房间另一次首次事件再现）；
## 已见列表入 meta 存档（经 save_source.get_meta_save() 每次取活档——boot 换档安全）；
## 文案全部在 presentation.hints（FR-001）。纯监听（§11.1 只听不驱动）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。

## hint_id → [触发信号, 过滤器（可空 Callable，收 payload 返回 bool）]
## 文案在 JSON；事件绑定是代码契约（信号本身即代码侧概念）
var _caption_label: Label
var _save_source: Node = null
var _shown_this_room: bool = false
## 会话内已见缓存（无存档源时仍保证"每条仅一次"）
var _session_seen: Dictionary = {}


func _init() -> void:
	super._init("hud")


func _ready() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 16))
	var screen_margin: float = float(layout.get("screen_margin", 0))
	# 底中、Build 状态条之上（条高 1.75bu + 边距）
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -(screen_margin + base_unit * 1.75 + base_unit * 2.0)
	offset_bottom = -(screen_margin + base_unit * 1.75 + base_unit * 0.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_caption_label = Label.new()
	_caption_label.name = "HintCaption"
	_caption_label.theme_type_variation = "CaptionLabel"
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_caption_label)

	EventBus.room_entered.connect(_on_room_entered)
	EventBus.snake_food_eaten.connect(_make_handler("first_food"))
	EventBus.snake_body_attacked.connect(_make_handler("first_hit"))
	EventBus.status_applied.connect(_make_handler("first_status"))
	EventBus.reward_presented.connect(_make_handler("first_reward"))
	EventBus.resonance_activated.connect(_make_handler("first_resonance"))
	EventBus.shop_entered.connect(_make_handler("first_shop"))
	EventBus.pickup_collected.connect(_make_handler("first_pickup"))
	EventBus.currency_changed.connect(_on_currency_changed)


## 存档源注入（main 接 MetaGrowthRoot；duck-typed get_meta_save → 每次取活档）
func set_save_source(source: Node) -> void:
	_save_source = source


func is_caption_visible() -> bool:
	return visible


func get_caption_text() -> String:
	return _caption_label.text if _caption_label != null else ""


func _make_handler(hint_id: String) -> Callable:
	return func(_data: Dictionary) -> void: _try_show(hint_id)


## first_shedskin 条件入口：真实蜕皮入账才算首次（reset/扣款不算）
func _on_currency_changed(data: Dictionary) -> void:
	if str(data.get("currency", "")) == "shedskin" and int(data.get("amount", 0)) > 0:
		_try_show("first_shedskin")


func _on_room_entered(_data: Dictionary) -> void:
	_shown_this_room = false


func _try_show(hint_id: String) -> void:
	if _shown_this_room:
		return  # §8.8：≤1 条新概念/房间——压掉的不标已见
	if _session_seen.get(hint_id, false) or _persisted_seen(hint_id):
		return
	var text: String = str(ConfigManager.get_presentation_config() \
		.get("hints", {}).get(hint_id, ""))
	if text.is_empty():
		return
	_shown_this_room = true
	_session_seen[hint_id] = true
	_mark_persisted(hint_id)
	_caption_label.text = text
	visible = true
	var tw: Tween = track_tween(create_tween())
	tw.tween_interval(float(
		ConfigManager.get_ceremony_config().get("hint_hold_sec", 0.0)))
	tw.tween_callback(func() -> void: visible = false)


func _persisted_seen(hint_id: String) -> bool:
	var save = _get_save()
	return save != null and save.get_seen_hints().has(hint_id)


func _mark_persisted(hint_id: String) -> void:
	var save = _get_save()
	if save != null:
		save.mark_hint_seen(hint_id)


func _get_save():
	if _save_source != null and is_instance_valid(_save_source) \
			and _save_source.has_method("get_meta_save"):
		return _save_source.get_meta_save()
	return null
