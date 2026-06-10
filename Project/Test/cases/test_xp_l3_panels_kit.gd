extends RefCounted
## SpecKit 004 T011+T012: L3 三面板 kit 迁移的新增语义契约（Red-first）
## 设计文档: Designs/Interactive/presentation_design.md §3(glyph/卡片解剖)/§4(字号阶梯)/
## §6(命中目标)/§11.5(kit 出生钩子)。
## 旧 getter 语义不变，由既有 test_l3_* 套件回归保障；本套件只断言迁移新增面：
## ui_kit 分组 / ui_layer 元数据 / settle() / 房型→glyph 映射 / palette token 取色 /
## 路径块状态与当前高亮 / Next 按钮命中目标 / choice_card 选项渲染与选中反馈。

const ROOM_INTENT_PATH: String = "res://ui/room_intent_panel.gd"
const FLOOR_PROGRESS_PATH: String = "res://ui/floor_progress_panel.gd"
const REWARD_CHOICE_PATH: String = "res://ui/reward_choice_panel.gd"
const FLOOR_MAP_GENERATOR_PATH: String = "res://systems/rooms/floor_map_generator.gd"


## 最小奖励流替身：面板只依赖 choose_reward(option_id) -> bool（§11.1 注入系统公共方法）
class StubRewardFlow:
	extends Node
	var chosen_ids: Array = []

	func choose_reward(option_id: String) -> bool:
		chosen_ids.append(option_id)
		return true


func run(t) -> void:
	for path in [ROOM_INTENT_PATH, FLOOR_PROGRESS_PATH, REWARD_CHOICE_PATH]:
		t.assert_file_exists(path)
		if not FileAccess.file_exists(path):
			return
	_test_panels_kit_membership(t)
	_test_room_intent_glyph_and_palette(t)
	_test_floor_progress_blocks_and_hit_target(t)
	_test_reward_choice_cards(t)


# ── kit 出生钩子：分组 / ui_layer / settle（§11.5） ─────────────────

func _test_panels_kit_membership(t) -> void:
	var specs: Array = [
		[ROOM_INTENT_PATH, "hud", false],
		[FLOOR_PROGRESS_PATH, "hud", false],
		[REWARD_CHOICE_PATH, "modal", true],
	]
	for spec in specs:
		var file: String = str(spec[0]).get_file()
		var panel: Control = load(spec[0]).new()
		t.add_child(panel)
		t.assert_true(panel.is_in_group("ui_kit"),
			"[XP-T011] %s is in ui_kit group" % file)
		t.assert_eq(str(panel.get_meta("ui_layer", "")), str(spec[1]),
			"[XP-T011] %s ui_layer meta is '%s'" % [file, spec[1]])
		t.assert_true(panel.has_method("settle"),
			"[XP-T011] %s exposes settle()" % file)
		panel.settle()
		t.assert_eq(panel.is_in_group("ui_modal"), bool(spec[2]),
			"[XP-T011] %s ui_modal group membership is %s" % [file, spec[2]])
		panel.queue_free()


# ── 房间意图：房型→glyph 映射 + room_* palette token 取色（T011） ────

func _test_room_intent_glyph_and_palette(t) -> void:
	var panel: Control = load(ROOM_INTENT_PATH).new()
	t.add_child(panel)

	EventBus.room_entered.emit(_make_room("combat_xp", "combat"))
	t.assert_eq(panel.get_glyph_id(), "combat",
		"[XP-T011] combat room maps to 'combat' glyph")
	t.assert_eq(panel.get_intent_color(), ConfigManager.get_palette_color("room_combat"),
		"[XP-T011] combat intent color reads room_combat palette token")
	var combat_cfg: Dictionary = ConfigManager.get_room_type("combat")
	t.assert_eq(panel.get_placeholder_color(), Color.html(str(combat_cfg.get("placeholder_color", ""))),
		"[XP-T011] legacy get_placeholder_color still reflects event data")

	EventBus.room_entered.emit(_make_room("reward_xp", "reward"))
	t.assert_eq(panel.get_glyph_id(), "reward",
		"[XP-T011] reward room maps to 'reward' glyph")
	t.assert_eq(panel.get_intent_color(), ConfigManager.get_palette_color("room_reward"),
		"[XP-T011] reward intent color reads room_reward palette token")

	panel.queue_free()


# ── 楼层进度：路径块状态/取色/当前高亮 + Next 命中目标（T011） ────────

func _test_floor_progress_blocks_and_hit_target(t) -> void:
	var panel: Control = load(FLOOR_PROGRESS_PATH).new()
	t.add_child(panel)

	var floor_map: Dictionary = load(FLOOR_MAP_GENERATOR_PATH).new().generate_floor(1, 1001)
	EventBus.floor_generated.emit(floor_map)

	t.assert_eq(panel.get_path_block_count(), floor_map.get("rooms", []).size(),
		"[XP-T011] path renders one block per room")

	var first: Dictionary = panel.get_path_block_info(0)
	t.assert_eq(str(first.get("state", "")), "current",
		"[XP-T011] start room block state is 'current'")
	t.assert_eq(first.get("color"), ConfigManager.get_palette_color("room_combat"),
		"[XP-T011] current block uses room_combat palette token")
	t.assert_eq(str(first.get("glyph_id", "")), "combat",
		"[XP-T011] block glyph matches room type")
	t.assert_true(bool(first.get("highlighted", false)),
		"[XP-T011] current room block is highlighted")

	var last: Dictionary = panel.get_path_block_info(panel.get_path_block_count() - 1)
	t.assert_eq(str(last.get("state", "")), "locked",
		"[XP-T011] unreached room block state is 'locked'")
	t.assert_eq(last.get("color"), ConfigManager.get_palette_color("frame_line"),
		"[XP-T011] unreached block is frame_line deep gray")

	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})
	EventBus.room_entered.emit({"room_id": "reward_01", "room_type": "reward", "intent_label": "选择奖励"})
	var done: Dictionary = panel.get_path_block_info(0)
	t.assert_eq(str(done.get("state", "")), "completed",
		"[XP-T011] completed room block state is 'completed'")
	t.assert_eq(done.get("color"), ConfigManager.get_palette_color("text_dim"),
		"[XP-T011] completed block dims to text_dim")
	t.assert_false(bool(done.get("highlighted", true)),
		"[XP-T011] completed block loses highlight")
	var current: Dictionary = panel.get_path_block_info(1)
	t.assert_eq(str(current.get("state", "")), "current",
		"[XP-T011] entered room block becomes 'current'")
	t.assert_eq(current.get("color"), ConfigManager.get_palette_color("room_reward"),
		"[XP-T011] current block uses room_reward palette token")

	var next_button: Control = panel.get_next_button()
	t.assert_true(next_button != null and next_button.is_in_group("ui_hit"),
		"[XP-T011] Next button registers as ui_hit target")
	var min_hit: float = float(ConfigManager.get_layout_config().get("min_hit_target", 0))
	t.assert_true(min_hit > 0.0, "[XP-T011] min_hit_target configured in JSON")
	if next_button != null:
		t.assert_true(next_button.custom_minimum_size.x >= min_hit \
				and next_button.custom_minimum_size.y >= min_hit,
			"[XP-T011] Next button min size >= min_hit_target")

	panel.queue_free()


# ── 奖励选择：choice_card 渲染 + 选中反馈（T012） ────────────────────

func _test_reward_choice_cards(t) -> void:
	var flow := StubRewardFlow.new()
	t.add_child(flow)
	var panel: Control = load(REWARD_CHOICE_PATH).new()
	panel.setup(flow)
	t.add_child(panel)

	var options: Array = [
		{"option_id": "head_hydra", "display_name": "九头蛇", "reward_type": "head", "placeholder_color": "#C85F3D"},
		{"option_id": "tail_salamander", "display_name": "再生尾", "reward_type": "tail", "placeholder_color": "#D9823B"},
		{"option_id": "scale_flame", "display_name": "火焰鳞", "reward_type": "scale", "placeholder_color": "#E4572E"},
	]
	EventBus.reward_presented.emit({"offer_id": "xp_t012", "options": options})

	t.assert_eq(panel.get_visible_option_count(), options.size(),
		"[XP-T012] option count getter preserved")
	var cards: Array = panel.get_option_cards()
	t.assert_eq(cards.size(), options.size(),
		"[XP-T012] one choice_card per option")
	if cards.size() != options.size():
		panel.queue_free()
		flow.queue_free()
		return

	for index in range(cards.size()):
		var card = cards[index]
		var option: Dictionary = options[index]
		t.assert_true(card.is_in_group("ui_kit"),
			"[XP-T012] card %d is a kit component" % index)
		t.assert_true(card.is_in_group("ui_hit"),
			"[XP-T012] card %d registers as hit target" % index)
		var content: Dictionary = card.get_content()
		t.assert_eq(str(content.get("name", "")), str(option.get("display_name")),
			"[XP-T012] card %d shows option display_name" % index)
		t.assert_eq(str(content.get("glyph_id", "")), str(option.get("reward_type")),
			"[XP-T012] card %d glyph maps reward_type (head/tail/scale)" % index)
		t.assert_eq(content.get("tag_color"), Color.html(str(option.get("placeholder_color"))),
			"[XP-T012] card %d tag color comes from option JSON color" % index)

	panel.highlight_option(0)
	t.assert_true(cards[0].is_selected(), "[XP-T012] highlight_option selects card 0")
	panel.highlight_option(1)
	t.assert_false(cards[0].is_selected(), "[XP-T012] highlight is exclusive")
	t.assert_true(cards[1].is_selected(), "[XP-T012] highlight moves to card 1")

	t.assert_true(panel.choose_option_by_index(2),
		"[XP-T012] choose_option_by_index keeps delegating to flow")
	t.assert_eq(flow.chosen_ids, ["scale_flame"],
		"[XP-T012] panel passes option_id to flow.choose_reward")
	t.assert_true(cards[2].is_selected(),
		"[XP-T012] choosing applies set_selected feedback on the card")

	EventBus.reward_chosen.emit({"chosen_option_id": "scale_flame", "option": options[2]})
	t.assert_eq(panel.get_visible_option_count(), 0,
		"[XP-T012] options clear after reward_chosen (legacy semantics)")
	t.assert_true(panel.get_option_cards().is_empty(),
		"[XP-T012] cards clear after reward_chosen")

	panel.queue_free()
	flow.queue_free()


# ── helpers ──────────────────────────────────────────────────────────

func _make_room(room_id: String, room_type: String) -> Dictionary:
	var cfg: Dictionary = ConfigManager.get_room_type(room_type)
	return {
		"room_id": room_id,
		"room_type": room_type,
		"intent_label": cfg.get("intent_label", room_type),
		"primary_intent": cfg.get("primary_intent", ""),
		"objective": {
			"objective_type": cfg.get("objective_type", ""),
			"required_count": int(cfg.get("required_count", 1)),
			"current_count": 0,
			"complete": false,
		},
		"placeholder_color": cfg.get("placeholder_color", "#FFFFFF"),
		"exit_room_ids": [],
		"enabled": true,
		"available": true,
		"completed": false,
	}
