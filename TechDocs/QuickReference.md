# 事实摘要 — 当前实现状态速查

> 本文件是设计文档的精简索引。修改设计文档或代码后必须同步更新。
> 完整设计见 `Designs/General/snake_roguelite_design.md` 和 `TechDocs/ScriptingLeading.md`。

## 项目概述

Godot 4.6 + GDScript 贪吃蛇 Roguelite。Grid-based、Tick-driven、Event-driven、Data-driven。

## 里程碑进度

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| L0 | 基础移动 + 长度 + 食物 | ✅ 完成 |
| L1 | 战斗循环 + per-segment status + T25 Atom System | ✅ 完成（1030 测试） |
| L2-Phase0 | T27A StatusCarrier + ReactionResolver + CollisionHandler | ✅ 完成（1082 测试） |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | ✅ 完成 T27A~T33（1518 测试） |
| L2.5 | Virtual Player 自动化测试基础设施 | ✅ 完成 |
| L3 | 完整一局：地图 / 房间 / 奖励 / 终局 | ✅ v1 完成并已提交（RunState、FloorMap、房间流程、奖励选择、楼层推进、终局、占位 UI smoke） |
| L4 | 成长循环（蜕皮/鳞片奖励/槽位/商店/PCG/难度） | 🟡 2026-06-05 草稿已提交在库：**零场景集成、任务 0 勾选、已知逻辑缺陷**，待按 spec 002 逐卡重验收 |
| L5 | 元成长（解锁/传承石/拾取/user:// 存档） | 🟡 同上，待按 spec 003 重验收；`run_ended` 生产代码无发射方 |
| 体验层 | 程序化美学 + 游戏手感（SpecKit 004） | 📋 已规划：设计文档 `Designs/Interactive/presentation_design.md` 先行 |

## 核心配置

```
Project/data/json/game_config.json    # 核心配置（grid/tick/snake/food/enemy/status/reactions）
Project/autoloads/event_bus.gd        # 全局事件定义
Project/systems/atoms/atom_registry.gd # T25 原子注册表（68 原子，24 触发器）
Project/ui/build_test_panel.gd        # T33 Build 测试面板（B 键切换）
Project/systems/status/reaction_resolver.gd  # T27A 反应查表引擎
Project/systems/status/collision_handler.gd  # T27A 碰撞统一处理器
AgentOps/                         # 会话无关 Agent 统筹控制面
Tools/run_tests_strict.ps1        # 严格测试包装器（扫描 Godot 错误输出）
.specify/specs/001-l3-run-loop/   # L3 完整一局 SpecKit 规格
Project/Test/cases/test_l3_run_loop.gd       # L3 配置/事件契约测试
Project/systems/run/run_progression_system.gd # L3 run 生命周期状态机
Project/systems/rooms/floor_map_generator.gd  # L3 v1 固定短路径房间地图生成器
Project/Test/cases/test_l3_room_flow.gd      # L3 US1 房间进入/完成测试
Project/systems/rooms/room_flow_system.gd    # L3 房间生命周期与目标进度
Project/ui/room_intent_panel.gd              # L3 房间意图/进度占位 UI
Project/Test/cases/test_l3_rewards.gd        # L3 US2 奖励展示/选择/Build 应用测试
Project/systems/rewards/reward_flow_system.gd # L3 奖励 offer、选择和 Build 接入
Project/ui/reward_choice_panel.gd            # L3 奖励选择占位 UI
Project/Test/cases/test_l3_floor_progression.gd # L3 US3 楼层推进/进度 UI 测试
Project/ui/floor_progress_panel.gd           # L3 楼层进度占位 UI
Project/Test/cases/test_l3_run_end.gd        # L3 US4 终局/死亡/cleanup 测试
Project/Test/cases/test_l3_smoke_run.gd      # L3 v1 固定路径占位 UI smoke run
```

- CELL_SIZE = 32，网格 40×22
- Tick = 0.25s
- 测试入口：`res://Test/test_runner.tscn`
- 严格测试入口：`$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File Tools/run_tests_strict.ps1`
- 当前验证事实（2026-06-11，Phase F 完成）：普通测试 `2897/2897` 断言通过，套件 `67/67`（runner 现核对"发现/运行"数）；严格门禁 `STRICT PASSED`。严格脚本先跑 `--headless --import` 重建 class cache/.uid（导入器输出不进扫描），再跑测试并扫描 stderr，豁免 AtomRegistry 负向测试、lambda capture 清理日志和 headless 退出期资源日志。
- 测试约定：禁止裸引用全局 class_name，一律 `const XxxScript := preload(...)`（见 ScriptingLeading 附录 C.8）；坏套件计 FAIL 不再静默吞测（2026-06-05 的"ALL PASSED 758/758"假绿根因已修复）。

## 表现内核事实（SpecKit 004 Phase F，2026-06-11）

- 设计文档：`Designs/Interactive/presentation_design.md`（「网格信号」，表现层 source of truth）。
- `game_config.json` 新增 `presentation` 段：palette（20 token）/typography/motion（tick 量化）/layout/glyphs/acceptance/game_feel/audio/hints/death_causes/debug_ui；ConfigManager 全套 accessor。
- `Project/ui/kit/`：theme_builder（JSON→Theme + 对比度对 + WCAG contrast_ratio）、kit_panel（角括号框基类，出生带 ui_kit 分组/ui_layer 元数据/settle()/track_tween/register_hit_target）、glyph（_draw 零子节点数据驱动图标）、choice_card/banner/chip（零编排组件态）。
- 仪表缝：TickManager `manual_mode`+`step_once()`（pause 期间步进无效）；VFXManager `vfx_invoked` 信号 + 参数 JSON 化 + 新效果 shatter_at/ring_at/fly_to_hud。
- 体验验收基建 `Project/Test/experience/`：experience_recorder（四通道时间线+pending modal 栈）、tick_driver（模态感知手动步进）、ui_actor（playbook 驱动面板公共 API）、ui_settle、ui_geometry_probe（几何五项+有效底色对比度，dry_run 自测）、state_stager（典型状态装配）。
- L3 三面板 + title/game_over/hud 已迁移 kit 设计语言；debug UI（kill_feed/debug_panel/build_test_panel/event_log_panel + T/Y 捷径）收进 `presentation.debug_ui` 开关（默认关）。
- banner 文字色按对比度自动选深/浅（金色底配深字）；banner 副标题用 HeadingLabel（body 字号在 room_combat 上对比 4.48 < 4.5，banner 按 large 阈值设计）。

## AgentOps 统筹事实

- 仓库长期记忆放在 `AgentOps/`，新会话必须从 `AgentOps/README.md` 启动。
- L3+ 默认由 Orchestrator Agent 派发单任务卡；Implementer 不自行扩大范围。
- 当前阶段路线：S0 稳定化 ✅ → S1 体验设计文档+表现内核（SpecKit 004 Phase F）→ S2 L4 重验收（spec 002）→ S3 L5（spec 003）→ S4 体验完成层（004 Phase P）→ S5 封板。S2/S4 按 US 合 main，其余按 Stage 合 main。
- 安全快照：`snapshot/2026-06-10-raw-worktree` 保存 6-05 草稿原始状态，永不合并。
- 设计门禁：体验深度、认知轻度；美术/UI 占位将由 SpecKit 004 表现内核替换为统一设计语言。
- 治理规则：改 EventBus 契约或 JSON schema 的提交，必须同一提交内含 QuickReference 增量。

## L3 Foundation 事实

- `game_config.json` 新增 `run` / `floor` / `room_types` / `rewards` / `endpoint` 配置。
- ConfigManager 新增 L3 访问器：`get_run_config()`、`get_floor_config()`、`get_room_type()`、`get_reward_pool()` 等。
- EventBus 新增 L3 信号：`run_started`、`floor_generated`、`room_entered`、`room_completed`、`reward_presented`、`reward_chosen`、`floor_completed`、`run_victory` 等。
- `RunProgressionSystem` 已支持 start/victory/death/cleanup 生命周期、当前房间查询、可进入房间列表、房间完成后解锁下一房间，以及 `advance_to_room(room_id)` 显式推进。
- `RunProgressionSystem` 只接受当前可进入房间的 completion，监听 `room_advance_requested` 进入下一房间，监听 `snake_died` 同步 death outcome，并在 endpoint 完成时发出 `floor_completed` / `run_victory`。
- `FloorMapGenerator` 已支持从 JSON `floor.fixed_v1_path` 生成确定性短路径房间图，房间类型、意图、目标和占位颜色来自 JSON。
- `RoomFlowSystem` 已支持进入当前房间、监听既有 `enemy_killed` 事件推进 `clear_enemies` 目标、发出 `room_objective_progressed` 和单次 `room_completed`。
- `RoomIntentPanel` 已作为功能占位 UI 接入 `game_world.tscn`，显示房间意图、目标进度和完成状态；正式美术可后续替换节点表现。
- L3 v1 战斗房当前配置为 `required_count=3` 且 `enemy_count=3`，这是 JSON 数值，不写死在系统代码中，避免“清空敌人”提前完成。
- `RewardFlowSystem` 已支持从 JSON `rewards.pools.starter_build` 生成最多 3 个可应用选项，监听配置的 `rewards.trigger_room_types`；v1 从 `reward` 房进入触发，选择后完成奖励房，并通过既有 `SnakePartsManager` / `ScaleSlotManager` 应用 head/tail/scale 奖励。
- `RewardChoicePanel` 已作为功能占位 UI 接入 `game_world.tscn`，使用按钮、文本标签和色块表达奖励选择与已选择反馈。
- L3 v1 奖励先复用既有 Build 系统，单次展示最多 3 个选项。
- `FloorProgressPanel` 已作为功能占位 UI 接入 `game_world.tscn`，使用色块和文本展示固定路径进度、当前房间意图和完成状态。
- `FloorProgressPanel` 已支持 Next 按钮/`request_next_room()`，通过 EventBus `room_advance_requested` 请求进入下一可用房间；UI 不直接修改 run state。
- `rest` 与 `endpoint` v1 通过 JSON `auto_complete_on_enter` 自动完成，避免 L3 v1 引入额外休整系统或 Boss 机制。
- `test_l3_smoke_run.gd` 已验证真实 `game_world.tscn` 能通过占位 UI 跑完固定一局：战斗 → 奖励 → 战斗 → 休整 → endpoint → victory/game over。
- `game_world.gd` 的 L3 子节点引用使用 `get_node_or_null()`，继承的 L1/L2 验收场景可以不带 L3 节点进树。
- `game_world.cleanup()` 已清理 L3 state、Build state、window state，以及 `TriggerManager` 对场景级 enemy/food/window manager 的引用；`VFXManager` 会在旧 VFX 层失效后重建。

## L1 战斗循环关键事实

- **吃敌人无消耗** — 蛇头碰敌人 = 直接吞噬，不扣长度；若蛇头与敌人携带异类状态则触发反应、双方状态清除
- **所有击杀方式均掉食物** — 蛇头吞噬、火光环、反应伤害
- **Per-Segment Status** — 每个 SnakeSegment 实现 StatusCarrier 接口，持有 `_statuses: Array[String]`（兼容 `carried_status` getter）
- **段对象持久化** — 蛇移动时所有段对象向前移动一格（不创建/销毁），状态自然跟随段走
- **空身躯防御早退** — `Snake.move()` 在 `body` 为空时直接 return（生命周期残留防御：销毁中的蛇在 queue_free 落地前仍连着 tick 信号）；仅剩蛇头的无身体倒计时态（`body.size() == 1`）照常移动（ScriptingLeading §3.1.3 步骤 0，回归测试在 test_t06_snake）
- **敌人攻击蛇身** — 敌人 P0 优先级，累计 3 次命中丢 1 段（hits_per_segment_loss=3）
- **双向状态转移** — 敌人攻击蛇段时双方状态互换/触发反应
- **敌人携带状态颜色** — 敌人携带 fire/ice/poison 时显示对应叠层颜色（fire=橙边框闪烁+overlay, ice=蓝overlay, poison=绿脉动overlay）
- **状态格永久存在** — L1 中无持续时间递减
- **同位异类互斥** — 放置状态格时已有不同类型 → 反应 + 双方消除
- **蛇基础颜色白/灰** — HEAD=0.95, BODY=0.78, TAIL=0.6 灰度
- **碾压（crush）已移除** — 蛇身段不再主动攻击敌人

## L2 架构决策

- **StatusCarrier 统一载体 + ReactionResolver 反应引擎（T27A）** ✅ 已实现
  - 蛇段/敌人/状态格统一实现 StatusCarrier 接口（`_statuses: Array[String]` + 兼容 getter）
  - CollisionHandler 统一处理 5 种碰撞类型，JSON `collision_rules` 驱动
  - ReactionResolver JSON 驱动反应规则（替代 3 处 `_get_reaction_id`）
  - `game_config.json` 新增 `collision_rules` 节
  - EventBus 新增 `status_added_to_carrier` / `status_removed_from_carrier` 信号
- **统一 Atom Chain** — 蛇头/蛇尾/蛇鳞三套系统统一使用 T25 Effect Atom System
- 复用 EffectChainResolver → TriggerManager → AtomExecutor 管线
- **EffectWindow 时间窗口框架（T27）** ✅ 已实现 — 为 Atom System 新增"持续 N tick"能力
  - 新增 EffectWindowManager（有状态管理器）+ open_window / if_in_window 原子
  - 窗口期内规则覆写（ignore_hit_counter / block_segment_loss 等）由各系统主动查询
  - 到期执行 on_expire 原子链，cancel_on 条件取消不触发到期链
  - 完全 JSON 配置，零代码扩展；新增 3 个 EventBus 信号
- **新增触发器 7 个（T28A）** ✅ 已实现 — 补全操作维度和资源维度
  - 高：on_length_change（长度增减）、on_turn（转弯）、on_near_death（濒死）
  - 中：on_streak（连杀）、on_enemy_approach（敌人靠近）、on_status_gained（获得状态）、on_tile_placed（状态格放置）
- **新增即时原子 4 个（T28B）** ✅ 已实现：modify_food_drop, direct_grow, steal_status, modify_hit_threshold；Snake.request_grow() 新增
- **SnakePartsManager + 蛇头链（T29）** ✅ 已实现
  - SnakePartsManager 管理蛇头装备/卸载，SnakePartData 兼容 TriggerManager duck typing
  - Hydra（九头蛇）：受击阈值-1、不掉食物、直接增长、窃取状态、L3回声咬
  - Bái Shé（白蛇）：击杀开无敌窗口、L2+反击冰冻、L3到期爆发状态
  - 新增 area_damage + burst_carried_status 原子（总数 57）
  - StatusEffectManager 持久修改器：hit_threshold / food_drop
  - Snake.take_hit() 集成无敌窗口查询
  - ConfigManager 新增 snake_heads 段 + get_snake_head()
- **蛇尾链（T30）** ✅ 已实现
  - Salamander（火蜥蜴尾）：段丢失后恢复窗口，L2+恢复时尾段获火，L3回复量+1
  - Lag Tail（滞后尾）：block_segment_loss 窗口 → 延迟段丢失，L2取消时减 hits_taken，L3蛇尾获冰
  - 新增 request_segment_loss + modify_hits_taken + cancel_window 原子（总数 60）
  - EffectWindow 新增 on_cancel 链：窗口被信号取消时执行
  - LengthSystem 集成 block_segment_loss 窗口规则查询
  - ConfigManager 新增 snake_tails 段 + get_snake_tail()
- **ScaleSystem 蛇鳞槽位（T31）** ✅ 已实现
  - ScaleSlotManager 管理 front/middle/back 三位置（最大 2/3/2 槽，初始 1/1/1）
  - 9 鳞片 × 3 级，全 JSON + Atom Chain 驱动
  - 前段：greedy_scale（食物掉落）、predator_scale（窃取+扩散状态）
  - 中段：flame_scale（火光环增强）、toxin_scale（毒蔓延加速）、frost_scale（攻击冷却）、phantom_scale（幻影尾段）
  - 后段：thorn_scale（击退）、regen_scale（概率增长）、retaliation_scale（反伤）
  - 新增 6 原子（总数 66）：modify_system_param, damage_attacker, knockback_attacker, knockback_with_damage, spread_status_to_segments, ice_wave
  - StatusEffectManager 新增 6 修改器：fire_aura_damage/range, poison_spread_bonus/tile_damage, attack_cooldown_bonus, phantom_tail_count
  - SegmentEffectSystem：曼哈顿距离火光环 + 毒格伤害
  - EnemyBrain：幻影尾段过滤
- 蛇鳞效果也走 Atom Chain，不再有独立的 Condition/Action 系统
- **邻接共鸣系统（T32）** ✅ 已实现
  - Tag-pair 驱动 + scale-pair override 混合架构
  - ResonanceManager 监听鳞片装备/卸载，自动计算邻接共鸣
  - 位置级邻接：front↔middle、middle↔back、同位置互邻；front↔back 不邻接
  - 11 个 tag-pair 共鸣：沸毒(fire+poison)、蒸腾(fire+ice)、冻疫(ice+poison)、炎棘(fire+physical)、冰刺(ice+physical)、毒棘(poison+physical)、幽焰(fire+void)、毒影(poison+void)、焚食(fire+recovery)、寒餐(ice+recovery)、铁壁(physical+physical)
  - 同 tag 不共鸣（physical 除外，铁壁）；多 tag 鳞片可触发多个共鸣
  - 新增 2 原子（总数 68）：apply_status_in_radius, place_tile_at_attacker
  - ConfigManager 新增 tag_resonances + scale_resonance_overrides 双向查找
  - EventBus 新增 resonance_activated / resonance_deactivated 信号
  - 发现机制：首次激活 is_new_discovery=true（预留 UI 提示）
- **全系统联调 + Build 测试面板（T33）** ✅ 已实现
  - Build 测试面板（B 键）：实时显示头/尾/鳞/共鸣/修改器/窗口状态
  - 热键装备：H=蛇头, J=蛇尾, F/G/K=前/中/后鳞, L=升级, 0=清空
  - game_world.cleanup()：修复重开游戏时 TriggerManager/修改器/窗口泄漏
  - main.gd：queue_free 前调用 cleanup 确保跨系统状态清理
  - 集成测试：修改器叠加、共鸣联动、清理正确性、配置一致性

## 敌人类型（L1）

| 类型 | 行为 | 攻击冷却 | 掉落食物 |
|------|------|----------|----------|
| wanderer | 随机移动，无视状态格 | 3 ticks | 2 |
| chaser | 追踪蛇身段，回避状态格 | 2 ticks | 3 |
| bog_crawler | 趋向毒液格，死亡留毒 | 4 ticks | 4 |

## 状态效果（L1，仅 fire/ice/poison）

| 状态 | 蛇段效果 | 状态格效果 |
|------|----------|-----------|
| fire | 火光环：相邻格敌人受火属性伤害（异类状态触发反应） | 踩入获火，蔓延 |
| poison | 毒蔓延：每个毒段每 3 tick 向随机邻格蔓延一格毒 | 踩入获毒 |
| ice | 冰防御：被攻击时攻击者获冰 | 踩入获冰 |

## 反应（L1，仅 3 种）

| 反应 | 组合 | 敌伤 | 蛇自伤 |
|------|------|------|--------|
| steam | fire+ice | 2 | 1 格 |
| toxic_explosion | fire+poison | 3 | 2 格 |
| frozen_plague | ice+poison | 0 | 0 |
