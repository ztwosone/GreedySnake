class_name AtomContext
extends RefCounted
## 效果原子执行上下文
## 传递给每个原子的运行时环境信息。

# === 实体引用 ===
var source: Object = null          # 效果施加者（蛇/敌人/地砖）
var target: Object = null          # 效果承受者
var source_position: Vector2i = Vector2i.ZERO
var target_position: Vector2i = Vector2i.ZERO

# === 效果数据 ===
var effect_data = null             # StatusEffectData（可 null）
var delta: float = 0.0             # 帧间隔
var params: Dictionary = {}        # chain 级别参数（radius, interval 等）
var direction: Vector2i = Vector2i.ZERO  # 方向（knockback/line 用）

# === 反应上下文 ===
var layer_a: int = 0               # 反应时状态 A 层数
var layer_b: int = 0               # 反应时状态 B 层数

# === 系统引用 ===
var effect_mgr: Node = null        # StatusEffectManager
var tile_mgr = null                # StatusTileManager
var tick_mgr: Node = null          # TickManager
var enemy_mgr: Node = null         # EnemyManager
var food_mgr: Node = null          # FoodManager
var window_mgr: Node = null        # EffectWindowManager

# === 原子间数据管道 ===
var results: Dictionary = {}       # damage_cap, cancel_cost, damage_dealt 等


## 创建一个子上下文，覆盖 target_position（用于 pattern 解析后对每个目标执行）
func with_target_position(pos: Vector2i) -> AtomContext:
	var ctx := AtomContext.new()
	ctx.source = source
	ctx.target = target
	ctx.source_position = source_position
	ctx.target_position = pos
	ctx.effect_data = effect_data
	ctx.delta = delta
	ctx.params = params
	ctx.direction = direction
	ctx.layer_a = layer_a
	ctx.layer_b = layer_b
	ctx.effect_mgr = effect_mgr
	ctx.tile_mgr = tile_mgr
	ctx.tick_mgr = tick_mgr
	ctx.enemy_mgr = enemy_mgr
	ctx.food_mgr = food_mgr
	ctx.window_mgr = window_mgr
	ctx.results = results  # 共享同一个 results dict
	return ctx


## 创建一个子上下文，覆盖 target
func with_target(new_target: Object) -> AtomContext:
	var ctx := with_target_position(target_position)
	ctx.target = new_target
	if new_target and new_target.get("grid_position") != null:
		ctx.target_position = new_target.grid_position
	return ctx
