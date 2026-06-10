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
- 当前验证事实（2026-06-11，S2 T2 簇收口）：普通测试 `2969/2969` 断言通过，套件 `68/68`（T004/T006 重写后的断言基数；runner 现核对"发现/运行"数）；严格门禁 `STRICT PASSED`。严格脚本先跑 `--headless --import` 重建 class cache/.uid（导入器输出不进扫描），再跑测试并扫描 stderr，豁免 AtomRegistry 负向测试、lambda capture 清理日志和 headless 退出期资源日志。
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

## L4 配置与契约基线（S2 T1，spec 002 修订版 2026-06-11）

配置事实（`game_config.json`，测试套件 `Project/Test/cases/test_l4_config.gd`）：

- `run.max_floors: 3` **显式取代并删除** `max_floors_v1`（FR-016/SC-009；grep 验证旧键零 GDScript 调用方，无需迁移；`run_progression_system` 在 T022 才消费新键）。
- `floor.generator: "fixed_v1"`，枚举 `fixed_v1 | pcg`（FR-016）；fixed_v1 为回退/MDE 路径。
- 概念节奏纯数据（FR-017/SC-010）：`floor.modifier_weights`（首层全 0，2 层起正权重）、`floor.elite_weights`（首层 0，逐层严格递增）、`floor.shop_guarantee`（`min_combat_rooms_before: 2`，每层保底商店）。
- `shop.price_multiplier_per_floor: 1.25`（FR-003：蜕皮跨层保留，下层物价上涨是唯一经济压力阀）。
- `room_types.shop`（`auto_complete_on_enter: true`，退店无目标门槛）、`room_types.elite`（clear_enemies，不自动完成）。
- `enemy_types.elite_wanderer|elite_chaser|elite_bog_crawler`：`is_elite: true` + `base_type`，复用基础型 shape/color，`visual_scale: 1.25` + `outline_palette_token: "room_elite"`（描边表现留待 UI 卡）；三个基础型显式 `is_elite: false`。精英不入 `enemy.spawn_weights` 常驻池，由 RoomDirector（T021）按 `floor.elite_weights` 注入。
- `difficulty.floor_table`（FR-008 MUST 静态层表：enemy_count 3/4/5、enemy_hp_bonus 0/1/2 严格递增，food_count 不回落）+ `difficulty.reactive`（SHOULD：normalization 分母 room_clear_ticks/damage_taken_per_room/status_usage_per_room + delta clamp，隐性、仅生成参数级验证）。
- `room_modifiers` v1 = `shield_enemies` + `preset_status_tiles`（各带逐项 `enabled` 开关，FR-009）。`darkness`/`speed_strips`/`mine_tiles` 为 6-5 草稿残留键，已入 backlog.md，随 T029/T031/T033 测试重写一并删除（现仍被草稿测试引用，不可先删）。

ConfigManager 新 accessor：`get_max_floors()`、`get_floor_generator()`、`get_floor_modifier_weights(floor)`、`get_floor_elite_weight(floor)`、`get_shop_guarantee()`、`get_shop_price_multiplier_per_floor()`、`get_difficulty_floor_table()`、`get_difficulty_floor_params(floor)`、`get_difficulty_reactive_config()`；楼层键表查询统一走 `_get_floor_keyed_value`（精确命中 → 钳制到 ≤floor 的最高定义层 → 最低定义层）。

L4 事件契约「发射方 → 监听方」对照表（T1 落地信号定义；接线落在标注簇）：

| 信号 | payload | 发射方（计划） | 监听方（计划） |
|------|---------|----------------|----------------|
| `currency_changed` | {currency, amount, total, source} | ShedskinSystem（T2 ✅） | shedskin_display（T2 ✅） |
| `scale_reward_presented` | {room_id, options, offer_id, pool_id} | ScaleRewardSystem（T2 ✅） | scale_choice_panel、RunProgression/FloorProgressPanel 模态门控（T2/T007 ✅） |
| `scale_reward_chosen` | {offer_id, option_id, scale_id, position, level, skipped} | ScaleRewardSystem（T2 ✅） | scale_choice_panel、门控解除（T2 ✅） |
| `scale_option_discarded` | {offer_id, discarded_ids, shedskin_gained} | ScaleRewardSystem（T2 ✅） | ShedskinSystem（discard 收入）、scale_choice_panel、门控解除（T2 ✅） |
| `shop_entered` | {room_id, items} | ShopSystem（T3） | shop_panel（T3） |
| `shop_purchase` | {item_id, category, cost, currency_remaining} | ShopSystem（T3） | ShedskinSystem、shop_panel（T3） |
| `slot_unlocked` | {position, total_slots, source} | SlotExpansionSystem（T3） | Build 面板（T3） |
| `floor_reward_presented` | {floor_index, options} | FloorRewardSystem（T5） | floor_reward_panel、模态门控（T5） |
| `floor_reward_chosen` | {category, option_id, skipped?} | FloorRewardSystem（T5） | RunProgression（决议先于 advance_floor，T027） |
| `difficulty_adjusted` | {reason, adjustment} | DifficultyScaler（T6） | RoomDirector（唯一消费者，T6） |
| `room_modifier_applied` | {room_id, modifier_id} | RoomModifierSystem（T6，经 RoomDirector 应用） | RoomDirector/表现层（T6） |
| `floor_theme_set` | {theme, pressure, floor_index} | FloorMapGenerator/RoomDirector（T4/T5） | 表现层（S4） |

FR-018 显式保留契约：**RewardFlowSystem 为 L3 `reward` 房发射的合成 `room_completed` 是该类房间唯一完成通路（load-bearing），保留不动**；草稿 ScaleRewardSystem 的合成 `room_completed` 是缺陷（幻影二次 offer 根因之一），T005 拆除——拆除范围仅限 ScaleRewardSystem。空选项 offer 一律自动决议（chosen 带 `skipped: true` 或 discarded，FR-014）；任一 `*_presented` 未决时推进请求被忽略（FR-015，T007 落地）。

## L4 鳞片奖励链 + 蜕皮经济事实（S2 T2，T004-T010，2026-06-11）

- `ScaleRewardSystem` 重写落地：战斗房 `room_completed`（`growth.scale_reward.trigger_room_types`）→ 恰 3 选项 offer；
  选择经 `ScaleSlotManager.equip_scale` 装备，**满槽替换**（卸该位置首槽旧鳞再装新鳞）；
  选项按「位置可承载」过滤（有空开放槽或可替换）；**无合成 `room_completed`**（FR-018）；
  决议顺序先清状态再发事件（草稿 :85/:98 幻影二次 offer/软锁根因已修）；
  `set_sampling_bias(Callable)` 传承石偏置钩子留给 L5（收合格选项 Array → 返回重排 Array）。
- 决议事件语义：选择 → `scale_reward_chosen`（skipped=false）+ `scale_option_discarded`（未选 2 项，每项 +`scale_discard`）；
  放弃全部（`discard_offer()`）→ 仅 `scale_option_discarded`（全部选项 × `scale_discard`）；
  空池/零合格 → 仅 `scale_reward_chosen`（skipped=true，不发 `scale_reward_presented`，FR-014）。
- `ShedskinSystem` 修复落地：`enemy_killed` 的 `enemy_def` 按 **Enemy 节点**取 `enemy_type`（草稿当 Dictionary 判型的死代码已修），
  精英判定走 `ConfigManager.get_enemy_type(...).is_elite`；**跨层保留**（`floor_generated` 清零路径已删，FR-003）；
  `run_started` 清零（FR-013）；消费 `scale_option_discarded.shedskin_gained` 入账（source=`scale_discard`）。
- 模态门控（FR-015）落地两处：`RunProgressionSystem._pending_offers` 家族登记
  （reward/scale_reward/floor_reward 三家族，`has_pending_offer()` 公共查询，未决时忽略 `room_advance_requested`）；
  `FloorProgressPanel` 同步登记（Next 按钮禁用 + `request_next_room()` 返回 false，`is_advance_blocked()` 公共查询）。
- `RewardFlowSystem` 回补（FR-014）：零可应用选项时自动决议——发 `reward_chosen`（payload 带 `skipped: true`）+
  合成 `room_completed`（完成通路保留），不发 `reward_presented`；choose 路径同步改为先清状态再发事件。
- UI：`ui/scale_choice_panel.gd` 基于 ui/kit 重建（modal 层 + ui_modal 组；choice_card×3 + 放弃入口
  「放弃全部 +N 蜕皮」，N = 选项数 × `growth.shedskin.scale_discard`）；`ui/shedskin_display.gd` 基于 ui/kit chip 重建
  （hud 层右上角，shedskin glyph + accent_shedskin；**渐进披露**：首次入账 amount>0 才出现）。
  两面板均已去 class_name（按路径加载，ScriptingLeading C.8）。
- `game_world.tscn/gd` 接线：`ShedskinSystem`/`ScaleRewardSystem` 场景节点 + `UI/ScaleChoicePanel`/`UI/ShedskinDisplay`；
  `cleanup()` 扩展。L3 全量回归套件（smoke/acceptance/xp_contracts/stager）已适配鳞片模态：
  战斗房完成 → 决议鳞片 offer → 才能推进。
- JSON 增量：`growth.scale_reward.default_pool: "l1_basic"`（present_offer 缺省池走配置，不写死池 id）。
- 几何探测新增状态 `l4_scale_pending`（state_stager + test_xp_ui_geometry：鳞片模态 + 蜕皮 chip 同屏探测）。
- 测试事实：`enemy_killed` 全局总线 payload 的 `enemy_def` 必须是 Node 派生或 null
  （EnemyManager 按 Node 收参；测试 mock 用 Node2D + enemy_type 属性）。

## L4 槽位扩展 + 商店经济事实（S2 T3，T011-T016，2026-06-11）

- `ScaleSlotManager` 槽位上限 JSON 化（T012）：`MAX_SLOTS` 常量删除，`init_manager` 读
  `growth.slot_expansion.max/initial`；新 accessor `get_max_slots(position)` /
  `get_open_slots(position)`（消费方不得直读 `_open_slots`；`build_test_panel` 已迁移）。
- `SlotExpansionSystem` 重写为**薄适配器**（T012）：不再自持槽位计数，唯一事实源 =
  ScaleSlotManager；`unlock_slot(position, source)` 真调 `open_slot()` 成功才发
  `slot_unlocked {position, total_slots, source}` + 记解锁史；监听 `shop_purchase`
  （category=`slot`，按 item_id 解析位置）走同一通路；草稿监听 `floor_reward_chosen`
  （expansion）属旧奖励模型已拆除——Boss 固定槽位解锁步骤（FR-007）由 T025 经
  `unlock_slot(position, "boss")` 接入。
- `ShopSystem` 修复落地（T014）：**种子 RNG 抽货**（`hash(run_seed:room_id)`，同局同店
  确定性，草稿 :198 pool[0] 伪随机已修）；容量按 `get_open_slots < get_max_slots`
  判定（草稿 :130 误用已装数已修）；**退店通路 = `room_entered`**（进商店房开店、进任何
  其他房关店；商店房 `auto_complete_on_enter: true`，**不注册模态门控**——否则门控 +
  进房退店组合必死锁，spec「allow exit without purchase」）；物价 = `ceil(基准价 ×
  price_multiplier_per_floor^(楼层-1))`（FR-003，监听 `run_started`/`floor_generated`
  取 seed 与楼层）；空货架自动决议（FR-014：零可上架项不发 `shop_entered`、不进 active）。
- 购买语义：scale → 满槽替换装备（与 ScaleRewardSystem 同语义）按 tier 等级；slot →
  只验容量后发 `shop_purchase`，真开槽由 SlotExpansionSystem 事件链完成（FR-011）；
  head/tail upgrade → `equip_head/equip_tail(part_id, level+1)`（已装备且下一等级
  配置存在才上架）。`setup(shedskin, scale_mgr, parts_mgr)`（草稿第 4 个 panel 参数删除，
  表现层只听不驱动）。
- JSON schema 增量（`shop` 段）：`scale_pool: "l1_basic"`（货架鳞片抽样池，草稿 :199
  硬编码池 id 已入配置）、`shelf_plan: {scale: 2, slot: 1, head_upgrade: 1,
  tail_upgrade: 1}`（货架构成纯数据，合计 ≤ `max_items_per_shop: 5`，SC-003 ≥3 项）、
  `item_categories.scale_l1|l2|l3` 增 `level`（tier 等级）、`item_categories.slot_*`
  增 `position`。

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
