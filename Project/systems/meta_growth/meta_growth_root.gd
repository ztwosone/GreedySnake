extends Node
## spec 003 M2（T009）：L5 元成长常驻根（main.tscn，GameWorldContainer 外，跨 run 存续——
## 世界每局重建，本节点与其子系统不清）。
##
## - boot(save_path)：显式装载 MetaSaveSystem 并 load_from_disk()（M1 裁定：_init 不隐式读盘，
##   注入先于首次磁盘 IO）。生产缺省路径 = meta_growth.save_path（user://meta_save.json）。
##   测试缝：凡把 main.tscn 入树并驱动 `run_ended` 的套件，必须先 boot(临时路径) 再触发——
##   否则解锁/铸石落盘会污染生产存档（存档卫生红线；M4 全环冒烟据此注入）。重复 boot = 换档重开。
## - 子系统：RunStatsTracker（`run_ended` 唯一发射点，`run_started` 自重置）+
##   UnlockSystem / LegacyStoneSystem `setup(meta_save)`（均监听 `run_ended`）。
## - attach_world(world)：每局新世界 duck-typed 接线——RunProgression.set_stats_tracker
##   （M1 注入缝，未注入零行为）+ RewardFlow.set_unlock_query（T010 解锁过滤缝，
##   口径同 ScaleRewardSystem.set_sampling_bias：Callable 注入、未注入全量回退）。
## - 结算数据通路（M2 卡，M3 T016 在此基础扩展）：缓存本局 content_unlocked /
##   legacy_stone_created，`run_ended` 时与冻结 stats 合并为 get_last_run_summary()；
##   `run_started` 清缓存。呈现编排归 S4（004 Phase P）。
##
## 事件序依赖（接线顺序即正确性）：子系统在子节点 _ready（先于本节点 _ready）连接
## `run_ended`，本节点在 _ready 末尾连接——run_ended 派发时 Unlock/LegacyStone 先行
## 发出 content_unlocked / legacy_stone_created，本节点的汇总 handler 最后执行。

const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")
const RunStatsTrackerScript := preload("res://systems/meta_growth/run_stats_tracker.gd")
const UnlockSystemScript := preload("res://systems/meta_growth/unlock_system.gd")
const LegacyStoneSystemScript := preload("res://systems/meta_growth/legacy_stone_system.gd")

var _meta_save = null
var _stats_tracker: Node = null
var _unlock_system: Node = null
var _legacy_stone_system: Node = null

var _last_run_summary: Dictionary = {}
var _run_unlocks: Array = []
var _run_stone: Dictionary = {}


func _ready() -> void:
	if _meta_save == null:
		boot()
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


## 显式装载（save_path 空 = 生产路径）；可重复调用换档（测试缝）
func boot(save_path: String = "") -> void:
	_meta_save = MetaSaveSystemScript.new(save_path)
	_meta_save.load_from_disk()
	_last_run_summary = {}
	_run_unlocks = []
	_run_stone = {}
	_ensure_children()
	_unlock_system.setup(_meta_save)
	_legacy_stone_system.setup(_meta_save)


func connect_events() -> void:
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)
	if not EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.connect(_on_content_unlocked)
	if not EventBus.legacy_stone_created.is_connected(_on_legacy_stone_created):
		EventBus.legacy_stone_created.connect(_on_legacy_stone_created)
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)


func disconnect_events() -> void:
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)
	if EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.disconnect(_on_content_unlocked)
	if EventBus.legacy_stone_created.is_connected(_on_legacy_stone_created):
		EventBus.legacy_stone_created.disconnect(_on_legacy_stone_created)
	if EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.disconnect(_on_run_ended)


## 每局新世界接线（duck-typed：L1/L2 验收场景无对应节点时全部 no-op）
func attach_world(world: Node) -> void:
	if world == null:
		return
	var run_system: Node = world.get_node_or_null("RunProgressionSystem")
	if run_system and run_system.has_method("set_stats_tracker"):
		run_system.set_stats_tracker(_stats_tracker)
	var reward_flow: Node = world.get_node_or_null("RewardFlowSystem")
	if reward_flow and reward_flow.has_method("set_unlock_query"):
		reward_flow.set_unlock_query(is_content_unlocked)


## 解锁查询（RewardFlow 过滤缝消费）：v1 仅门控 head/tail，
## 鳞片等其他内容不过滤（Designs §12.3 附录「v1 鳞片范围」）
func is_content_unlocked(content_type: String, content_id: String) -> bool:
	if _meta_save == null:
		return true
	match content_type:
		"head":
			return _meta_save.is_head_unlocked(content_id)
		"tail":
			return _meta_save.is_tail_unlocked(content_id)
	return true


func get_meta_save():
	return _meta_save


func get_stats_tracker() -> Node:
	return _stats_tracker


func get_unlock_system() -> Node:
	return _unlock_system


func get_legacy_stone_system() -> Node:
	return _legacy_stone_system


## 结算数据缓存：{outcome, run_id, floor_index, stats, unlocks, stone}；
## 本局尚未结束 / 新局已开始 → 空字典
func get_last_run_summary() -> Dictionary:
	return _last_run_summary.duplicate(true)


func cleanup() -> void:
	disconnect_events()
	if _unlock_system and _unlock_system.has_method("cleanup"):
		_unlock_system.cleanup()
	if _legacy_stone_system and _legacy_stone_system.has_method("cleanup"):
		_legacy_stone_system.cleanup()
	if _stats_tracker and _stats_tracker.has_method("cleanup"):
		_stats_tracker.cleanup()


func _ensure_children() -> void:
	if _stats_tracker == null:
		_stats_tracker = RunStatsTrackerScript.new()
		_stats_tracker.name = "RunStatsTracker"
		add_child(_stats_tracker)
	if _unlock_system == null:
		_unlock_system = UnlockSystemScript.new()
		_unlock_system.name = "UnlockSystem"
		add_child(_unlock_system)
	if _legacy_stone_system == null:
		_legacy_stone_system = LegacyStoneSystemScript.new()
		_legacy_stone_system.name = "LegacyStoneSystem"
		add_child(_legacy_stone_system)


func _on_run_started(_data: Dictionary) -> void:
	_last_run_summary = {}
	_run_unlocks = []
	_run_stone = {}


func _on_content_unlocked(data: Dictionary) -> void:
	_run_unlocks.append(data.duplicate(true))


func _on_legacy_stone_created(data: Dictionary) -> void:
	_run_stone = data.duplicate(true)


func _on_run_ended(data: Dictionary) -> void:
	_last_run_summary = {
		"outcome": str(data.get("outcome", "")),
		"run_id": str(data.get("run_id", "")),
		"floor_index": int(data.get("floor_index", 0)),
		"stats": data.get("stats", {}).duplicate(true),
		"unlocks": _run_unlocks.duplicate(true),
		"stone": _run_stone.duplicate(true),
	}
