# 表现层设计 —「网格信号」(Grid Signal)

> 本文档是 GreedySnake 表现层（视觉/听觉/手感/屏幕流程）的 source of truth，
> 由 SpecKit 004 (`004-presentation-experience`) 实现：Phase F（表现内核）+ Phase P（体验完成层）。
> 吸收并取代 `visual_feedback_design.md` 的第三层规划（见 §13）；第一、二层的既有实现继续有效。
> 所有数值/颜色/时长入 `game_config.json` 的 `presentation` 段，零硬编码（宪法条款）。

---

## 1. 美学宣言

**一切皆为网格上的发光几何信号。**

- **色彩 = 语义**：颜色只用来表达"这是什么/这属于哪个系统"，绝不装饰。
- **形状 = 身份**：方=玩家与世界，菱=敌意，十字=异类，括号角标=界面。
- **节奏 = 游戏状态**：0.25s 的 tick 是全游戏的心跳；游戏层动效与 tick 同拍，
  底缘 tick 脉搏线是这颗心跳的可视化（死亡时脉搏线随蛇身消散一起熄灭）。
- **玩家是全场唯一的无彩色实体**：蛇保持灰阶（HEAD 0.95 / BODY 0.78 / TAIL 0.6），
  无论战场多乱，玩家永远一眼找到自己。
- **克制**：同屏语义色 ≤ 5 族；没有信息的地方就是深色背景；静默不是缺陷而是留白。

## 2. 色彩系统（JSON: `presentation.palette`）

### 2.1 语义角色表

| token | hex | 角色 |
|---|---|---|
| `bg_deep` | `#0B0E11` | 最深背景（屏幕底色/dim 目标色） |
| `bg_panel` | `#12161C` | 面板底色 |
| `bg_panel_raised` | `#1A2026` | 卡片/浮起元素底色；网格线同色 |
| `wall` | `#2A323B` | 墙体/边界 |
| `text_primary` | `#E8ECEF` | 主文本 |
| `text_dim` | `#8A949E` | 次要文本/caption |
| `frame_line` | `#3A444F` | 角括号框线 |
| `status_fire` | `#FF6B35` | 火（提亮校正，旧 `#FF4500`） |
| `status_ice` | `#7FD1F0` | 冰（提亮校正，旧 `#ADD8E6` 近似保留） |
| `status_poison` | `#6FBF3F` | 毒（提亮校正，旧 `#006400` 对深背景对比不足） |
| `room_combat` | `#B84444` | 战斗意图（沿用） |
| `room_reward` | `#D9B44A` | 奖励意图（沿用） |
| `room_rest` | `#4A9B78` | 休整意图（沿用） |
| `room_endpoint` | `#7D63B8` | 终点/Boss 意图（沿用） |
| `room_shop` | `#4A8FB8` | 商店意图（新增，L4） |
| `room_elite` | `#C2185B` | 精英意图（新增，L4） |
| `accent_shedskin` | `#D1A642` | 蜕皮货币金 |
| `accent_resonance` | `#4FE3C1` | 共鸣青 |
| `accent_danger` | `#FF3B30` | 危险/警告红 |
| `accent_confirm` | `#9CCC65` | 确认/完成绿 |

### 2.2 校正与迁移规则

- 实体层旧状态色（fire `#FF4500` 等）由各自 JSON `visual`/`color` 字段迁移到 palette token
  引用；**迁移分期进行**（Phase F 先迁 UI 层，实体层校正随 Phase P 调色卡），但新代码一律
  只引用 token，不写裸 hex。
- 配置中残留的 `placeholder_color` 字段语义升级为正式色，字段名保留兼容（避免无谓 churn），
  QuickReference 记录该决定。
- 同屏语义色 ≤ 5 族规则：背景族+玩家灰阶不计；状态族/敌意族/房间意图族/强调色按实际出现计。

## 3. 形状词汇表

- **蛇**：方格 75% 填充（既有）；**蛇头方向缺口**（Phase P）：头格朝移动方向开 8px 缺口。
- **敌人**：粉方 / 红菱 / 紫十字（既有，不动）；精英 = 同形状 1.25 倍 + `room_elite` 色描边。
- **食物**：40% 小方格脉动（既有二层项）。
- **UI 签名母题「角括号框」**：面板不画完整边框——四角各一个 8px 的 L 形角标
  （`frame_line` 色，2px 粗）+ `bg_panel` 底。这是"界面"区别于"世界"的唯一记号。
- **图标 (glyph)**：全部由 ≤4 个矩形组合，程序绘制（`ui/kit/glyph.gd`，数据定义在
  `presentation.glyphs`）。基础集：
  | id | 构成 | 用途 |
  |---|---|---|
  | `combat` | 两条 45° 交叉杠 | 战斗房 |
  | `reward` | 旋转 45° 的方（菱形） | 奖励房/奖励 |
  | `rest` | 一条横杠 | 休整房 |
  | `endpoint` | 同心双方框 | 终点/Boss |
  | `shop` | 上横杠+下方块（摊位） | 商店 |
  | `elite` | 菱形+中心点 | 精英 |
  | `shedskin` | 竖菱 | 蜕皮货币 |
  | `scale` | 六边形近似（三矩形叠转） | 鳞片 |
  | `head` / `tail` | 方+方向缺口 / 渐细三矩形 | 蛇头/蛇尾 Build 件 |
  | `slot_empty` | 虚线方框（四短杠） | 空槽位 |
- **卡片解剖**（choice_card）：上=glyph 区（48px）；中=名称（heading）；下=效果说明
  （body，≤2 行）；底缘 4px 色条 = 标签/类别色。选中态：外框亮起 + scale 1.05。

## 4. 字体与文字（JSON: `presentation.typography`）

- **字体**：Godot 4 内置默认字体（自带 CJK fallback，零外部资产）。
- **字号阶梯**：`display: 48 / title: 32 / heading: 20 / body: 16 / caption: 13`。
- 拉丁标题可全大写；数字场合保持同字号对齐。
- 文本永不直接落在战场上：必须有 `bg_panel`(α≥0.85) 底或处于 dim 层之上。

## 5. 动效语言（JSON: `presentation.motion`）

- **游戏层动效时长量化到 tick**：`{half_tick: 0.125, one_tick: 0.25, two_ticks: 0.5}`，
  实体反馈只允许取这三档。
- **UI 仪式层**：0.3–0.6s 区间；超过 0.6s 的只有死亡/胜利仪式。
- **标准缓动表**：
  | 角色 | 曲线 | 用途 |
  |---|---|---|
  | `enter` | QUINT / EASE_OUT | 元素入场 |
  | `exit` | CUBIC / EASE_IN | 元素退场 |
  | `feedback` | CUBIC / EASE_OUT | 命中/数值变化 |
  | `acquire` | BACK / EASE_OUT | "获得"类事件（弹跳感） |
- 列表/卡片 stagger：0.04s/项。
- 全部时长、强度、stagger 入 `presentation.motion`，VFXManager/kit 从 ConfigManager 读取。

## 6. 空间与 HUD 布局（JSON: `presentation.layout`）

- 基准单位 16px（半格）；屏幕边距 16px；面板 padding 16px；最小命中目标 32×32px。
- 窗口 1280×720，战场即全屏（1280×704），持久 HUD 用半透明 chip 浮于其上：

```
┌──────────────────────────────────────────────┐
│ [楼层小地图]      [房间意图 chip]    [蜕皮 chip] │ ← 顶部 16px 起
│                                              │
│                  (战场 40×22)                 │
│                                              │
│ [长度/受击]       [Build 状态条]               │ ← 底部
│ ━━━━━━━━━━━ tick 脉搏线（底缘 2px，保留）━━━━━━ │
└──────────────────────────────────────────────┘
```

- 仪式（选择/死亡/胜利）使用全屏 dim 层（`bg_deep` α0.7）+ 居中内容。

## 7. 屏幕流程（Phase P 实现，本节为设计契约）

**架构**：单一 `main.tscn` AppFlow，屏幕为 UILayer 子 Control，不切场景
（autoload 状态存续、headless 可测）。**状态枚举属 GameManager**
（新增 `STONE_SELECT`、`SUMMARY` 入 `GameManager.GameState`），main.gd 只做可见性切换。
T/Y 验收捷径保留，收进 `presentation.debug_ui` 开关。

> 落地进度（2026-06-11，spec 003 M3）：`STONE_SELECT` 枚举（尾部追加保既有 int 值）、
> 传承石选择屏（`ui/stone_select_screen.gd`，kit modal：横排石碑卡 + 轻装上阵 +
> ←/→/数字/回车/鼠标）与「开始/再来一局 → 有石选石 / 空石直进」分流已提前落地；
> `SUMMARY`、入局横幅、死亡/胜利仪式等编排仍属 Phase P。

```
TITLE ──开始──> (有传承石? STONE_SELECT : RUN) ──run_ended──> SUMMARY ──再来──> STONE_SELECT/RUN
  ^                                                                  └──回标题──> TITLE
```

| 屏 | 内容 | 驱动 |
|---|---|---|
| 标题 | display 级标题 + 角括号框菜单（开始/退出；有石碑时多一项） | UI 本地 |
| 传承石选择 | 横排石碑卡（≤5）+「轻装上阵」跳过；**石碑列表为空时整屏跳过** | meta 存档 |
| 入局横幅 | 「第 N 层」全宽横幅 0.8s | `run_started`/`floor_generated` |
| 房间切换 | 0.2s 淡入淡出（列扫 wipe 为 Could）+ 房间意图横幅（§8） | `room_entered` |
| 死亡仪式 | hitstop 0.1 → 蛇尾到头逐段消散（0.05s/段）→ 世界去饱和 → dim → 死因一行（cause→中文映射入 JSON）| `snake_died`→`game_over`→`run_ended` |
| 胜利仪式 | 终点格金色扩散环 → dim → 进总结 | `run_victory`→`run_ended` |
| 局后总结 | 统计行 stagger 滚入 → 解锁卡翻出 → 「遗愿铸成」石碑卡 → 按钮 | `run_ended(stats)` + 缓存的 `content_unlocked`/`legacy_stone_created` |

## 8. 局内体验（Phase P 实现，设计契约）

1. **房间意图两段式**：进房全宽横幅（房色扫入 + display_name + intent_label）0.9s
   后收缩为顶中 chip（glyph + 进度 `2/3`）；完成时 chip 盖「完成」章。
   Should：墙体色调向房间意图色偏移 30%（不读字也能"感到"房型）。
2. **楼层小地图**（左上）：房间 = 意图色小方块沿路径连 1px 线；当前 = 外框脉动；
   完成 = 暗化+中心点；未达 = 深灰。
3. **选择仪式**（奖励/鳞片/楼层奖励共用 `choice_ceremony`）：
   `TickManager.pause(&"ceremony")` → dim 0.6 → 三卡 stagger 升起 → ←→/1-3/鼠标选择 →
   确认后选中卡飞向蛇头/Build 条，余卡坠落 → `resume(&"ceremony")`。
   底部恒有次选项「放弃 +N 蜕皮」（接 `scale_option_discarded`）。
4. **商店**：进店侧栏紧凑态，Tab 展开全屏卡阵；余额不足卡片去饱和；购买 = 盖章 + 金币音。
5. **蜕皮 chip**（右上）：`currency_changed` 时从事件世界坐标飞出 `+N` 金色粒子到 chip
   （world→screen 投影）+ chip bounce。**首次获得蜕皮时 chip 才出现**（渐进披露）。
6. **Build 状态条**（底中）：`[头][前][中…][后][尾]` 槽位 glyph；空槽 = 虚框；
   装备/升级 = glyph bounce + 等级点；共鸣 = 相邻 glyph 间青色连线 +
   首次发现横幅「共鸣发现：沸毒」（`resonance_activated.is_new_discovery` 已有）。
7. **拾取物**：世界内闪烁标记 + 顶部 chip 行。
8. **认知轻度引导（hint_system）**：无教程屏。监听首次事件（首食/首受击/首状态格/
   首奖励/首共鸣…），底中浮现一行 caption chip 3s；每条仅一次，已见列表入 meta 存档；
   文案全部在 `presentation.hints`。**≤1 条新概念 caption / 房间**。
   概念出场节奏由 L4 配置数据强制（首层无修饰符/无精英；商店保底在 ≥2 战斗房后；
   Boss 仪式内教学槽位解锁与楼层奖励；石碑选择第二局才首次出现）。

## 9. Game-Feel 触发表（JSON: `presentation.game_feel.triggers`）

**本表 = 运行时 juice 绑定 = 验收契约**（Layer A 直接读同一份 JSON 断言，文档不漂移）。

| # | 事件 | 视觉 | 音频 | hitstop | 级 |
|---|------|------|------|---------|---|
| 1 | `snake_food_eaten` | 头 scale_bounce + `+1` popup；连吃音高 +1 半音（4s 衰减） | `eat` | — | MUST |
| 2 | `enemy_killed` | 敌色 shatter_at + shake 2 | `kill` | 0.03 | MUST |
| 3 | `snake_body_attacked` | 既有 lunge/红闪/shake + 受击 pip 充能 | `hit` | — | MUST |
| 4 | `snake_length_decreased` | 段位 shatter(灰) + 全屏红 flash 0.1 + shake 4 | `segment_loss` | 0.05 | MUST |
| 5 | `reaction_triggered` | 既有区域闪光 + ring_at + **反应名 popup（命名教学）** | `reaction_*`(3 种) | — | MUST |
| 6 | 死亡仪式 | §7；tick 脉搏线渐灭 | `death` 下行扫频 1.2s | 0.1 | MUST |
| 7 | `room_completed` | chip 盖章 +（Should）墙体房色脉冲 | `room_clear` 两音上行 | — | MUST |
| 8 | `*_presented`/`*_chosen` | 选择仪式 §8.3 | `card_in`×3 stagger / `confirm` | — | MUST |
| 9 | `resonance_activated` | 连线 + 横幅 | `resonance` 琶音 | 0.4s 顿 | SHOULD |
| 10 | `floor_completed`/`run_victory` | 金色扫场 + rect 纸屑 | `victory` 和弦 | — | SHOULD |
| 11 | `status_applied`(蛇) | 头顶状态色小块上浮（二层残留项） | `status_*` | — | SHOULD |
| 12 | 移动拖尾/食物脉动 | 二层残留项收编 | — | — | SHOULD |

**强度排序硬约束**：`segment_loss` 的 hitstop/shake 数值必须 > `hit`（丢段重于受击），
Layer A 从 JSON 比较断言。
**JSON 开关**：`presentation.game_feel.enabled`、`presentation.audio.enabled`、
每条 trigger 可单独 `enabled: false`（宪法：重特效可禁用）。

## 10. 音频体系（JSON: `presentation.audio`）

- **SFXForge**（autoload）：启动时按 `presentation.audio.sfx` 合成 `AudioStreamWAV`。
  参数 schema：`{wave: sine|square|triangle|noise, freq_start, freq_end, duration,
  attack, decay, noise_mix, volume}`；16-bit mono 22050Hz，~150 行 DSP。
- **AudioManager**（autoload）：8 voice `AudioStreamPlayer` 池；仅监听 EventBus；
  同音效 50ms 防重（`Time.get_ticks_msec()`）；总线音量入 JSON；
  仪表信号 `sfx_invoked(sfx_id)` + `last_played` 环形缓冲（Layer A 观察点）。
- **音乐：本阶段不做**。SFX-only；房间氛围 drone 为 Could。
- **五条实现坑（强制遵守）**：
  1. 只用 `FORMAT_16_BITS`（Godot 的 8-bit 是有符号的，经典踩坑）+ `encode_s16` 小端；
  2. 测试中禁止 `await finished`（headless dummy driver 可能不推进播放）；
  3. autoload 顺序排在 ConfigManager 之后；
  4. 防重用 `Time.get_ticks_msec()` 差值，不用 Timer；
  5. 若 JSON 定义总线，boot 时用代码创建总线。

## 11. 技术约束

1. **表现层只听不驱动**：`ui/`、VFX、Audio 只监听 EventBus / 调用注入系统的公共方法
   （choice 类面板调用 `choose_*` + `room_advance_requested` 沿用既有契约），
   绝不直接改游戏状态。
2. **暂停 reason-token**（Phase P）：`TickManager.pause(reason: StringName)` /
   `resume(reason)`，原因集合空才真恢复；hud 手动暂停迁移到 `&"manual"`，
   仪式用 `&"ceremony"`——防止仪式 resume 吞掉玩家暂停。
3. **kit 组件零编排**：Phase F 的组件只有 hover/press/disabled 态；
   pause/dim/stagger/飞行编排全部属于 Phase P 的 CeremonyLayer，从外部驱动。
4. **仪表缝**：VFXManager `vfx_invoked(fx_name, args)`、AudioManager `sfx_invoked`、
   TickManager `manual_mode`+`step_once()`（is_ticking=false 时步进无效）——挂在各自单例上，
   不挂 EventBus（不是游戏事件）。
5. **kit 组件出生即带**：分组（`ui_kit`/`ui_modal`/`ui_chip`/`ui_dim`/`ui_hit`）、
   `ui_layer` 元数据（`modal|dim|hud|toast`）、`settle()`（活动 Tween 快进到终态）、
   `ui_allow_truncate` 元数据（刻意省略号须显式声明）。
6. Tween 预算同屏 ≤50、ColorRect ≤200（沿用既有约束）；z-index 层级沿用既有表。
7. debug UI（debug_panel/event_log_panel/kill_feed/build_test_panel）收进
   `presentation.debug_ui` 开关，豁免设计语言迁移。

## 12. 体验验收清单（三分法）

### 12.1 机器层（Layer A 契约 + Layer B 几何，进严格门禁，每次测试）

- 每个 MUST trigger：事件后 K tick 内出现约定 {vfx, sfx, ui} 反馈（命令层断言）。
- 模态唯一：pending `*_presented` ≤1；pending 期间 `step_once()==false`（Phase P 起）；
  决议后 tick 连续无跳变。
- 节奏预算：time-to-first-choice ≤ `acceptance.time_to_first_choice_max_ticks`；
  战斗中无反馈死气 > `acceptance.dead_air_max_ticks`。
- 强度排序：`segment_loss` > `hit`（hitstop/shake JSON 数值比较）。
- 几何五项（每个典型状态，沉降态探测）：同层可见不透明节点无相交（`ui_layer` 矩阵豁免）；
  Label 文字适配（无未声明截断）；视口内；命中目标 ≥32px；模态可见数 ≤1。
- 对比度：theme 静态对 + 运行时有效底色合成，比值 ≥ 4.5（body）/ 3.0（大字）。
- `audio.enabled=false` 时全部契约仍绿（关音频完整可玩）。
- 3 局 soak：连续三局全循环无报错、无残留 UI。

### 12.2 AI 视觉层（Layer C 截图评审，Stage Gate 时）

- 全部典型状态截图（与 A/B 共用 StateStager）；逐张对照：
  构图/留白/层次；**遮住文字只看色彩与 glyph 能否 1 秒辨认房型**；
  全图无灰框占位、无英文 debug 文案、无设计语言外的元素；palette 合规目视抽查。
- 产出 `AgentOps/acceptance_shots/<date>/findings.md` 作为 Gate 证据。

### 12.3 人工终审层（Gate-H，S4/S5 阻塞）

- 30 秒上手可理解（不看文档开始并理解一局）。
- 动态手感：丢段打击感**体感上**重于受击；缓动"对味"；hitstop 节奏舒服。
- 死后 5 秒能说出死因；总结屏与本局行为一致。
- 音频品味：不刺耳、不疲劳。
- 综合「作品感」裁定。

## 13. 与 visual_feedback_design.md 的关系

- 该文档第一层（状态色/敌人形状/反应闪光/受伤反馈）**已实现且继续有效**，
  色值经 §2.2 校正表逐步迁移 token。
- 第二层未完项（拖尾/死亡逐段消散/食物脉动/状态上浮）**收编**为本文档 §9 触发表
  #6/#11/#12，随 Phase P 落地。
- 第三层（粒子/Shader/精灵/音频）**由本文档取代**：粒子方向改为 `shatter_at` 色块碎片
  （更符合美学且 headless 安全）；Shader/精灵不在本阶段范围；音频按 §10。
- `visual_feedback_design.md` 头部加状态行指向本文档，不再扩写。

## 14. `presentation` JSON Schema 总览

```jsonc
"presentation": {
  "palette": { "bg_deep": "#0B0E11", ... },                  // §2
  "typography": { "display": 48, "title": 32, "heading": 20, "body": 16, "caption": 13 },
  "motion": {
    "durations": { "half_tick": 0.125, "one_tick": 0.25, "two_ticks": 0.5 },
    "ceremony_range_sec": [0.3, 0.6],
    "stagger_per_item": 0.04,
    "easing": { "enter": "quint_out", "exit": "cubic_in", "feedback": "cubic_out", "acquire": "back_out" }
  },
  "layout": { "base_unit": 16, "screen_margin": 16, "panel_padding": 16, "min_hit_target": 32 },
  "ceremony": {                                               // §7/§8 仪式编排参数（Phase P 增量）
    "dim_alpha": 0.6, "dim_sec": 0.3,                         // §8.3 "dim 0.6" 的 JSON 落点
    "death_hitstop_sec": 0.1, "dissolve_per_segment_sec": 0.05, // §7 死亡仪式（hitstop 0.1 / 0.05s/段）
    "desaturate_alpha": 0.55, "desaturate_sec": 0.4,          // §7 世界去饱和（§13 无 shader——灰罩近似）
    "cause_hold_sec": 0.8, "victory_ring_token": "accent_shedskin" // 死因停留 / §7 胜利金色扩散环色
  },
  "glyphs": { "combat": [ {"rect": [x,y,w,h], "rotation": 45}, ... ], ... },  // §3
  "game_feel": { "enabled": true, "triggers": { ... } },      // §9
  "audio": { "enabled": true, "master_volume_db": -6, "dedup_ms": 50, "sfx": { ... } },  // §10
  "hints": { "first_food": "...", ... },                      // §8.8
  "death_causes": { "hit_self": "吞到了自己", ... },           // §7 死亡仪式（键 = snake.die(cause) 实际死因 + victory/unknown；缺键回退原文）
  "acceptance": {                                             // §12.1 阈值
    "feedback_window_ticks": 1, "max_pending_modals": 1,
    "time_to_first_choice_max_ticks": 120, "dead_air_max_ticks": 12,
    "contrast_min_body": 4.5, "contrast_min_large": 3.0,
    "overlap_tolerance_px2": 4, "opaque_alpha": 0.5
  },
  "debug_ui": false
}
```
