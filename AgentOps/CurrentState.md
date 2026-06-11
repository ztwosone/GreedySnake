# 当前状态

**更新时间**：2026-06-11（S3 M1 收口）
**当前分支**：`003-l5-meta-growth`
**当前 feature**：`.specify/specs/003-l5-meta-growth/`（spec/plan/tasks 已 2026-06-11 治理修订）
**当前阶段**：S3 进行中——M1 ✅（run_ended 链路 + 存档硬化）；M2 解锁门控 / M3 传承石 / M4 拾取+验收 待办

## 阶段路线图

```
S0 稳定化 ✅ → S1 体验设计文档+表现内核 ✅ → S2 L4 重验收(spec 002) ✅
→ S3 L5 元成长(spec 003) ← 当前 → S4 体验完成层(004 Phase P) → S5 整段验收封板
```

## S2 Gate-A 记录（T037，2026-06-11）

- **严格门禁**：`STRICT PASSED`（T7 收口最终跑），普通汇总 `ALL PASSED: 3635/3635`。
- **套件数核对**：`suites: 71 discovered / 71 ran`（runner 自核对，零静默吞测）。
- **多层冒烟**：`test_l4_multifloor_run`（种子 9090，3 层 PCG 至胜利、门控、槽位真开、
  终层无奖励）+ `test_xp_contracts_l4`（VirtualPlayer 真实步进 + 面板驱动全程、防死锁断言）双绿。
- **PCG 性质测试**：`test_l4_pcg_rooms`（定种子全等/变种子异图/BFS 可达/商店保底/
  节奏数据反证）+ 验收套件 SC-010 多种子 DFS 互证双绿。
- **几何探测覆盖**：8 典型状态（title/game_over/l3_run_start/l3_reward_pending/
  l4_scale_pending/l4_shop_open/l4_floor_reward_slot/l4_floor_reward_choice）随门禁每跑。
- **截图评审证据**：`AgentOps/acceptance_shots/2026-06-11/`（7 镜头 + findings.md：
  7 PASS / 2 SUSPECT 不阻塞，§12.2 清单逐张评审）。
- **Gate-H（人工，不阻塞合入，S3 收口前补录）**：① S1 人工 5 分钟设计语言裁定；
  ② T017 MDE 10 分钟人工通跑（脚本见下节）；③ 层间压力可感知（静态缩放——
  截图 07 已留楼层 2 敌数 +1 的画面证据，待人工确认体感）；反应式 DDA 按设计不可见、
  仅生成参数级测试验证（已闭环，无人工项）。

## 实现事实（S1 后基线）

- 表现层 source of truth：`Designs/Interactive/presentation_design.md`（「网格信号」）。
- 表现内核与验收基建已落地（详见 QuickReference「表现内核事实」节）：
  `presentation` JSON 段、`ui/kit/` 六件、TickManager/VFXManager 仪表缝、
  `Test/experience/` 六件（recorder/driver/actor/settle/probe/stager）。
- L3 三面板 + title/game_over/hud 已迁移统一设计语言；debug UI 收进
  `presentation.debug_ui` 开关（默认关，含 T/Y 验收捷径与 B/V/C 热键）。
- 几何探测随严格门禁每次运行（4 个典型状态）；L3 首批体验契约入库
  （模态唯一/reward 流 ui 变化/time-to-first-choice）。
- 顺手修复：空身躯残留蛇 tick 越界（Snake.move 防御早退 + 回归测试，
  ScriptingLeading §3.1.3 步骤 0）。
- L4/L5 草稿仍为零集成状态，等待 S2/S3 逐卡重验收（缺陷清单见 02cdabf 提交信息）。

## 当前阻塞项

- 无阻塞。**Gate-H 欠账**（T037 裁定：不阻塞合入，**S3 收口前**补录于本文件）：
  ① S1 的人工 5 分钟设计语言裁定未做（编辑器 F5 看一眼 title→局内→game over 的观感）；
  ② T017 MDE 的 10 分钟人工通跑未做（脚本见下节，全自动链路已由 e2e + 几何探测覆盖）；
  ③ 层间压力可感知的人工体感确认（静态缩放，截图 07 留有楼层 2 敌数 +1 画面证据）。

## MDE 存活检查点（T017，tag `mde-checkpoint`，2026-06-11）

**定义**：fixed_v1 单层闭环 = 战斗 → 鳞片三选一 → 蜕皮入账 → 商店买槽 → 终点/死亡结算，
S1 统一设计语言。此后任何中断，项目仍是「打开就能感受到设计意图」的最小可交付体验。
砍单阶梯（反应式 DDA → 主题敌池 → 修饰符扩展）绝不低于此线。

**10 分钟手动演示脚本**（人工通跑待补录，Gate-H 式欠账）：

1. 编辑器 F5 → 标题屏：确认 S1 设计语言（角括号框、palette、glyph、网格信号布局）→ 开始。
2. `combat_01`：清 3 敌（蛇头吞噬/状态反应），观察击杀掉食、HUD 长度、房间意图面板进度 0/3→3/3。
3. 房间完成 → 右上鳞片三选一模态：确认 Next 按钮禁用（FR-015 门控）；点「放弃全部 +6 蜕皮」→
   右上蜕皮 chip 首次入账出现（渐进披露）并弹跳。
4. Next → `reward_01`：L3 奖励三选一（头/尾/鳞 choice_card），选一张 → 「已选择」反馈。
5. Next → `combat_02`：再清 3 敌 → 第二次鳞片模态 → 再放弃（余额 12）。
6. Next → `shop_01`：商店面板开（货架 ≤5：鳞片 L1-L3×2 / 扩展槽位 / 蛇头升级 / 蛇尾升级；
   价格 chip 蜕皮图标；买不起的行灰显）。买「扩展槽位」（5 蜕皮）→ 余额扣减；
   （debug_ui 开启时按 B 看 Build 面板开槽数 +1）。确认不买也能直接走（无门控）。
7. Next → `rest_01`（自动完成）→ Next → `endpoint_01` → 胜利结算屏（cause=victory）。
8. 重开一局，故意撞墙/被敌人耗死 → 死亡结算屏 → 重开正常。
9. 全程检查：模态唯一（同屏最多一个选择面板）、离开奖励房后「已选择」面板收起、
   商店离店后面板收起、蜕皮 chip 跨房间存续。

## 最近验证基线

- 普通测试：`3708/3708` 断言，套件 `71/71`。
- 严格测试：`STRICT PASSED`（2026-06-11，S3 M1 收口门禁）。

## S3 进度

- M1 ✅（T001-T005 run_ended 链路 + 存档硬化）：`run_ended` 唯一发射点落定——
  `RunStatsTracker.finalize_run(outcome)` once-guard（`run_started` 解除），调用方 =
  `RunProgressionSystem` victory/death 双出口（`set_stats_tracker` duck-typed 注入缝，
  未注入零行为，RunProgression 侧 guard 双保险）；payload = spec FR-016 冻结契约
  （outcome/run_id/floor_index + 十字段 stats，`stats.run_outcome` 冗余删除）；度量源补全
  （damage 双源 boundary+body_attacked / near_death=no_body_countdown_started /
  low_length=tick×JSON 阈值 / max_length / duration_ticks）；MetaSaveSystem save_path
  构造注入缝（`_init` 不再隐式读盘）+ `schema_version` 恒写 + 坏档/形状/版本未知容错重置
  （push_warning，默认解锁集 hydra/salamander）；JSON `meta_growth` 增 schema_version /
  default_unlocked_heads/tails / stats.low_length_threshold + ConfigManager 四 accessor；
  `test_l5_meta_save` 全量重写（临时 save_path 卫生），`test_l5_unlocks/legacy/acceptance`
  草稿卫生化补丁（各自重写卡在 M2/M3/M4）；meta_save/run_stats 已去 class_name；
  EventBus run_ended 注释 + QuickReference「L5 元成长 M1 事实」同提交落地。
  注意：生产侧 tracker/MetaGrowthRoot 场景接线归 M2 T009（M1 只落注入缝）；
  Red 阶段跑旧草稿套件曾写真实 user://meta_save.json，残留已删（M4 Gate-H 删档重验照旧）。

## S2 进度

- T7 ✅（T033-T037 验收与封口）：`test_l4_acceptance` 重写为修订版 SC-001..SC-012
  逐条映射（含 SC-012 四 offer 空选项自动决议 + FR-015 门控、SC-010 多种子商店
  保底 DFS、SC-011 双档定种子全等）；`test_xp_contracts_l4` 新建（CompositeBrain
  确定性种子真实步进穿首战斗房 → 面板驱动 3 层 pcg 至胜利 + 防死锁断言 + L4 新
  模态契约表）；TDD Red 实证修复两处 harness——experience_recorder 同前缀重呈现
  原地更新（两段结算曾叠悬挂模态）、game_perception Object.get 双参误用（L2.5
  草稿缺陷，敌人入场即快照中断）；AcceptanceShots Layer C 装置
  （`Project/AcceptanceShots/` + `Tools/run_acceptance_shots.ps1`，EnvPath.json
  已登记）S2 Gate 首用 7/7 + findings.md；文档清偿（QuickReference L4 完成态 +
  T7 事实节 / 本文件 / DailyLogs）。

- T6 ✅（T029-T032 难度缩放 + 房间修饰符）：`DifficultyScaler` 重写为 FR-008 两层——
  静态层 MUST（floor_table − baseline 敌数 delta + enemy_hp_bonus，楼层经
  floor_generated 跟踪；食物静态基数仍由 RoomDirector 直读 floor_table，scaler 食物
  delta 只含反应式分量防双计）+ 反应式 DDA SHOULD（设计不可见，Designs §11.5；
  单房口径度量：room_entered 起算 tick/room_completed 计差，命中源 snake_body_attacked
  + snake_hit_boundary，状态源 reaction_triggered + status_added_to_carrier(enemy)，
  归一化分母/clamp 全 JSON；reactive.enabled 砍单开关 + difficulty.enabled 总开关 +
  run_started 重置 FR-013）；唯一消费者 RoomDirector（duck-typed 钩子拉取，
  difficulty_adjusted 事件仅观测）。`EnemyManager.spawn_hp_bonus` 增量（spawn_enemy_at
  不吃加成）；RoomDirector 预算/食物钳制改走 difficulty.[min|max]_* 配置
  （required_count 压过 cap）。`RoomModifierSystem` 重写-扩展：v1 = shield_enemies
  （随机 max_shielded 个敌 hp+hp_bonus + ShieldOutline palette 描边 + meta 标记）+
  preset_status_tiles（StatusTileManager 预置 tile_count 格，距蛇头 ≥ min_distance），
  经 RoomDirector 注入点应用（先布怪后修饰）、room_completed 按账本只回收自己放置的
  格/盾、应用层复核 enabled、v1 集合外 id 拒绝；game_world.tscn/gd 接线两节点。
  JSON：room_modifiers 草稿残留（darkness/speed_strips/mine_tiles）删除、schema 改
  params+visual、overperform_threshold 0.7→0.75（浮点临界防抖）、min_food_count 0、
  死键 baseline_food_count 删除。`test_l4_difficulty` 全量重写（反应式用例纯生成参数级
  断言）；`test_l4_acceptance` SC-006/SC-007 同卡更新；`test_l4_config`/`test_l4_pcg_rooms`
  补 T032 节奏互证。接线副作用：全 world 测试楼层 2+ 敌数 = 房 enemy_count + 静态
  delta（test_l4_room_director e2e 断言已按 scaler 读数适配）。

- T5b ✅（T024-T028 楼层奖励 + 多层冒烟）：`FloorRewardSystem` 重写为 Boss 结算两段式
  （FR-007/Designs §10.3-10.5）——固定槽位解锁步骤（选前/中/后，经 SlotExpansionSystem
  `unlock_slot(position, "boss")` 真开槽，新槽先于 3 选 1 开放；全位置满级自动跳过）+
  独立 3 选 1（扩展=随机高级鳞 `advanced_level`/强化=最低级件免费升一级/修正=同 tag
  换鳞保级保槽位；无合格目标类别以高级鳞替补；全空自动决议 FR-014）；呈现自守门
  `floor_index < run.max_floors` **且 pcg 档**（终层直达胜利 US5 场景 4；fixed_v1 单层
  MDE 闭环不弹）；决议严格先于 `advance_floor`/`floor_generated`（US5 场景 5，顺序断言
  入库）；`floor_reward_panel` 基于 ui/kit 重建两段式模态（槽位卡 → choice_card×3，
  去 class_name）；game_world.tscn/gd 接线 + cleanup；`ScaleSlotManager.get_slot_layout`
  新 accessor（升级/换鳞按真实槽位号定位）；几何探测新增 `l4_floor_reward_slot/choice`
  状态；T5a 驱动器（room_director/slots T023/acceptance SC-004）补结算决议；
  `test_l4_multifloor_run.gd` 多层冒烟（种子 9090：3 层主题/布局各异、门控、槽位 3→5、
  终层无奖励、cause=victory）。EventBus 契约增量（presented 两段 step 字段 / chosen 带
  floor_index+skipped）同提交落 QuickReference。

- T5a ✅（T020-T023 多层基建）：`EnemyManager` 增量改造——`respawn_policy`
  （默认 `maintain` 保 L1/L2 行为，`room_budget` 档不补怪）+ `spawn_budget`
  （`spawn_enemy_at` 定点放置不消耗）+ `set_spawn_weights` 注入权重表；
  `RoomDirector` 新建（game_world 常驻节点）——`room_entered` 清场布怪布食
  （仅 clear_enemies 房有敌、预算钳 >= required_count、主题敌池注入、elite/boss 房
  elite_* 变体、食物走 difficulty.floor_table）、`floor_theme_set` 发射、难度 scaler
  duck-typed 钩子（T6 零桩）+ 修饰符注入点（T031）；`RunProgressionSystem.advance_floor()`
  ——同 run seed 重生成下层、按层重置房间状态、**pcg 档**非终层 boss 完成
  `call_deferred` 切层（击杀级联重入防护）、floor_reward 未决挂起（T027 groundwork）、
  终层胜利路径；**fixed_v1 档保持单层 MDE 闭环（终点即胜利）**；
  `game_world.reset_for_floor()`——组合既有清场原语 + 蛇重建保长度（按 target 注销
  状态，不可 StatusEffectManager.clear_all——会杀 Build 触发器）；Build/蜕皮/共鸣
  跨层存续专项测试（test_l4_slots T023 用例组）。新套件 `test_l4_room_director.gd`。

- T4 簇 ✅（T018-T019）：`floor_map_generator` 重写为双档——`floor.generator` 开关全权决定
  （草稿楼层 1 短路固定路径、2 层起无视开关已修）；PCG 档 seeded（每层 RNG 种子 =
  `hash("run_seed:floor_index")`，RNG 调用顺序固定且文档化）；结构保证构造即性质：
  起点 combat / 终点 boss 恰一间（`room_types.boss` 新增，is_boss、clear_enemies）、
  每层恰一商店且全路径 ≥2 战斗房在前（SC-010）、奖励房保底、支线死端全房可达；
  精英升格按 `floor.elite_weights`、修饰符按 `floor.modifier_weights` + 逐项 enabled
  （首层全 0 数据节奏生效）；魔数全入 `floor.pcg`（main_rooms 楼层键表/权重/支线参数）+
  新 accessor `get_pcg_config`/`get_pcg_main_room_bounds`；`test_l4_pcg_rooms` 重写为
  性质测试（定种子全等、变种子异图、BFS 可达、DFS 商店保底、边界、数据反证、逐项 disable）；
  fixed_v1 档输出与 L3 验收完全一致（`test_l3_floor_progression` 回归绿）。

- T1 簇 ✅（T001-T003）：`run.max_floors: 3` 取代并删除 `max_floors_v1`（旧键零调用方）、`floor.generator` 开关、
  节奏权重（首层 modifier/elite 全 0）、商店保底、`shop.price_multiplier_per_floor`、`room_types.shop|elite`、
  elite 敌人类型（is_elite + 1.25x + room_elite 描边 token）、difficulty 静态层表 + reactive 归一化、
  修饰符 v1 配置（shield_enemies/preset_status_tiles 逐项开关）；EventBus 补 `scale_option_discarded`/`floor_theme_set`、
  `scale_reward_chosen` 带 skipped 契约；QuickReference 含 L4 事件发射方→监听方表 + FR-018 注记。
  注意：`room_modifiers` 中 darkness/speed_strips/mine_tiles 为草稿残留（仍被草稿测试引用），
  随 T029/T031/T033 测试重写时删除。

- T3 簇 ✅（T011-T017）：`ScaleSlotManager` 上限 JSON 化（`growth.slot_expansion.max/initial` +
  `get_max_slots`/`get_open_slots` accessor，`build_test_panel` 直读迁移）；`slot_expansion_system`
  重写为薄适配器（unlock 真调 `open_slot`，草稿买槽零效果已修；`shop_purchase` 事件链开槽）；
  `shop_system` 修复（种子 RNG `hash(run_seed:room_id)`、容量按开放槽、`room_entered` 退店、
  物价乘数 `ceil(基准×mult^(层-1))`、空货架自动决议 FR-014、商店**不注册模态门控**）；
  `shop_panel` 基于 ui/kit 重建（货架行 + 价格 chip + 禁用去饱和，≤5 项）；
  `fixed_v1_path` 插入 `shop_01`（6 房，FR-017 商店保底 + MDE 买槽可达）；game_world 接线
  买槽端到端（买 → 开槽 → 装备 → 共鸣）；几何探针实证缺陷顺手修：`RewardChoicePanel`
  「已选择」反馈离开奖励房不收（双模态重叠），现随 `room_entered` 收起；
  几何探测新增 `l4_shop_open` 状态；JSON 增量 `shop.scale_pool`/`shop.shelf_plan`/
  tier `level`/slot `position`。MDE tag `mde-checkpoint` 已打（见上节）。

- T2 簇 ✅（T004-T010）：`scale_reward_system` 重写（无合成 `room_completed`/FR-018、满槽替换、
  按开放槽过滤、空池自动决议 FR-014、先清状态再发事件修软锁、`set_sampling_bias` L5 钩子）；
  `shedskin_system` 修复（Enemy 节点判型、跨层保留 FR-003、`run_started` 清零 FR-013、discard 收入）；
  模态门控 FR-015 双侧落地（RunProgression `has_pending_offer` + FloorProgressPanel Next 禁用/
  `is_advance_blocked`）；L3 `RewardFlowSystem` 空选项自动决议回补；`scale_choice_panel`（kit 模态，
  choice_card×3 + 放弃入口 +N 蜕皮）与 `shedskin_display`（kit chip，渐进披露）重建；game_world 接线 +
  cleanup 扩展；L3 回归套件（smoke/acceptance/xp_contracts/stager）适配鳞片模态；几何探测新增
  `l4_scale_pending` 状态；JSON 增量 `growth.scale_reward.default_pool`。
  测试事实：全局 `enemy_killed` 的 `enemy_def` 必须是 Node 派生或 null（EnemyManager 按 Node 收参）。

## 下一张建议任务（S3 开卡：L5 元成长，spec 003 重验收）

S2 已封口合 main。S3 按 plan.md 判决表（后 5 文件）重验收 L5 草稿，建议簇序：

1. **`run_ended` 链路先行**（S3 一切的地基）：生产代码当前**无人发射 `run_ended`**
   ——判决为 `RunStatsTracker.finalize_run` 是唯一发射点，调用方 = RunProgressionSystem
   （victory/death 双出口）。先写 Red：胜利与死亡各恰一次 `run_ended`、payload 带
   完整 run stats。
2. **MetaSave/RunStatsTracker**（保留+修）：meta_save_system 注入 save_path（测试用
   user:// 临时路径）、容错重置、schema 版本；run_stats_tracker 补
   near_death/low_length/damage_taken 度量源；MetaGrowthRoot 常驻节点挂 game_world
   外层（跨 run 存续，世界重建不清）。
3. **传承石选择**：legacy_stone_system 阈值 JSON 化；bias 消费端 =
   ScaleRewardSystem.set_sampling_bias 既有钩子（T005 预留，零改造接入）；
   selected payload 带完整 stone；STONE_SELECT 屏（GameManager.GameState 枚举扩展
   属 S4 Phase P，S3 先以系统级 API + 测试驱动，UI 可后置）。
4. **解锁门控既有内容**：**先补 Designs §12.3 v1 映射附录**（设计先行红线——
   哪些鳞片/头/尾/房型初始锁定、解锁条件各是什么），再 gate：RewardFlow/
   ScaleReward/Shop 按解锁集过滤抽样池。
5. **pickups（Should，砍单阶梯首位）**：节点判型 bug、elite 查 is_elite、网格实体化
   （仿 food）、randf 顺序修正；v1 仅 broken_eye。
6. 纪律不变：TDD 每卡 Red 先行；每簇严格门禁绿合 main；EventBus/JSON 契约变更
   同提交落 QuickReference；新 UI 必须 ui/kit 基座 + stager/几何探测覆盖。
   Gate-H 三项人工欠账（见 Gate-A 记录）须在 S3 收口前补录。
