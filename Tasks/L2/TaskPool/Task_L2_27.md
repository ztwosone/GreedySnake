## [L2-T27] EffectWindow 时间窗口框架

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L2-基础设施 |
| **优先级** | P0(前置) |
| **前置任务** | T25 (Effect Atom System) |
| **预估粒度** | M(1~3h) |
| **分配职能** | 系统程序 |

### 概述

为 T25 Atom System 新增"持续 N tick 的效果窗口"能力。L2 蛇头/蛇尾的核心机制（无敌窗口、延迟丢段、恢复窗口）均依赖此框架。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §5.3 设计框架（EffectWindow 部分）、§12B 全节 |
| `TechDocs/ScriptingLeading.md` | §3.5.8 T27 技术实现指南 |

### 设计要点

- **不继承 AtomBase** — 窗口有生命周期，原子无状态单例，属于不同抽象层
- **新增 EffectWindowManager** — 有状态管理器，挂在 GameWorld 上
- **2 个新原子** — `open_window`（动作）+ `if_in_window`（条件）
- **完全 JSON 配置** — duration_ticks / rules / on_expire / cancel_on
- **规则覆写被动查询** — 各系统调 `get_rule()` 而非窗口主动推送

### 任务详细

1. 创建 `Project/systems/atoms/effect_window.gd` — EffectWindow 数据类
2. 创建 `Project/systems/atoms/effect_window_manager.gd` — 窗口管理器
   - open_window / cancel_window / is_active / get_rule
   - tick_post_process 连接：递减 → 到期执行 on_expire 链
   - cancel_on 动态信号连接
3. 创建 `Project/systems/atoms/atoms/temporal/open_window_atom.gd` — open_window 原子
4. 创建 `Project/systems/atoms/atoms/condition/if_in_window_atom.gd` — if_in_window 条件原子
5. 修改 `atom_context.gd` — 新增 `window_mgr` 字段
6. 修改 `atom_registry.gd` — 注册 2 个新原子
7. 修改 `trigger_manager.gd` — _build_context 注入 window_mgr
8. 修改 `autoloads/event_bus.gd` — 新增 3 个信号（window_opened/expired/cancelled）
9. 修改 `scenes/game_world.gd` — 实例化 EffectWindowManager
10. 编写测试 `Project/Test/cases/test_t27_effect_window.gd`

### 对接点（T27 本身不改，后续任务改）

| 文件 | 后续任务 | 改动 |
|------|---------|------|
| `enemy.gd:_attack_segment` | T29 蛇头 | 查询 ignore_hit_counter |
| `snake.gd:remove_tail_segment` | T30 蛇尾 | 查询 block_segment_loss |

### 测试清单

- [ ] 开窗口 → tick 递减 → 到期触发 on_expire
- [ ] 同 id 重复开窗口 → 刷新 remaining_ticks（不叠加）
- [ ] cancel_on 信号触发 → 窗口取消不执行 on_expire
- [ ] if_in_window 在窗口内返回 true，窗口外返回 false
- [ ] 多窗口并存互不干扰
- [ ] on_expire 中执行原子链（如 direct_grow）
- [ ] 窗口持有者失效 → 安全清理
- [ ] get_rule 查询：窗口活跃时返回规则值，窗口不存在时返回默认值

### 设计笔记

T27 是 L2 Phase 0 前置基础设施。L2 的 delay_loss / grant_invincibility / mark_recovery_window 不再作为独立原子，而是 open_window 的不同 JSON 配置。这将原来设计中的 6 个新原子缩减为 4 个即时型 + open_window + if_in_window。

L2+ 预留扩展点（on_tick 链、窗口叠加策略）在 EffectWindow 数据模型中预留字段，代码走空路径。
