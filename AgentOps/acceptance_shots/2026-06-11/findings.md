# Layer C 截图评审 — S2 Gate（spec 002 T035 首用）

- **日期**：2026-06-11 ｜ **评审人**：AI（Claude，读图评审）
- **装置**：`Project/AcceptanceShots/acceptance_shots.tscn` 经 `Tools/run_acceptance_shots.ps1` 带窗运行（1280x720）
- **捕获**：7/7 成功（见 `manifest.json`）
- **清单依据**：`Designs/Interactive/presentation_design.md` §12.2

## 逐张判定

### 01_title（标题屏）— PASS
- 构图/留白/层次：居中角括号框面板，大量呼吸留白，层次清晰。PASS
- 设计语言：kit 角标框 + display 字阶标题 + 暗底 palette。PASS
- 无灰框占位 / 无英文 debug 文案（"GreedySnake Roguelite" 为产品名非 debug）。PASS

### 02_l3_run_start（局内起始）— PASS
- 1 秒房型辨认（遮字）：红色横幅 + combat glyph + 红方敌人 → 战斗房。PASS
- HUD 布局合§6：左上楼层进度（1/6 + 路径 glyph 行）、顶中房间意图横幅、左下长度 pips、底缘 tick 脉搏线。PASS
- 横幅标题深字红底为既定设计（banner 按 large 阈值，Layer A 对比度断言在册）。PASS
- 蛇体 = 中央白→灰渐变段列（非占位灰框）。PASS

### 03_l4_scale_pending（鳞片三选一 + 蜕皮 chip）— PASS
- 卡片解剖合§3：glyph 区（六边形近似、选项色）/名称/位置+等级说明/底缘类别色条。PASS
- 放弃入口标注「放弃全部 +6 蜕皮」（数值 = 3×scale_discard，概念透出）。PASS
- 蜕皮 chip 右上首次入账出现（渐进披露），shedskin glyph + 数字。PASS
- 模态唯一：同屏仅一个选择面板。PASS

### 04_l4_shop_open（商店）— PASS
- 货架 4 行（≤5）：鳞片×2 / 扩展槽位 / 蛇头升级，每行价格 chip（蜕皮 glyph + 数字）。PASS
- 头升级上架因奖励房已装蛇头、尾未装备不上架——货架与 build 状态一致。PASS
- 商店蓝横幅 + shop glyph，遮字 1 秒可辨房型。PASS
- 余额双显（面板头 + HUD chip）一致（12）。PASS

### 05_l4_floor_reward_slot（Boss 结算·槽位定位）— PASS
- 两段式第一段：「Boss 结算/选择新槽位位置」+ 前/中/后三卡，slot_empty 虚线方框 glyph。PASS
- 槽位卡底缘绿色条与「新增 1 个鳞片槽位」说明可读。PASS

### 06_l4_floor_reward_choice（Boss 结算·三选一）— SUSPECT（布景代表性，非缺陷）
- 面板结构合契约：「楼层 1 奖励/三选一」+ choice_card×3。PASS
- **SUSPECT**：三卡全为「扩展」——布景态零装备，强化/修正无合格目标，按 Edge Case
  以高级鳞替补属 spec 行为；但该镜头未展示三类各一的典型形态（典型形态由
  `test_l4_acceptance` SC-004 断言覆盖）。**建议**：后续给 stager 该状态预装 1 片鳞，
  让 Layer C 镜头呈现三类各一（S4 仪式化前顺手）。不阻塞 Gate。

### 07_l4_multifloor_midrun（pcg 第 2 层局中）— PASS（1 项整容级 SUSPECT）
- 多层证据：路径 glyph 行与第 1 层不同（房序异）、蜕皮 12 跨层存续、第 2 层敌数 4
  （3 + 静态 delta 1）——**层间压力在画面上可感（Gate-H「层间压力可感知」的静态侧证据）**。PASS
- 状态格（绿十字）预置可见——修饰符/状态系统视觉在场。PASS
- **SUSPECT（整容级）**：进房过渡的「GO!」金色大字被定格在画面中——截图时点仪式 tween
  尚未沉降（ui_settle 只沉降 kit 组件，不含 GameTransition）。仅影响截图美观，
  不影响判读；S4 CeremonyLayer 落地时让装置等过渡完成或纳入 settle。不阻塞 Gate。

## 横切检查

| §12.2 项 | 判定 | 说明 |
|---|---|---|
| 构图/留白/层次 | PASS | 七张均无拥挤/压字/悬空元素 |
| 遮字 1 秒辨房型 | PASS | 战斗红/商店蓝横幅 + glyph 形状词汇一致 |
| 无灰框占位 | PASS | 全部面板为 kit 设计语言；中央灰渐变为蛇体本体 |
| 无英文 debug 文案 | PASS | 仅产品名与「GO!」仪式字（非 debug）；debug UI 默认关验证在几何套件 |
| palette 合规目视抽查 | PASS | 暗底/红绿蓝语义色/金色强调与 §2 语义角色表一致 |
| 主题视觉差异（楼层蒙色） | 预期空缺 | 第 2 层无主题蒙色——主题表现属 S4（floor_theme_set 已发射，表现层未消费），非本阶段缺陷 |

## 结论

**Gate 判定：通过（7 PASS，2 SUSPECT 均不阻塞）。**
SUSPECT 两项（06 布景代表性、07 GO! 定格）已登记为 S4 顺手项，不构成 spec 002 验收缺陷。
