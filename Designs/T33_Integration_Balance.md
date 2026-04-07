# T33: 全系统联调 + 数值平衡

> **前置：** T29-T32 全部完成（1429 测试）
> **目标：** 修复跨系统生命周期 bug、覆盖多系统联动测试、验证配置一致性

---

## 1. 问题分析

### 1.1 已确认的 Bug：生命周期泄漏

**现象：** `main.gd._cleanup_game_world()` 只调用 `queue_free()` + `GridWorld.clear_all()`，
但 `StatusEffectManager` 是全局单例，其内部状态不随 game_world 销毁而重置。

**泄漏链：**

```
_cleanup_game_world()
  ├─ game_world.queue_free()     → 子节点（SnakePartsManager, ScaleSlotManager, ResonanceManager）延迟释放
  ├─ GridWorld.clear_all()       → 格子清空
  └─ ❌ StatusEffectManager      → _trigger_manager._active_entries 残留旧 SnakePartData
                                 → _active_modifiers 残留旧数值
                                 → EffectWindowManager 残留旧窗口
```

**后果：** 重新开始游戏后，旧部件的 Atom Chain 仍注册在 TriggerManager 中，
旧修改器值叠加到新游戏，产生幽灵效果。

### 1.2 测试空缺

当前所有 T29-T32 测试都是**单系统单元测试**，缺少：

- 头 + 尾同时装备的修改器叠加
- 鳞片装备触发共鸣激活
- 全套配装（头+尾+多鳞+共鸣）协同
- 装备热替换（先卸后装）的修改器正确性
- 系统级清理（clear_all）后的状态归零

### 1.3 误报排除

以下问题经代码验证为**不存在**：

| 疑似问题 | 结论 | 理由 |
|----------|------|------|
| 修改器覆写冲突 | ❌ 不存在 | `modify_system_param_atom` 用 `old + value` 叠加，同参数多源正确累加 |
| 装备时序竞态 | ❌ 不存在 | GDScript 单线程，`fire_on_applied` 顺序执行，每次 get 读到最新值 |
| 窗口规则污染 | ❌ 当前不触发 | 头/尾打开的窗口有不同 ID 和不同 rule，不会交叉查询 |

---

## 2. 修复方案

### 2.1 game_world 退出清理

在 `game_world.gd` 新增 `cleanup()` 方法，在 `main.gd._cleanup_game_world()` 中于 `queue_free()` 前调用：

```
game_world.cleanup():
  1. ResonanceManager.clear_all()        # 停用所有共鸣，注销链
  2. ScaleSlotManager.clear_all()        # 卸载所有鳞片，注销链
  3. SnakePartsManager.unequip_head()    # 卸载蛇头
  4. SnakePartsManager.unequip_tail()    # 卸载蛇尾
  5. EffectWindowManager.clear_all()     # 关闭所有窗口
  6. StatusEffectManager.clear_all()     # 清空 TriggerManager + 修改器 + 状态
```

**顺序重要性：** 共鸣依赖鳞片 → 先清共鸣再清鳞；鳞/头/尾的 `on_removed` 需要 TriggerManager 还活着 → StatusEffectManager 最后清。

### 2.2 main.gd 调用时机

```gdscript
func _cleanup_game_world() -> void:
    if _current_game_world and is_instance_valid(_current_game_world):
        if _current_game_world.has_method("cleanup"):
            _current_game_world.cleanup()       # ← 新增：先清理跨系统状态
        _current_game_world.queue_free()
        _current_game_world = null
    GridWorld.clear_all()
```

---

## 3. 集成测试设计

### 3.1 测试文件

`Project/Test/cases/test_t33_integration.gd`

### 3.2 测试用例

#### A 组：修改器叠加（~12 断言）

| 用例 | 验证内容 |
|------|----------|
| 头+鳞同参数叠加 | Hydra(`hit_threshold=-1`) + 装备鳞片后，`get_modifier("hit_threshold")` = -1 |
| 双鳞同参数叠加 | 2 个 flame_scale L1 装备后，`fire_aura_damage` = 2.0 |
| 装备后卸载归零 | 装备 flame_scale → 卸载 → `fire_aura_damage` 回到 0.0 |
| 头+尾+鳞三源叠加 | Hydra(`food_drop=-99`) + greedy_scale(`food_drop=+1`) → `food_drop` = -98 |

#### B 组：共鸣联动（~10 断言）

| 用例 | 验证内容 |
|------|----------|
| 邻接鳞自动共鸣 | front:predator + middle:flame → `fire+fire`=skip, 但 predator 有 [fire,ice,poison] tags → 检查 fire 相关共鸣 |
| 非邻接无共鸣 | front:scale + back:scale → 不触发共鸣 |
| 卸载后共鸣消失 | 装备两鳞触发共鸣 → 卸载其一 → 共鸣停用 |
| 共鸣链正确解析 | 激活的共鸣 SnakePartData 有非空 chains |

#### C 组：清理正确性（~10 断言）

| 用例 | 验证内容 |
|------|----------|
| cleanup 全流程 | 装备头+尾+鳞+共鸣 → cleanup() → 所有 modifier=0, 无活跃共鸣, 无活跃部件 |
| cleanup 后重装备 | cleanup() → 重新装备 → 修改器值正确（无幽灵叠加） |
| TriggerManager 无残留 | cleanup() 后 `_trigger_manager._active_entries` 为空 |

#### D 组：配置一致性（~15 断言）

| 用例 | 验证内容 |
|------|----------|
| 所有鳞片 on_removed 对称 | 每个 scale 的 on_applied 中 modify_system_param 的 value，在 on_removed 中有对应负值 |
| 所有头/尾 on_removed 对称 | 同上 |
| 共鸣配置完整性 | 每个 tag_resonance 有 resonance_id、display_name、entity_effects |
| 鳞片 tags 覆盖 | 每个 scale 都有 tags 字段且非空 |
| 鳞片位置合法 | 每个 scale 的 position ∈ {front, middle, back} |
| 等级渐进 | 每个 scale 的 L2 效果 ≥ L1 效果（数值非递减） |

**预计新增测试：~47 个断言**

---

## 4. 不在范围内

以下内容属于 L3+，T33 不做：

- 数值平衡调整（需要可玩 loop 后才能调参）
- 动态难度调整
- 敌人 AI 对蛇部件的反应
- 性能优化（当前规模不需要）

---

## 5. 交付清单

| 产出 | 文件 |
|------|------|
| game_world 清理方法 | `Project/scenes/game_world.gd` → `cleanup()` |
| main.gd 调用修复 | `Project/scenes/main.gd` → `_cleanup_game_world()` |
| 集成测试 | `Project/Test/cases/test_t33_integration.gd` |
| 文档同步 | `TechDocs/QuickReference.md`, `Tasks/L2/L2_Overview.md` |
