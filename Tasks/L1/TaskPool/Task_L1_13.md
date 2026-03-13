## [L1-T13] StatusTile 空间状态格

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P0(阻塞) |
| **前置任务** | L1-T12 |
| **预估粒度** | M(1~3h) |
| **分配职能** | 引擎程序 |

### 概述

创建空间状态格实体（StatusTile），代表地板上的状态效果区域。实体踩入时触发状态转化，到期自动消失。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.3 转化规则（空间→实体） |
| `Designs/General/snake_roguelite_design.md` | §4.4 各状态的空间效果 |
| `Project/data/json/game_config.json` | `status_effects.*.tile_duration` |
| `Project/core/helpers/grid_entity.gd` | GridEntity 基类 |

### 任务详细

1. 创建 `Project/entities/status_tiles/status_tile.gd` — 继承 GridEntity
2. 创建 `Project/entities/status_tiles/status_tile_manager.gd` — 管理所有 StatusTile 的生命周期
3. 在 EventBus 中添加 StatusTile 相关信号
4. 编写测试 `Project/Test/cases/test_t13_status_tile.gd`

**StatusTile 数据字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `status_type` | `String` | 状态类型（"fire"/"ice"/"poison"） |
| `layer` | `int` | 层数（影响视觉强度） |
| `duration` | `float` | 剩余持续时间（秒，从 config `tile_duration` 读取） |
| `color` | `Color` | 显示颜色（从 config `color` 字段读取） |

**StatusTile 核心行为：**

- 在 GridWorld 中注册为 `EntityType.STATUS_TILE`
- 拥有 ColorRect 视觉表现，颜色和透明度根据 `status_type` 和 `layer` 变化
- 每帧/每 tick 更新 `duration`，到期后自动从 GridWorld 移除并 `queue_free()`
- 同一格子可以有多个不同类型的 StatusTile（火+冰可共存以触发反应）
- 同一格子同类型 StatusTile 只能有一个，再次放置时叠层

**StatusTileManager 核心方法：**

| 方法 | 说明 |
|------|------|
| `place_tile(pos, type, layer) -> StatusTile` | 在指定格子放置状态格 |
| `remove_tile(pos, type)` | 移除指定位置的指定类型状态格 |
| `get_tile(pos, type) -> StatusTile` | 获取指定位置的指定类型状态格 |
| `get_tiles_at(pos) -> Array[StatusTile]` | 获取指定位置的所有状态格 |
| `has_tile(pos, type) -> bool` | 检查指定位置是否有某类型状态格 |
| `tick_update(delta)` | 更新所有状态格的计时 |

**需要创建的目录：**
- `Project/entities/status_tiles/`

**需要创建的文件：**
- `Project/entities/status_tiles/status_tile.gd`
- `Project/entities/status_tiles/status_tile_manager.gd`

**需要修改的文件：**
- `Project/autoloads/event_bus.gd` — 添加 StatusTile 信号

### EventBus 新增信号

```gdscript
# === Status Tiles ===
signal status_tile_placed(data: Dictionary)    # { position, type, layer }
signal status_tile_removed(data: Dictionary)   # { position, type }
signal entity_entered_status_tile(data: Dictionary)  # { entity, tile, position, type }
```

### 技术约束

- StatusTile 继承 `GridEntity`（extends GridEntity），在 GridWorld 中有格子坐标
- 视觉大小为 `Constants.CELL_SIZE`（满格覆盖），透明度 0.3~0.6 之间
- StatusTileManager 作为场景节点加入 GameWorld（不作为 Autoload），类似 FoodManager/EnemyManager
- 使用 `Dictionary[Vector2i, Dictionary[String, StatusTile]]` 存储，支持同位置多类型
- `tile_duration` 从 ConfigManager 读取，不硬编码
- 渲染层级：低于实体、高于 GridBackground

### 验收标准

- [ ] `status_tile.gd` 存在，继承 GridEntity
- [ ] StatusTile 有正确的视觉表现（对应颜色的半透明 ColorRect）
- [ ] `place_tile` 能在指定位置创建状态格并注册到 GridWorld
- [ ] 同位置同类型再次 `place_tile` 时叠层而非创建新实例
- [ ] 状态格到期后自动消失并发射 `status_tile_removed` 信号
- [ ] `entity_entered_status_tile` 信号在实体移入状态格位置时触发
- [ ] StatusTile 从 GridWorld 正确注销（不留残影、不影响寻路）
- [ ] 所有测试通过

### 备注

- 实体进入状态格时的具体效果（获得状态）在 T14 实体↔空间转化系统中实现
- StatusTile 的蔓延逻辑（火焰格蔓延）在 T15 中实现
- 渲染层级可通过设置 `z_index` 实现（StatusTile z_index < Snake/Enemy z_index）
