# Tasks: 程序化美学与游戏手感

**Phase F = Stage S1（先行）；Phase P = Stage S4（系统就位后）。**
每卡 TDD：Red → Green → Refactor → 全量严格回归。

## Phase F — 表现内核与验收基建（S1）

### F-A 配置与主题

- [x] T001 [F-A] `game_config.json` 新增 `presentation` 段（palette/typography/motion/
  layout/glyphs/acceptance/debug_ui，schema 见设计文档 §14）+ ConfigManager accessor
  + 配置契约测试（test_xp_presentation_config）
- [x] T002 [F-A] `ui/kit/theme_builder.gd`：JSON→Theme + `get_contrast_pairs()`；
  单测字号/颜色/对比度对

### F-B UI 内核组件

- [x] T003 [F-B] `ui/kit/kit_panel.gd` 基类：角括号框 _draw + 出生分组/`ui_layer` 元数据/
  `settle()`；单测分组与元数据存在性
- [x] T004 [F-B] `ui/kit/glyph.gd`：`presentation.glyphs` 数据驱动绘制；单测子节点数/颜色
- [x] T005 [F-B] `ui/kit/choice_card.gd` + `banner.gd` + `chip.gd`：组件态与公共 API
  （set_content/set_selected/settle）；单测状态切换

### F-C 仪表缝

- [x] T006 [F-C] TickManager `manual_mode` + `step_once()`（pause 期间无效）；
  扩展 test_t03
- [x] T007 [F-C] VFXManager：参数 JSON 化 + `vfx_invoked` 仪表信号 +
  `shatter_at/ring_at/fly_to_hud`；单测信号发射与参数来源

### F-D 验收基建

- [x] T008 [F-D] `Test/experience/experience_recorder.gd`（四通道 + pending modal 集）
  + `tick_driver.gd`（模态感知步进）+ `ui_actor.gd`（playbook）；单测录制与步进
- [x] T009 [F-D] `Test/experience/state_stager.gd` + `ui_settle.gd` +
  `ui_geometry_probe.gd`（几何五项 + 对比度合成）；探针自测（构造违规场景必须报红）
- [x] T010 [F-D] `test_xp_contracts_l3.gd`：L3 首批契约（模态唯一/reward 流 ui 变化/
  time-to-first-choice）

### F-E L3 面板迁移（kit 首批消费者）

- [x] T011 [F-E] room_intent_panel + floor_progress_panel 迁移 kit；旧测试回归
- [x] T012 [F-E] reward_choice_panel 迁移 kit（choice_card）；旧测试回归
- [x] T013 [F-E] title_screen + game_over_screen + hud 换 kit 样式；
  debug UI 收进 `presentation.debug_ui` 开关
- [x] T014 [F-E] `test_xp_ui_geometry.gd`：全部 L3 面板典型状态几何探测绿

### F-Gate

- [x] T015 [F-Gate] S1 Gate-A：F5 全流程统一设计语言；严格门禁绿；文档同步
  （QuickReference/CurrentState/DailyLog）；Gate-H 设计语言裁定记录
  （Gate-A 通过 2026-06-11：67/67 套件 2897/2897 + STRICT PASSED + 几何探测
  覆盖 title/game_over/l3_run_start/l3_reward_pending；Gate-H 待人工 5 分钟裁定，
  不阻塞 S2 开工，须在 S2 收口前补录于 CurrentState）

## Phase P — 体验完成层（S4，2026-06-12 开工细化；蓝本 = AgentOps/CurrentState「S4 开卡」节）

每卡纪律：TDD Red 先行；每 US 严格门禁绿合 main；EventBus/JSON 契约变更同提交落
QuickReference；appflow 套件入树即 `root.boot(临时路径)`（存档卫生红线）；
kit 零编排红线的解除处 = CeremonyLayer 从外部驱动（S1 铁律的对偶）。

### P-A 基座（US4 前置 + US3 骨架）

- [x] T101 [P-A] TickManager reason-token 暂停（`pause(reason)`/`resume(reason)`，
  原因集合空才真恢复，`start_ticking` 清集合，`get_pause_reasons()` 观察点）+
  hud 手动暂停迁移 `&"manual"`（裁定 #1：仪式 resume 不得吞掉玩家暂停）+
  test_t03 扩展（叠加/幂等/未持有 reason 不解他锁）
- [x] T102 [P-A] AppFlow 四态收口：`GameManager.GameState` 增 SUMMARY（尾部追加保
  int 值；STONE_SELECT 已于 S3 M3 落地）+ 总结屏 = game_over_screen 演进（TitleButton
  回标题 + title_pressed；数据通路 `get_last_run_summary()`/`get_summary_lines()` 既有）+
  标题屏菜单重建（开始/退出/传承石条件项，set_stone_source duck-typed）+
  `CeremonyLayer` 骨架（ui/ceremony_layer.gd，编排宿主：dim 原语 + settle，
  挂 UILayer index 0）+ T/Y 验收捷径保持 debug 开关后 + 新套件 test_xp_appflow
  （SUMMARY 状态/壳层 e2e/JSON ceremony 段契约）

### P-B 仪式与局内体验（US3 余下 + US4）

- [ ] T103 [P-B] 死亡仪式（hitstop 0.1 → 蛇尾到头逐段消散 0.05s/段 → 世界去饱和 →
  dim → 死因中文一行，cause→中文映射 `presentation.death_causes`；tick 脉搏线随消散
  渐灭）+ 胜利仪式（终点格金色扩散环 → dim）+ 局后总结编排（统计行 stagger 滚入 →
  解锁卡 → 石碑卡 → 按钮；与 `run_ended.stats` 一致性 Layer A 断言）
- [ ] T104 [P-B] 房间意图横幅→chip 两段式（0.9s 横幅收缩为顶中 chip + 完成章）+
  楼层小地图（左上，意图色方块 + 路径线 + 当前脉动/完成暗化）+ 选择仪式
  `choice_ceremony`（`pause(&"ceremony")` → dim → 三卡 stagger → 选中卡飞向蛇头 →
  `resume(&"ceremony")`，奖励/鳞片/楼层奖励三模态共用）+ 蜕皮 chip 飞行粒子
  （`currency_changed` 世界坐标 → chip + bounce）+ Build 状态条（底中槽位 glyph +
  等级点 + 共鸣青色连线 + 首次发现横幅）+ 拾取物世界内闪烁标记（§8.7 前半）

### P-C 音频与引导（US5 + US6）

- [ ] T105 [P-C] SFXForge autoload（JSON 合成 AudioStreamWAV，16-bit mono 22050Hz，
  五条实现坑强制遵守）+ AudioManager autoload（8 voice 池 + 50ms 防重 +
  `sfx_invoked` 仪表 + `last_played` 环形缓冲）+ Game-Feel 触发表 MUST #1-8 全量
  （`presentation.game_feel.triggers` 表即契约）+ 强度排序断言
  （segment_loss > hit，JSON 数值比较）+ `audio.enabled=false` 契约全量重跑
- [ ] T106 [P-C] hint_system 认知轻度引导（首次事件 caption chip 3s，≤1 概念/房间，
  已见列表入 meta save——注意 schema_version 兼容；文案 `presentation.hints`）

### P-Gate

- [ ] T107 [P-Gate] AcceptanceShots 全状态截图 + Layer C findings + 3 局 soak +
  S4 Gate（**Gate-H 阻塞封板**：S2 三项 + S3 跨进程持久化人工欠账一并清偿，
  脚本见 CurrentState「Gate-H 欠账」节）+ 文档清偿（QuickReference/CurrentState/
  DailyLog/本文件全勾）
