extends Node
## Layer C 截图装置（spec 002 T035，presentation_design.md §12.2 AI 视觉层）
## 自承载主场景（test_runner.tscn 同模式）：带窗运行 → 逐典型状态布景（与 Layer A/B
## 共用 Test/experience/state_stager）→ 冻结 tick → 沉降 → frame_post_draw 截图 PNG。
## 用法（经 Tools/run_acceptance_shots.ps1，读 EnvPath.json）：
##   godot --path Project res://AcceptanceShots/acceptance_shots.tscn
## 输出：AgentOps/acceptance_shots/<date>/<shot_id>.png + manifest.json；
## findings.md（§12.2 清单逐张评审）由 AI 读图后人工归档，不在本装置内生成。
## headless 下渲染管线为 dummy driver，截图全黑——本装置必须带窗运行（Stage Gate 时点）。

const STAGER_PATH: String = "res://Test/experience/state_stager.gd"
const SETTLE_PATH: String = "res://Test/experience/ui_settle.gd"

## 镜头清单：id 前缀定序；state 为 stager 状态名，"@multifloor_midrun" 为
## 本装置内驱动的特殊布景（pcg 档推进到第 2 层的局中态）
const SHOT_MANIFEST: Array = [
	{"id": "01_title", "state": "title_screen"},
	{"id": "02_l3_run_start", "state": "l3_run_start"},
	{"id": "03_l4_scale_pending", "state": "l4_scale_pending"},
	{"id": "04_l4_shop_open", "state": "l4_shop_open"},
	{"id": "05_l4_floor_reward_slot", "state": "l4_floor_reward_slot"},
	{"id": "06_l4_floor_reward_choice", "state": "l4_floor_reward_choice"},
	{"id": "07_l4_multifloor_midrun", "state": "@multifloor_midrun"},
]

const MULTIFLOOR_SEED: int = 9090
const MIDRUN_ACTION_BUDGET: int = 128

var _failures: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = _ensure_output_dir()
	if out_dir == "":
		printerr("SHOTS FAILED: cannot create output directory")
		get_tree().quit(1)
		return

	var manifest: Array = []
	for shot in SHOT_MANIFEST:
		var shot_id: String = str(shot.get("id", ""))
		var state_name: String = str(shot.get("state", ""))
		var path: String = out_dir.path_join("%s.png" % shot_id)
		var ok: bool = await _capture_shot(state_name, path)
		manifest.append({"id": shot_id, "state": state_name, "file": "%s.png" % shot_id, "ok": ok})
		print("SHOTS: %s -> %s [%s]" % [state_name, path, "ok" if ok else "FAILED"])
		if not ok:
			_failures.append(shot_id)

	var manifest_file := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file:
		manifest_file.store_string(JSON.stringify({
			"date": Time.get_date_string_from_system(),
			"resolution": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
			"shots": manifest,
		}, "\t"))
		manifest_file.close()

	print("SHOTS: done, %d/%d captured (out: %s)" % [
		SHOT_MANIFEST.size() - _failures.size(), SHOT_MANIFEST.size(), out_dir])
	get_tree().quit(0 if _failures.is_empty() else 1)


## 单镜头：布景 → 冻结 tick（沉降态纪律，与几何探测一致）→ settle → 截图 → 还原
func _capture_shot(state_name: String, path: String) -> bool:
	var stager_script: GDScript = load(STAGER_PATH)
	var ctx: Dictionary
	if state_name == "@multifloor_midrun":
		ctx = await _stage_multifloor_midrun(stager_script)
	else:
		ctx = stager_script.stage(state_name, self)
	TickManager.stop_ticking()

	var ok: bool = false
	if ctx.get("world", null) != null:
		await get_tree().process_frame
		await get_tree().process_frame
		load(SETTLE_PATH).settle_all(get_tree())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		ok = image != null and image.save_png(path) == OK

	stager_script.teardown(ctx)
	if ctx.has("restore_generator"):
		ConfigManager.floor["generator"] = str(ctx.get("restore_generator"))
		ConfigManager.floor["default_seed"] = int(ctx.get("restore_seed", 0))
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


## 特殊布景：pcg 档（定种子）面板公共 API 驱动到第 2 层局中（多层压力可见：
## 楼层进度/主题切换后的新布场）；推进期间 tick 冻结，房间目标走 record_objective_progress
func _stage_multifloor_midrun(stager_script: GDScript) -> Dictionary:
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	var previous_seed: int = int(ConfigManager.floor.get("default_seed", 0))
	ConfigManager.floor["generator"] = "pcg"
	ConfigManager.floor["default_seed"] = MULTIFLOOR_SEED

	var ctx: Dictionary = stager_script.stage("l3_run_start", self)
	ctx["restore_generator"] = previous_generator
	ctx["restore_seed"] = previous_seed
	var world: Node = ctx.get("world", null)
	if world == null:
		return ctx
	TickManager.stop_ticking()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var reward_flow: Node = world.get_node("RewardFlowSystem")
	var scale_system: Node = world.get_node("ScaleRewardSystem")
	var floor_reward_system: Node = world.get_node("FloorRewardSystem")
	var floor_panel: Node = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Node = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Node = world.get_node("UI/ScaleChoicePanel")
	var floor_reward_panel: Node = world.get_node("UI/FloorRewardPanel")

	for _step in range(MIDRUN_ACTION_BUDGET):
		if not run_system.is_running():
			break
		if int(run_system.get_state().get("floor_index", 1)) >= 2:
			break
		if scale_system.has_pending_offer():
			scale_panel.discard_offer()
			continue
		if reward_flow.has_pending_offer():
			reward_panel.choose_option_by_index(0)
			continue
		if floor_reward_system.has_pending_offer():
			if floor_reward_panel.get_step() == "slot_unlock":
				floor_reward_panel.choose_slot_by_index(0)
			else:
				floor_reward_panel.choose_option_by_index(0)
			continue
		if not room_flow.is_current_room_complete():
			var objective: Dictionary = room_flow.get_current_room().get("objective", {})
			if str(objective.get("objective_type", "")) == "clear_enemies":
				room_flow.record_objective_progress(int(objective.get("required_count", 1)), {"method": "shots_midrun"})
			continue
		await get_tree().process_frame
		if not run_system.is_running() or floor_reward_system.has_pending_offer():
			continue
		floor_panel.request_next_room()
	return ctx


## 输出目录：<repo>/AgentOps/acceptance_shots/<date>/
func _ensure_output_dir() -> String:
	var out_dir: String = (ProjectSettings.globalize_path("res://") \
		+ "/../AgentOps/acceptance_shots/" + Time.get_date_string_from_system()).simplify_path()
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		return ""
	return out_dir
