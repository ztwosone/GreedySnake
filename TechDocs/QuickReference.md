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
- `difficulty.floor_table`（FR-008 MUST 静态层表：enemy_count 3/4/5、enemy_hp_bonus 0/1/2 严格递增，food_count 不回落）+ `difficulty.reactive`（SHOULD：normalization 分母 room_clear_ticks/damage_taken_per_room/status_usage_per_room + delta clamp，隐性、仅生成参数级验证）。T030 增量：`overperform_threshold: 0.75`（0.7 恰为「秒清零受击零状态」驱动器分数 0.4+0.3 的浮点临界，全 world 测试会抖）、`min_food_count: 0`（食物可被压到零）、死键 `baseline_food_count` 删除（食物静态基数 = floor_table.food_count）。
- `room_modifiers` 恰为 v1 双件 = `shield_enemies` + `preset_status_tiles`（各带逐项 `enabled` 开关，FR-009）；schema = `params`（应用参数）+ `visual`（表现参数），草稿 `apply_chains/remove_chains/visual_config` 键废弃。`darkness`/`speed_strips`/`mine_tiles` 草稿残留键已随 T029/T031 删除（backlog.md 收容，`test_l4_config` 文本级断言零残留）。

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
| `floor_reward_presented` | {reward_id, floor_index, source_room_id, step: "slot_unlock"\|"choice", slot_options, options} | FloorRewardSystem（T5b ✅，Boss 结算两段各发一次） | floor_reward_panel、RunProgression/FloorProgressPanel 模态门控（T5b ✅） |
| `floor_reward_chosen` | {floor_index, category, option_id, skipped} | FloorRewardSystem（T5b ✅，skipped=true 为空选项自动决议 FR-014） | RunProgression（决议先于 advance_floor/floor_generated，T027 ✅）、floor_reward_panel 收面板 |
| `difficulty_adjusted` | {reason, adjustment: {score, floor_index, enemy_delta, food_delta, reactive_enemy_delta, reactive_food_delta}} | DifficultyScaler（T030 ✅，每 rooms_between_adjustments 房重算时发射） | 监听方为空——RoomDirector 经 duck-typed 钩子拉取（唯一消费者），事件供表现层/调试观测（S4） |
| `room_modifier_applied` | {room_id, modifier_id} | RoomModifierSystem（T031 ✅，经 RoomDirector 注入点应用） | 表现层（S4）；测试观测 |
| `floor_theme_set` | {theme, pressure, floor_index} | RoomDirector（T5a ✅，生成器保持纯函数） | 表现层（S4） |

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
- 固定路径增商店房（T016/MDE）：`floor.fixed_v1_path = [combat_01, reward_01, combat_02,
  shop_01, rest_01, endpoint_01]`（6 房，`rooms_per_floor: 6`）；shop_01 排在 2 个战斗房后
  （FR-017 商店保底在 fixed_v1 档的体现），F5 即可走到买槽。L3 回归套件
  （acceptance/smoke/floor_progression/run_end/xp_contracts/T010）已适配 6 房路径。
- `game_world.tscn/gd` 接线（T016）：`ShopSystem`/`SlotExpansionSystem` 场景节点 +
  `UI/ShopPanel`；`shop_system.setup(shedskin, scale_slot_mgr, snake_parts_mgr)`、
  `slot_expansion_system.setup(scale_slot_mgr)`、`shop_panel.setup(shop_system)`；
  `cleanup()` 扩展。买槽端到端：面板 purchase → `shop_purchase` → 适配器 `open_slot` →
  新槽可装备可共鸣（e2e 用例 `test_l4_shop._test_game_world_shop_chain`）。
- 几何探针实证缺陷顺手修（T016）：`RewardChoicePanel` 决议后的「已选择」反馈面板
  原本悬挂不收，离开奖励房进商店时构成双模态重叠；现监听 `room_entered`——
  进入非奖励触发房且无待决选项时收起（奖励房本身由 `reward_presented` 接管，
  RewardFlow 在同一派发中先行，顺序安全）。
- 几何探测新增状态 `l4_shop_open`（state_stager + test_xp_ui_geometry：两战斗一奖励
  走到 shop_01，ShopPanel 货架 + 蜕皮 chip 同屏探测）。

## L4 Seeded PCG 楼层生成事实（S2 T4，T018-T019，2026-06-11）

- `FloorMapGenerator` 重写为双档（FR-016）：`floor.generator == "pcg"` 走 seeded PCG，
  否则 fixed_v1 固定路径（回退/MDE 档，输出与 L3 验收完全一致；草稿「楼层 1 无条件短路
  固定路径、2 层起无视开关走 PCG」已修——开关全权决定档位）。`generate_floor(floor_index,
  run_seed)` 返回 map 新增 `generator` 字段标记实际档位。
- **种子推导（SC-011）**：每层 RNG 种子 = `hash("run_seed:floor_index")`，同 run 不同楼层
  独立可复现；与 ShopSystem `hash(run_seed:room_id)` 派生约定一致。RNG 调用顺序固定
  （① 主题 → ② 主路径房数 → ③ 自由槽房型 → ④ 中段洗牌 → ⑤ 商店插位 → ⑥ 支线房 →
  ⑦ 精英升格 → ⑧ 修饰符），重排即改变同种子输出。
- **结构保证（构造即性质）**：起点 = combat、终点 = boss 恰一间且为图终点（死端）；
  每层恰一间商店且所有 start→shop 路径途经 ≥ `shop_guarantee.min_combat_rooms_before`
  个战斗类房（combat/elite，SC-010——经预留中段战斗槽 + 插位下界构造保证）；奖励房
  ≥ `floor.pcg.min_reward_rooms`；主路径 `exits[0]` = 下一主路径房，支线房挂主路径房
  exits 末尾且为死端（全房可达）。精英升格 = combat 房按 `floor.elite_weights` 概率
  转 elite（起点/boss 豁免）；修饰符按 `floor.modifier_weights` 逐项概率附加到战斗类房，
  尊重 `room_modifiers.<id>.enabled` 逐项开关（FR-009）；首层两权重全 0（FR-017）。
- JSON schema 增量：`floor.pcg`（`main_rooms` 楼层键表 {min,max} 主路径房数、
  `min_reward_rooms`、`middle_type_weights`、`side_room_chance`、`max_side_rooms`、
  `side_type_weights`——草稿 :54-84 魔数全部清除，FR-010）；`room_types.boss`
  （clear_enemies、required/enemy_count 1、`is_boss: true`、不自动完成；US4 boss endpoint，
  Boss 结算消费在 T024-T027）。房 dict 新增 `modifiers: Array`（fixed_v1 档恒空）。
- ConfigManager 新 accessor：`get_pcg_config()`、`get_pcg_main_room_bounds(floor)`
  （楼层键表，钳制语义同 `_get_floor_keyed_value`）。
- 测试事实：`test_l4_pcg_rooms.gd` 重写为性质测试（定种子全等 var_to_str 比对、变种子
  10 取 ≥9 异图、BFS 全房可达、DFS 枚举 start→shop 全路径验战斗保底、房数边界 =
  main_rooms ± max_side_rooms、首层零精英零修饰 + 权重拉满反证数据通路 + 逐项 disable）；
  测试通过改写 `ConfigManager.floor`/`room_modifiers` 段并还原来驱动数据反证。

## L4 多层推进 + RoomDirector 事实（S2 T5a，T020-T023，2026-06-11）

- `EnemyManager` 增量改造（T020，默认行为与 L1/L2 完全一致）：
  `respawn_policy = "maintain"`（默认，击杀即补怪维持 `max_enemy_count`）|
  `"room_budget"`（生成既定一批不补怪，RoomDirector 用）；`spawn_budget`（room_budget
  档剩余可生成数，-1 不限，`spawn_enemy` 成功消耗 1、归零拒绝；`spawn_enemy_at`
  为脚本定点放置**不消耗**——l1/l2 验收场景用法）；`set_spawn_weights(Dictionary)`
  注入权重表（空表回退 `enemy.spawn_weights`，权重按 float 累计）。
- `RoomDirector`（T021，`systems/rooms/room_director.gd`，game_world.tscn 常驻节点）：
  `floor_generated` → 缓存楼层/主题并发 `floor_theme_set`（主题空不发——fixed_v1 档）；
  `room_entered` → 清场（clear_enemies/clear_foods）→ 重新布怪布食：仅 `clear_enemies`
  目标房有敌（预算 = 房 dict `enemy_count` + 难度 delta，钳入
  `difficulty.[min|max]_enemy_count` 后 **required_count 始终压过 cap** 保目标可达成，
  T030 起）；主题敌池经 `set_spawn_weights` 注入；elite/`is_boss` 房映射
  `enemy_types.elite_*` 变体（无变体回退基础型——spec「boss 未配置 → 精英回退」边界）；
  食物数 = `difficulty.floor_table[层].food_count` + delta（钳入
  `difficulty.[min|max]_food_count`，min 默认 0，T030 起）。
  难度钩子 `set_difficulty_scaler(obj)` duck-typed 读 `get_enemy_count_delta`/
  `get_food_count_delta`/`get_enemy_hp_bonus`（T030 实装，hp bonus 落点
  `EnemyManager.spawn_hp_bonus`）；修饰符注入点 `set_modifier_system(obj)` →
  布场后调 `apply_modifiers(room)`（T031 实装，先布怪后修饰）。
- `RunProgressionSystem` 多层推进（T022）：run state 增 `seed` 键；`advance_floor()`
  以同一 run seed 生成下一层（种子推导含 floor_index，SC-011 跨层确定性）、
  completed/available 按层重置（房 id 是楼层作用域）、`floor_generated` →
  `room_entered` 进起点房。**pcg 档**非终层 endpoint/boss 完成 → `floor_completed` →
  （`floor_reward` 家族未决则挂起，`floor_reward_chosen` 后再推进——FR-007 决议先于
  `floor_generated` 的 T027 groundwork）→ `call_deferred("advance_floor")`（boss 击杀
  级联发生在 tick 派发内，不可同步重建世界）；终层（`run.max_floors`）→ 胜利路径。
  **fixed_v1 档保持单层 MDE 闭环**（终点完成即胜利，FR-016「回退/MDE 路径」语义，
  L3 验收与 MDE 手动脚本不变——多层推进是 pcg 档行为）。
- `game_world`（T022）：`reset_for_floor()` 组合既有原语（按 target 注销蛇/段状态——
  **不可用 `StatusEffectManager.clear_all`，会连 TriggerManager 原子链清掉杀死 Build
  触发器**；clear_enemies/clear_foods/status_tile clear_all/effect window clear_all；
  蛇重建保长度），监听 `floor_generated`（楼层号大于跟踪值且属本世界 run 才重置，
  mock 发射免疫）；`start_game` 在有 RoomDirector 时不再 `init_enemies`（布怪让位
  director；l1/l2 场景无该节点保持原行为）。
- Build 跨层存续（T023，`test_l4_slots` 用例组）：蛇重建后已装鳞片/头/共鸣/开槽数/
  蜕皮余额/长度全部存续，卸装重装可驱动共鸣重算（触发器链路完好，FR-003/FR-013 边界）。
- 测试事实：`test_l4_room_director.gd`（T020 契约 + T021 布场 + T022 多层/门控/
  fixed_v1 回归 + game_world reset e2e）；全 game_world 多层测试需测试内切
  `ConfigManager.floor["generator"] = "pcg"` 并还原；boss 完成后需 `await process_frame`
  冲延迟切层。

## L4 Boss 结算 + 楼层奖励 + 多层冒烟事实（S2 T5b，T024-T028，2026-06-11）

- `FloorRewardSystem` 重写落地（`systems/growth/floor_reward_system.gd`，game_world.tscn 常驻节点）：
  Boss 结算两段式（FR-007/Designs §10.3-10.5）——① 固定槽位解锁步骤
  `choose_slot_position(position)` 经 `SlotExpansionSystem.unlock_slot(position, "boss")`
  真开槽（新槽先于 3 选 1 开放，US3 场景 1；全位置满级自动跳过）；② 独立 3 选 1
  `choose_floor_reward(index)`：扩展=随机高级鳞（`growth.floor_reward.expansion.advanced_level/
  scale_pool`，满槽替换语义同 ScaleRewardSystem）/ 强化=最低等级已装鳞免费升一级
  （`ScaleSlotManager.upgrade_scale`，满级件跳过，同级并列取 front→middle→back 序首件）/
  修正=同 tag 换鳞（保级保槽位）。无合格目标类别以高级鳞替补（去重），尽量保持 3 选项；
  全空自动决议（`floor_reward_chosen` 带 skipped=true，不发 presented，FR-014）。
- 呈现自守门（`_on_floor_completed`）：`floor_index < run.max_floors`（终层直达胜利路径，
  US5 场景 4）**且 `floor.generator == "pcg"`**（T5a 裁定：fixed_v1 = 单层 MDE 回退档）；
  `present_settlement(floor_index, room_id, salt)` 公共方法本身不设门槛（测试/布景直驱）。
  抽样种子 = `hash(run_id:floor_reward:floor_index:source_room_id)`（同 run 同层确定性）。
  `run_started` 清残留 offer（FR-013）。
- 门控时序（T027）：`floor_completed` 同步派发内 presented → RunProgression 登记
  `floor_reward` 家族 → 挂起切层；`floor_reward_chosen` → `call_deferred("advance_floor")`
  ——决议严格先于下一次 `floor_generated`（US5 场景 5，`test_l4_floor_rewards` 顺序断言）。
- `ScaleSlotManager.get_slot_layout(position)` 新 accessor：槽位原始视图（含 null 空槽，
  索引 = 真实槽位号）——升级/换鳞按槽位号定位（`get_scales` 压缩空槽索引会漂移）。
- UI：`ui/floor_reward_panel.gd` 基于 ui/kit 重建为两段式模态（modal 层 + ui_modal 组，
  右上选择栏同槽位；① slot_empty glyph 槽位卡（前段/中段/后段）→ ② choice_card×3
  （类别名 + detail 具体效果 + 底缘标签色条），已去 class_name。公共契约：setup/get_step/
  get_visible_option_count/get_slot_labels/get_option_labels/choose_slot_by_index/
  choose_slot_position/choose_option_by_index/get_status_text。
- 多层冒烟（T028，`test_l4_multifloor_run.gd`）：种子 9090 三层 PCG 至胜利全程面板公共 API
  驱动——floor_generated×3、主题（ruins/marsh/cave）与房型序列各异（SC-005）、结算未决时
  Next 被拒、槽位 3→5 真开、终层无楼层奖励、game_over cause=victory。
- 几何探测新增状态 `l4_floor_reward_slot`/`l4_floor_reward_choice`（state_stager 经
  `present_settlement` 系统公共 API 布景两段模态）。
- JSON 增量：`growth.floor_reward.slot_unlock_source: "boss"`、`expansion.scale_pool/
  advanced_level`；三类 description 对齐 Designs §10.4 措辞（诅咒鳞/头尾升级/槽位重排
  变体在 backlog.md，不入 v1）。

## L4 难度缩放 + 房间修饰符事实（S2 T6，T029-T032，2026-06-11）

- `DifficultyScaler` 重写落地（`systems/difficulty/difficulty_scaler.gd`，game_world.tscn
  常驻节点）。FR-008 两层结构：
  - **静态层（MUST，玩家可感）**：`get_static_enemy_delta()` = floor_table[层].enemy_count
    − `baseline_enemy_count`；`get_enemy_hp_bonus()` = floor_table[层].enemy_hp_bonus；
    楼层号经 `floor_generated` 跟踪。食物静态基数由 RoomDirector 直接读
    floor_table.food_count，**scaler 的 `get_food_count_delta()` 只含反应式分量**（防双计）。
  - **反应式层（SHOULD，设计不可见——Designs §11.5，验收仅生成参数级断言）**：
    单房口径度量（草稿 :114 全局累计 tick 已修）——`room_entered` 记起算 tick、
    `room_completed` 计差；命中源 = `snake_body_attacked` + `snake_hit_boundary`；
    状态源 = `reaction_triggered` + `status_added_to_carrier(carrier_type=="enemy")`；
    每 `rooms_between_adjustments` 房按 `metrics` 权重重算分数（归一化分母出自
    `reactive.normalization`，草稿 :93 硬编码已修）→ 过 `overperform_threshold` 敌 +/食 −、
    低于 `underperform_threshold` 反向，幅度 `adjustment_*_delta` 钳入 `reactive.clamp`；
    `reactive.enabled=false` 整层归零（砍单阶梯首位）、`difficulty.enabled=false` 全部归零；
    `run_started` 重置（FR-013）。`get_last_room_metrics()` 介观接口供测试。
  - **唯一消费者 = RoomDirector**（duck-typed 钩子拉取）；`difficulty_adjusted` 事件
    仅供观测，无系统监听方。
- `EnemyManager.spawn_hp_bonus`（T030 增量）：随机生成敌人在 config hp 之上加成
  （RoomDirector 每房写入 scaler 的 hp bonus；默认 0 保 L1/L2；`spawn_enemy_at`
  定点放置不吃加成——l1/l2 验收场景/触发原子语义不变）。
- `RoomModifierSystem` 重写-扩展落地（`systems/difficulty/room_modifier_system.gd`，
  game_world.tscn 常驻节点，`setup(enemy_mgr, status_tile_mgr, snake)`）。v1 双件：
  - `shield_enemies`：布场后随机 `params.max_shielded` 个敌人 hp += `params.hp_bonus`，
    挂 `ShieldOutline` 描边（`visual.outline_palette_token` palette 色、外扩
    `outline_pad`、z 序低于本体；与状态描边 3px 错开，叠加独立可读）+
    meta `room_modifier_shield`；
  - `preset_status_tiles`：经 StatusTileManager 预置 `params.tile_count` 个状态格
    （类型抽 `params.tile_types`，距蛇头曼哈顿 ≥ `params.min_distance_from_snake`，
    Designs §11.5「状态格已预置」，复用状态格视觉）。
  - 生命周期：生成期选定（FloorMapGenerator ⑧ 按 `floor.modifier_weights`）→
    RoomDirector 布场后 `apply_modifiers(room)`（注入点，重入先回收旧账）→
    `room_completed` 移除（**按 [pos,type] 账本只回收自己放置的格/盾**，不误伤外部
    状态格；存活敌人 hp 回退）→ `run_started` 清账（FR-013）。应用层复核逐项
    `enabled`（生成层之外纵深防御）；v1 集合外 id（含草稿残留）一律拒绝。
- `game_world.tscn/gd` 接线：`DifficultyScaler`/`RoomModifierSystem` 场景节点；
  `room_director.set_difficulty_scaler/set_modifier_system` + `room_modifier_system.setup`；
  `cleanup()` 扩展。接线后全 world 多层测试的楼层 2+ 敌数 = 房 enemy_count + 静态
  delta（`test_l4_room_director` e2e 断言已按 scaler 读数计算预期）。
- 测试事实：`test_l4_difficulty.gd` 重写（静态层/钳制/单房度量/事件源/clamp/分母
  JSON 反证/开关/FR-013 + 修饰符应用-移除-禁用-叠加-拒绝 + RoomDirector e2e +
  场景节点存在）；反应式用例全部为生成参数级断言（无玩家感知措辞）；
  `test_l4_config`/`test_l4_pcg_rooms` 补 T032 节奏互证（v1 集合恰为双件、params 形状、
  权重引用真实修饰符、2 层起精英/修饰从数据出现且 id 全落 v1 集合——固定种子确定性）。

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
