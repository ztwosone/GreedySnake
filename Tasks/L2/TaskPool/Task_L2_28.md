## [L2-T28] Atom System 能力扩展：新触发器 + 新原子

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L2-Phase 1 |
| **优先级** | P1(核心) |
| **前置任务** | T25 (Atom System), T27 (EffectWindow) |
| **预估粒度** | M(1~3h) |
| **分配职能** | 系统程序 |

### 概述

扩展 T25 Atom System 的事件覆盖面和原子库，为 L2 蛇头/蛇尾/蛇鳞系统提供所需的触发器和原子。分为 T28A（触发器）和 T28B（原子）两部分。

---

## T28A — 新增触发器（7 个）

### 设计动机

L1 的 17 个触发器覆盖了战斗和状态事件，但缺少**操作维度**（玩家输入相关）和**资源维度**（长度增减完整事件）。L2 Build 系统需要这些触发器来支撑多样化的效果配置。

### 高价值触发器（3 个）

| 触发器 | 信号源 | payload | 设计用途 |
|--------|--------|---------|---------|
| `on_length_change` | snake.gd: 长度增减时 | `{ amount: int, direction: "grow"/"shrink", new_length: int }` | 蛇鳞"每增长 N 段触发 X"、长度联动效果 |
| `on_turn` | snake.gd: 方向改变时 | `{ old_direction: Vector2i, new_direction: Vector2i, turn_count: int }` | 操作型 build、"连续直行加速"、"转弯释放状态" |
| `on_near_death` | snake.gd: 长度降至阈值 | `{ current_length: int, threshold: int }` | 濒死暴走、绝境反击、低血量触发型效果 |

### 中价值触发器（4 个）

| 触发器 | 信号源 | payload | 设计用途 |
|--------|--------|---------|---------|
| `on_streak` | enemy_manager.gd: 连续击杀 | `{ streak_count: int, time_since_first: float }` | 连杀奖励、combo 系统 |
| `on_enemy_approach` | enemy.gd: 敌人进入范围 | `{ enemy: Enemy, distance: int, segment: SnakeSegment }` | 防御型 build（靠近时自动释冰）、预警 |
| `on_status_gained` | snake_segment.gd: 段获得状态 | `{ segment: SnakeSegment, status_type: String, source: String }` | 状态联动（"获火时+1伤"）、build 触发 |
| `on_tile_placed` | status_tile_manager.gd: 放置状态格 | `{ position: Vector2i, type: String, source: String }` | 蛇鳞与蔓延系统联动、领地控制 build |

### 实现方式

每个触发器的实现步骤相同：

1. `EventBus` 新增信号定义
2. 信号发射点添加 `EventBus.<signal>.emit(data)` （通常 1 行代码）
3. `TriggerManager._connect_signals()` 中连接信号并调用 `_fire_trigger(trigger_name, data)`
4. 编写测试验证触发

### on_near_death 特殊说明

不同于其他事件型触发器，on_near_death 需要避免重复触发。实现策略：
- TriggerManager 维护 `_near_death_fired: bool` 标志
- 长度降至阈值时触发一次，长度回升后重置标志
- 阈值由链的 `trigger_params.threshold` 配置（默认 3）

### on_streak 特殊说明

- enemy_manager 维护 `_kill_streak: int` 和 `_last_kill_tick: int`
- 每次击杀递增 streak，如果距上次击杀超过 N tick（可配置，默认 10）则重置
- 每次击杀都发射信号，由链的条件原子（如 `if_count_reached`）过滤

---

## T28B — 新增即时原子（4 个）

| 原子名 | 类别 | 参数 | 作用 | 用于 |
|--------|------|------|------|------|
| `modify_food_drop` | Value | `amount: int` | 改写击杀后食物掉落数量（叠加到 ctx.results） | 蛇头 |
| `direct_grow` | Value | `amount: int` | 直接增长蛇身 N 段（跳过食物流程） | 蛇头、蛇尾 |
| `steal_status` | Status | — | 从 ctx.target（被吃敌人）偷取 carried_status 到 ctx.source（蛇头段） | 蛇头 |
| `modify_hit_threshold` | Value | `value: int` | 改写 hits_per_segment_loss（叠加修改） | 蛇头 |

### 实现方式

每个原子的实现步骤相同：

1. 创建 `systems/atoms/atoms/<category>/<name>_atom.gd` extends AtomBase
2. 实现 `execute(ctx: AtomContext)`
3. 在 `atom_registry.gd` 注册
4. 编写测试

### 原子详细设计

#### modify_food_drop

```gdscript
func execute(ctx: AtomContext) -> void:
    var amount: int = get_param("amount", 0)
    var current: int = ctx.results.get("food_drop_modifier", 0)
    ctx.results["food_drop_modifier"] = current + amount
```

消费方：enemy_manager.gd 在 `_on_snake_hit_enemy` 中读取 `food_drop_modifier` 调整掉落数。

#### direct_grow

```gdscript
func execute(ctx: AtomContext) -> void:
    var amount: int = get_param("amount", 1)
    if ctx.source and ctx.source.has_method("request_grow"):
        ctx.source.request_grow(amount)
```

需要 Snake 新增 `request_grow(amount)` 方法（设置 grow_pending += amount）。

#### steal_status

```gdscript
func execute(ctx: AtomContext) -> void:
    if not ctx.target or not ctx.source:
        return
    var enemy_status: String = ""
    if ctx.target.has_method("get_carried_status"):
        enemy_status = ctx.target.get_carried_status()
    if enemy_status == "" or not ctx.source.has_method("set_carried_status"):
        return
    ctx.source.set_carried_status(enemy_status)
    ctx.target.clear_carried_status()
```

#### modify_hit_threshold

```gdscript
func execute(ctx: AtomContext) -> void:
    var value: int = get_param("value", 0)
    var current: int = ctx.results.get("hit_threshold_modifier", 0)
    ctx.results["hit_threshold_modifier"] = current + value
```

消费方：enemy.gd 在 `_attack_segment` 中读取修改后的阈值。

---

## 测试清单

### T28A 触发器

- [ ] on_length_change: 吃食物增长 → 触发 direction="grow"
- [ ] on_length_change: 丢段 → 触发 direction="shrink"
- [ ] on_turn: 蛇改变方向 → 触发，直行不触发
- [ ] on_near_death: 长度降至阈值 → 触发一次，不重复
- [ ] on_near_death: 长度回升后再降至阈值 → 再次触发
- [ ] on_streak: 连续击杀 → streak_count 递增
- [ ] on_streak: 间隔过长 → streak 重置
- [ ] on_enemy_approach: 敌人移动至蛇段范围内 → 触发
- [ ] on_status_gained: 蛇段获得状态 → 触发
- [ ] on_tile_placed: 放置状态格 → 触发

### T28B 原子

- [ ] modify_food_drop: amount=-1 → 掉落减 1（最低 0）
- [ ] direct_grow: amount=2 → 蛇立即增长 2 段
- [ ] steal_status: 敌人携带 fire → 蛇头获得 fire，敌人清除
- [ ] steal_status: 敌人无状态 → 无效果
- [ ] modify_hit_threshold: value=-1 → 2 hit 即丢段（原 3）

---

## L3+ 预留触发器（本任务不实现）

| 触发器 | 预计用途 | 实现时机 |
|--------|---------|---------|
| on_wall_near | 贴墙 build、地形利用 | L3 地图系统 |
| on_encircle | 围地战术、区域控制 | L3+ |
| on_room_enter | 房间切换事件 | L3 地图系统 |
