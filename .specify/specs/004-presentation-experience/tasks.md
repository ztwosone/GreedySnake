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

- [ ] T008 [F-D] `Test/experience/experience_recorder.gd`（四通道 + pending modal 集）
  + `tick_driver.gd`（模态感知步进）+ `ui_actor.gd`（playbook）；单测录制与步进
- [ ] T009 [F-D] `Test/experience/state_stager.gd` + `ui_settle.gd` +
  `ui_geometry_probe.gd`（几何五项 + 对比度合成）；探针自测（构造违规场景必须报红）
- [ ] T010 [F-D] `test_xp_contracts_l3.gd`：L3 首批契约（模态唯一/reward 流 ui 变化/
  time-to-first-choice）

### F-E L3 面板迁移（kit 首批消费者）

- [ ] T011 [F-E] room_intent_panel + floor_progress_panel 迁移 kit；旧测试回归
- [ ] T012 [F-E] reward_choice_panel 迁移 kit（choice_card）；旧测试回归
- [ ] T013 [F-E] title_screen + game_over_screen + hud 换 kit 样式；
  debug UI 收进 `presentation.debug_ui` 开关
- [ ] T014 [F-E] `test_xp_ui_geometry.gd`：全部 L3 面板典型状态几何探测绿

### F-Gate

- [ ] T015 [F-Gate] S1 Gate-A：F5 全流程统一设计语言；严格门禁绿；文档同步
  （QuickReference/CurrentState/DailyLog）；Gate-H 设计语言裁定记录

## Phase P — 体验完成层（S4，占位，开工时细化）

- [ ] T101 [P] TickManager reason-token 暂停 + hud 迁移 + test_t03 扩展
- [ ] T102 [P] AppFlow 四态（GameManager.GameState 扩展）+ 标题屏重建 + StoneSelect/
  RunSummary 屏 + CeremonyLayer
- [ ] T103 [P] 死亡/胜利仪式 + 局后总结
- [ ] T104 [P] 房间横幅→chip + 楼层小地图 + 选择仪式 + 蜕皮 chip + Build 状态条
- [ ] T105 [P] SFXForge + AudioManager + 触发表 MUST #1-8 全量 + 强度排序断言
- [ ] T106 [P] hint_system 认知轻度引导
- [ ] T107 [P] AcceptanceShots 装置 + Layer C 评审 + S4 Gate
