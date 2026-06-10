# Tasks: L4 Growth Cycle（重验收 Re-cut，2026-06-11）

**Input**: `.specify/specs/002-l4-growth-cycle/`（spec.md 2026-06-11 修订版 + plan.md「重验收策略」+ backlog.md）
**Context**: 本次不是绿地开发。6-5 草稿系统/面板/测试已入库（零场景集成，缺陷逐文件实证——判决表见 plan.md「重验收策略」）。任务语义统一为**「对照修订后 spec 验证/修复/重写 X」**，而非「Create X」。
**Tests**: TDD 强制——每卡先写/改失败测试（Red）→ 最小实现（Green）→ 重构 → 全量回归。每卡列明归属测试套件。
**UI**: 全部 UI 卡**基于 `Project/ui/kit/` 构建**（theme_builder/kit_panel/glyph/choice_card/banner/chip），出生即带分组/`ui_layer` 元数据/`settle()`；零编排（仪式归 S4）。
**合入节奏**: 每簇（T1–T7）完成即跑严格门禁（`Tools/run_tests_strict.ps1`）并合 main——防长分支搁浅。

---

## T1 簇 — 配置与契约基线（横切，阻塞全部后续）

**Goal**: 修订版 spec 的全部配置键与事件契约落地为数据与 accessor，概念节奏从此可纯数据验证。

**Independent Test**: 新套件 `test_l4_config.gd` 全绿：max_floors/generator 开关/节奏权重/物价乘数均可从 JSON 读出且无 `max_floors_v1` 残留。

- [x] T001 配置修订卡：在 `Project/data/json/game_config.json` 落地 `run.max_floors: 3`（**显式取代并删除 `max_floors_v1`**）、`floor.generator: "fixed_v1"`（枚举 `fixed_v1|pcg`）、`floor.modifier_weights`（首层全 0）、elite 权重（首层 0）、商店保底参数（≥2 战斗房后）、`shop.price_multiplier_per_floor`、`room_types.shop|elite`、elite 敌人类型、difficulty 静态层表+反应式归一化参数、修饰符 v1 配置（`shield_enemies`/`preset_status_tiles`，逐项 disable 开关）。测试套件：`Project/Test/cases/test_l4_config.gd`（新建，FR-016/FR-017/SC-009/SC-010 数据断言）
- [x] T002 ConfigManager accessor 卡：`Project/autoloads/config_manager.gd` 新增/迁移 accessor（max_floors 取代 max_floors_v1 的 accessor，**同卡迁移全部调用方**；generator/节奏权重/物价乘数 accessor）。测试套件：`test_l4_config.gd` + 全量回归
- [x] T003 [P] EventBus 契约卡：对照 plan.md 信号清单验证 `Project/autoloads/event_bus.gd` 中 L4 信号（补 `scale_option_discarded`、`scale_reward_chosen` 带 `skipped` 字段）；同提交更新 `TechDocs/QuickReference.md` 事件「发射方→监听方」对照表增量（含 RewardFlowSystem 合成 `room_completed` 为 L3 奖励房显式保留契约的注记，FR-018）。测试套件：`test_l4_config.gd`（信号存在性断言）

**T1 收口**: 严格门禁绿 → 合 main。

---

## T2 簇 — 鳞片奖励链 + 蜕皮经济基础（US1 + US2 前半，P1）

**Goal**: 战斗房清怪 → 3 选 1 → 装备/放弃 → 蜕皮入账，全链无软锁、无合成 `room_completed`。

**Independent Test**: 清战斗房 → 恰 3 选项呈现 → 选中装备到对应槽且 Build 面板更新；放弃 → +2 蜕皮；空池 → 自动决议且流程继续。

- [ ] T004 [US1] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_scale_rewards.gd`——幻影二次 offer 回归用例、无合成 `room_completed` 断言（FR-018）、满槽替换、按开放槽过滤、空池自动决议（FR-014）、放弃蜕皮收入。测试套件：`test_l4_scale_rewards.gd`
- [ ] T005 [US1] 重写 `Project/systems/growth/scale_reward_system.gd` 逻辑（判决：重写）：修软锁（:85,:98 状态互踩）；**拆除合成 `room_completed`（仅此系统）**；改发 `scale_reward_chosen`/`scale_option_discarded`；满槽替换/空池自动决议/按开放槽过滤；预留传承石偏置注入钩子（L5 用）。测试套件：`test_l4_scale_rewards.gd`
- [ ] T006 [P] [US2] 验证修复 `Project/systems/growth/shedskin_system.gd`（判决：保留+修）：修 Enemy 节点被当 Dictionary 判型（:87，elite 分支死代码）；**跨层保留**（FR-003 修订后，删除 floor_generated 清零路径）；补 discard 收入接线。测试套件：重写 `Project/Test/cases/test_l4_shedskin.gd`（含跨层保留用例）
- [ ] T007 [横切] 模态门控卡：`Project/systems/run/run_progression_system.gd` 增加 pending-offer 登记（任一 `*_presented` 未决 → 忽略推进请求、Next 禁用，FR-015）；L3 `RewardFlowSystem` 补空选项自动决议（四 offer 系统中 Scale/Shop/FloorReward 的自动决议在各自重写卡内，FR-014）。测试套件：`test_l4_scale_rewards.gd`（门控用例）+ `test_l3_*` 全量回归
- [ ] T008 [US1] UI 卡：`Project/ui/scale_choice_panel.gd` **基于 ui/kit 构建**（choice_card×3 + 放弃入口标注 +2 蜕皮；进 ui_modal 组自动纳入几何探测）。测试套件：`test_l4_scale_rewards.gd`（UIActor 公共 API 驱动用例）+ 几何探测（自动覆盖）
- [ ] T009 [P] [US2] UI 卡：`Project/ui/shedskin_display.gd` **基于 ui/kit chip 构建**（HUD 蜕皮计数，首次入账才出现——概念节奏）。测试套件：`test_l4_shedskin.gd` + 几何探测
- [ ] T010 [US1] 集成卡：`Project/scenes/game_world.gd` 接线鳞片奖励链（清怪 → offer → 决议 → 房间流程继续，不经合成 `room_completed`）。测试套件：`test_l4_scale_rewards.gd` + `test_l3_room_flow.gd` 回归

**T2 收口**: 严格门禁绿 → 合 main。

---

## T3 簇 — 槽位扩展 + 商店（US2 后半 + US3，P1/P2）

**Goal**: 买槽真开槽、商店真随机、退店有通路；经济闭环（赚-花-涨价）成立。

**Independent Test**: 积累蜕皮 → 进商店 → 买槽 → `open_slot()` 生效 → 新槽可装备可共鸣；买不起的项禁用；下一层物价上涨。

- [ ] T011 [US3] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_slots.gd`——买槽后 open_slot 生效断言、3→7 上限（前×2 中×3 后×2）、新槽参与共鸣。测试套件：`test_l4_slots.gd`
- [ ] T012 [US3] 重写 `Project/systems/growth/slot_expansion_system.gd` 为**薄适配器**（判决：重写）：真正调用 `ScaleSlotManager.open_slot()`；ScaleSlotManager 的 MAX_SLOTS JSON 化 + 提供 accessor，**同卡迁移 `Project/ui/build_test_panel.gd:161` 的直读**。测试套件：`test_l4_slots.gd` + L2 Build 回归
- [ ] T013 [P] [US2] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_shop.gd`——种子随机抽货、容量、退店、物价乘数、空货架自动决议、买不起禁用。测试套件：`test_l4_shop.gd`
- [ ] T014 [US2] 验证修复 `Project/systems/growth/shop_system.gd`（判决：修）：修 pool[0] 伪随机（:198，改种子 RNG）；修容量误用已装数（:130）；exit_shop 接 `room_entered` 退店；消费 `shop.price_multiplier_per_floor`；空货架自动决议（FR-014）。测试套件：`test_l4_shop.gd`
- [ ] T015 [US2] UI 卡：`Project/ui/shop_panel.gd` **基于 ui/kit 构建**（货架卡片 + 价格 chip + 禁用态；≤5 项）。测试套件：`test_l4_shop.gd`（UIActor 驱动）+ 几何探测
- [ ] T016 [US2+US3] 集成卡：`Project/scenes/game_world.gd` 接线商店进出流 + 买槽端到端（买槽 → 槽位开放 → 装备成功）。测试套件：`test_l4_shop.gd` + `test_l4_slots.gd`

**T3 收口**: 严格门禁绿 → 合 main。

- [ ] T017 【MDE 存活检查点】打 tag `mde-checkpoint`：手动脚本验证 F5 → S1 设计语言 → fixed_v1 单层 → 战斗 → 鳞片三选一 → 蜕皮入账 → 商店买槽 → Boss → 死亡结算全通。此后任何中断，项目仍是「打开就能感受到设计意图」的最小可交付体验。砍单阶梯绝不低于此线。证据记入 `AgentOps/CurrentState.md`

---

## T4 簇 — Seeded PCG 楼层生成（US4 前半，P2）

**Goal**: 楼层图为种子确定性 PCG：config 权重/分支、每层保底商店（≥2 战斗房后）、endpoint=boss；fixed_v1 留作开关回退。

**Independent Test**: 定种子生成两次同图；性质断言（连通/可达/房数边界/商店保底位置/首层零修饰零精英）全绿；`floor.generator` 两档均可跑。

- [ ] T018 [US4] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_pcg_rooms.gd` 为**性质测试**——连通性、全房可达、房数边界、定种子确定性（SC-011）、商店保底排 ≥2 战斗房后（SC-010）、endpoint=boss、首层 modifier/elite 权重为 0 从数据生效。测试套件：`test_l4_pcg_rooms.gd`
- [ ] T019 [US4] 重写 `Project/systems/rooms/floor_map_generator.gd` PCG 路径（判决：PCG 重写）：seeded RNG + config 权重/分支 + 每层保底 shop + endpoint=boss；魔数（:54-84）全部入 JSON；fixed_v1 路径保留于 `floor.generator` 开关后。测试套件：`test_l4_pcg_rooms.gd` + `test_l3_floor_progression.gd` 回归（fixed_v1 档）

**T4 收口**: 严格门禁绿 → 合 main。

---

## T5 簇 — 多层推进 + 楼层奖励 + RoomDirector（US4 后半 + US5，P2）

**Goal**: 3 层完整 run：层间切换干净（清场/重建/装备存续）、Boss 结算 = 固定槽位解锁 + 3 选 1、终层走胜利路径。

**Independent Test**: 面板公共 API 驱动 3 层 PCG run 至胜利；首层 Boss 后选位开槽 + 三选一生效；终层 Boss 后无楼层奖励直达胜利。

- [ ] T020 [US4] EnemyManager 增量改造卡（RoomDirector 前置契约变更）：`Project/systems/enemy/enemy_manager.gd` 新增 `respawn_policy`（默认 `maintain` 保 L1/L2 行为与既有测试绿）+ 注入式权重表 + spawn_budget。测试套件：`Project/Test/cases/test_l4_room_director.gd`（新建）+ 既有 enemy 套件回归
- [ ] T021 [US4] 新建 `Project/systems/rooms/room_director.gd`：监听 `room_entered`/`floor_generated` → 清场 → 按房型+主题权重+难度修正布怪布食（修饰符注入点）。测试套件：`test_l4_room_director.gd`
- [ ] T022 [US4] 多层切换卡：`Project/scenes/game_world.gd` 新增 `reset_for_floor()`（组合既有 clear_enemies/clear_foods/clear_all 原语）；`run_progression_system.gd` 消费 `run.max_floors`。测试套件：`test_l4_room_director.gd` + `test_l3_run_loop.gd` 回归
- [ ] T023 [US4] Build 装备跨层存续专门测试卡：蛇重建后已装鳞片/共鸣/蜕皮余额全部存续（FR-003/FR-013 边界）。测试套件：`test_l4_slots.gd`（跨层存续用例组）
- [ ] T024 [US5] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_floor_rewards.gd`——固定槽位解锁步骤（选前/中/后）先于 3 选 1；三选项恰为高级鳞/升级最低级件/同 tag 换鳞；终层不弹（US5 场景 4）；奖励决议先于 `floor_generated`（US5 场景 5）；全空自动决议。测试套件：`test_l4_floor_rewards.gd`
- [ ] T025 [US5] 重写 `Project/systems/growth/floor_reward_system.gd` 逻辑（判决：重写——草稿 expansion 硬编码 equip、correction 是 pass 的假实现）：实现 §10.3-10.5 模型（FR-007），`floor_index < run.max_floors` 才呈现。测试套件：`test_l4_floor_rewards.gd`
- [ ] T026 [US5] UI 卡：`Project/ui/floor_reward_panel.gd` **基于 ui/kit 构建**为两段式（槽位定位选择 → choice_card×3）。测试套件：`test_l4_floor_rewards.gd`（UIActor 驱动）+ 几何探测
- [ ] T027 [US4+US5] 集成卡：`run_progression_system.gd` 楼层奖励决议**先于** `advance_floor()` 发 `floor_generated`；终层 `floor_completed` → 胜利路径。测试套件：`test_l4_floor_rewards.gd` + `test_l3_run_end.gd` 回归
- [ ] T028 [US4] 多层冒烟卡：新建 `Project/Test/cases/test_l4_multifloor_run.gd`——3 层 PCG 至胜利，全程面板公共 API 驱动（test_l3_smoke_run 模式扩展）。测试套件：`test_l4_multifloor_run.gd`

**T5 收口**: 严格门禁绿 → 合 main。

---

## T6 簇 — 难度缩放 + 房间修饰符（US6，P3）

**Goal**: 层间静态压力递增可感（MUST）；反应式 DDA 隐性、仅测试验证（SHOULD，超时即砍——砍单阶梯首位）；修饰符 v1 双件真正被应用。

**Independent Test**: 自动测试断言层 N+1 生成参数严格更难；模拟过强/过弱 → 生成参数在 clamp 内微调；`shield_enemies`/`preset_status_tiles` 房内效果可见可读。

- [ ] T029 [US6] Red 卡：对照修订版 spec 重写 `Project/Test/cases/test_l4_difficulty.gd`——静态层表缩放 MUST 用例组；反应式 DDA SHOULD 用例组（仅生成参数级断言，**无任何玩家感知措辞**）；clamp 边界。测试套件：`test_l4_difficulty.gd`
- [ ] T030 [US6] 重写 `Project/systems/difficulty/difficulty_scaler.gd`（判决：重写）：修全局 tick 当单房用时（:114）、分母硬编码（:93）；度量改为单房口径并 JSON 化；**唯一消费者 = RoomDirector**；静态层缩放 MUST + 反应式 DDA SHOULD 分层实现。测试套件：`test_l4_difficulty.gd`
- [ ] T031 [US6] 重写-扩展 `Project/systems/difficulty/room_modifier_system.gd`（判决：重写-扩展——草稿从不被应用）：v1 = `shield_enemies` + `preset_status_tiles`（复用状态格视觉，Designs §11.5）；经 RoomDirector 实际应用；逐项 JSON disable。测试套件：`test_l4_difficulty.gd`
- [ ] T032 [P] [US6] 节奏数据验证卡：首层 modifier/elite 权重为 0、2 层起主题蒙色+首修饰+首精英的概念节奏从配置数据生效（SC-010 与 PCG 侧断言互证）。测试套件：`test_l4_config.gd` + `test_l4_pcg_rooms.gd`

**T6 收口**: 严格门禁绿 → 合 main。

---

## T7 簇 — 验收与封口（横切）

**Goal**: 修订版 spec 的 SC-001..SC-012 全量自动验收 + 体验基建覆盖新面板 + 文档清偿。

**Independent Test**: `test_l4_acceptance.gd` 对照 SC 逐条绿；VirtualPlayer 多层冒烟绿；严格门禁 STRICT PASSED；QuickReference/CurrentState 与实现零偏差。

- [ ] T033 重写 `Project/Test/cases/test_l4_acceptance.gd` 对照修订版 spec（SC-001..SC-012 逐条映射，含 SC-012 四 offer 系统空选项自动决议 + 门控用例）。测试套件：`test_l4_acceptance.gd`
- [ ] T034 VirtualPlayer 冒烟卡：`Test/experience/` harness（TickDriver+UIActor）playbook 覆盖鳞片/商店/楼层奖励三类模态响应；pending 无人响应即 FAIL 的防死锁断言；新面板加入契约表（`presentation.game_feel.triggers`）与 stager 状态行。测试套件：`test_l4_multifloor_run.gd` + Layer A 契约
- [ ] T035 [P] Layer C 截图装置骨架卡：建 `Project/AcceptanceShots/` 骨架 + `Tools/run_acceptance_shots.ps1`，S2 Gate 首用（带窗逐状态截图 → AI 读图 findings.md 归档 `AgentOps/`）。证据：findings.md
- [ ] T036 文档清偿卡（/syncdocs）：`TechDocs/QuickReference.md`（L4 实现事实 + RewardFlowSystem 合成 `room_completed` 显式契约注记 + 事件发射方→监听方表全量）、`AgentOps/CurrentState.md`（S2 收口 + S1 Gate-H 补录提醒）、`DailyLogs/`、tasks.md 勾卡核对
- [ ] T037 S2 Gate-A 卡：严格门禁 STRICT PASSED + 套件数核对 + 多层冒烟 + PCG 性质测试 + 几何探测覆盖新面板 + 截图评审证据 → 合 main。Gate-H（不阻塞合入，S3 收口前补录）：层间压力递增可感知（静态缩放）；反应式 DDA 按设计不可见、仅测试验证

---

## Dependencies and Execution Order

- T1 簇阻塞全部后续（配置与契约基线）。
- T2 簇（鳞片链+蜕皮）阻塞 T3（商店消费蜕皮）；T2 内 T004→T005→T010 串行，T006/T009 可并行。
- T3 簇完成后立刻打 MDE tag（T017），此为存活线。
- T4（PCG）独立于 T2/T3，但排在 MDE 之后以保护存活线；T4 阻塞 T5。
- T5 内 T020（EnemyManager 改造）阻塞 T021（RoomDirector）；T024→T025→T026→T027 串行。
- T6 依赖 T021（DifficultyScaler 唯一消费者 = RoomDirector）。
- T7 收口依赖全部前簇。

## Cut Ladder（砍单阶梯，绝不低于 MDE = T017）

反应式 DDA（T030 SHOULD 部分）→ 主题敌池细化 → 修饰符扩展（backlog.md）。
