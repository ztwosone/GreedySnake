## [L0-T03] TickManager 节拍管理器

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P0(阻塞) |
| **前置任务** | L0-T01, L0-T02 |
| **预估粒度** | M(1~3h) |
| **分配职能** | 引擎程序 |

### 概述

创建基于 Timer 的 tick 节拍管理器，驱动整个游戏的离散时间推进。所有游戏实体的移动和结算都在 tick 边界发生。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §2.4 TickManager |

### 任务详细

1. 创建 `Project/autoloads/tick_manager.gd`
2. 在 `project.godot` 中注册为 Autoload，名称 `TickManager`
3. 实现以下功能：

**核心属性：**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `base_tick_interval` | `float` | 从 `Constants.BASE_TICK_INTERVAL` 读取 | 基础 tick 间隔 |
| `tick_speed_modifier` | `float` | `1.0` | 速度修正因子 |
| `is_ticking` | `bool` | `false` | 是否正在 tick |
| `current_tick` | `int` | `0` | 当前 tick 计数 |

**核心方法：**

| 方法 | 说明 |
|------|------|
| `start_ticking()` | 启动 tick 循环 |
| `stop_ticking()` | 停止 tick 循环 |
| `pause()` | 暂停（保留当前状态） |
| `resume()` | 恢复 |
| `get_effective_interval() -> float` | 返回 `base_tick_interval / tick_speed_modifier` |

**每个 Tick 的执行流程（严格顺序）：**

```
1. 发射 EventBus.tick_pre_process({ tick_index: current_tick })
2. 发射 EventBus.tick_input_collected({ tick_index: current_tick })
   → MovementSystem 在此事件中执行蛇移动
   → 蛇移动触发 GridWorld 回调链（碰撞、进入格子等）
3. 发射 EventBus.tick_post_process({ tick_index: current_tick })
   → 敌人 AI 在此事件中决策并移动
   → 状态效果在此事件中结算
4. current_tick += 1
```

**实现方式：** 使用 Godot 的 `Timer` 节点或在 `_process()` 中手动累计 delta。推荐 `Timer`，因为可以方便地 `stop()` / `start()` 实现暂停。

**需要创建的文件：**
- `Project/autoloads/tick_manager.gd`

**需要修改的文件：**
- `Project/project.godot` — 添加 TickManager Autoload

### 技术约束

- 继承 `Node`
- tick 间隔从 `Constants.BASE_TICK_INTERVAL` 读取，不硬编码
- `tick_speed_modifier` 为预留接口（MVP 中固定为 1.0，后续被冰冻等效果修改）
- 三个 tick 事件（pre_process → input_collected → post_process）必须在同一帧内同步顺序发射，不允许跨帧
- `start_ticking()` 时重置 `current_tick = 0`

### 验收标准

- [ ] `tick_manager.gd` 存在且已注册为 Autoload
- [ ] 调用 `start_ticking()` 后，每 0.25 秒按顺序发射三个 tick 事件
- [ ] 三个事件的 `tick_index` 参数值一致且递增
- [ ] 调用 `pause()` 后不再触发新 tick
- [ ] 调用 `resume()` 后恢复 tick
- [ ] 调用 `stop_ticking()` 后完全停止且 `current_tick` 不再递增
- [ ] 可通过连接 `EventBus.tick_post_process` 信号来验证 tick 循环正常运行（打印日志即可）

### 备注

- MVP 阶段只需要固定速度 tick，不需要处理 `tick_speed_modifier` 的动态变化逻辑（但属性要预留）
- Tick 的三阶段设计是为了保证执行顺序：输入先于移动，移动先于结算。后续如果需要更精细的阶段，可在 pre/post 之间插入新阶段
