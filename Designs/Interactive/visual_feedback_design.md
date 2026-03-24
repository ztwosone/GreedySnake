# 视觉反馈交互设计方案

> 纯色块风格下的最小可验证视觉反馈体系。所有效果基于 ColorRect + Tween，不引入精灵图或 Shader。
>
> **实现状态：** T26 第一层视觉反馈 ✅ 已完成（2026-03-24，1017 测试通过）

---

## 设计原则

1. **即时可读性**：玩家在 0.3 秒内能识别「发生了什么」
2. **层次分明**：状态格（地板层）→ 实体状态（实体层）→ 反应/事件（覆盖层）
3. **最小实现**：优先用颜色、透明度、闪烁频率区分，避免过度设计
4. **纯色块风格**：32×32 格子，所有视觉元素为 ColorRect，保持统一美学

---

## 第一层：最低限度视觉反馈（T26 — L2 之前必须完成）

### 1.1 蛇身状态指示 ✅

蛇段在携带状态时，通过覆盖层和边框显示状态。每段独立携带一种状态（L1 不存在多状态共存）。

**蛇基础颜色**：白/灰渐变（HEAD=0.95, BODY=0.78, TAIL=0.6 灰度），与毒绿色区分。

| 状态 | 视觉表现 | 实现方式 | 状态 |
|------|----------|----------|------|
| 灼烧 (fire) | 红橙边框（比色块大 6px）+ 0.5s alpha 闪烁 (0.3-0.9) + 半透明红覆盖层 (alpha=0.3) | `_border_rect` + Tween loop + `_status_overlay` | ✅ |
| 冰冻 (ice) | 蓝色覆盖层 (0.4, 0.6, 1.0, alpha=0.55) | `_status_overlay` 直接着色 | ✅ |
| 中毒 (poison) | 绿色覆盖层 + 1s 周期脉动 (alpha 0.25-0.55) | `_status_overlay` + Tween loop | ✅ |

**敌人也使用相同的状态视觉系统**（`_apply_status_visual`），携带状态时显示对应颜色。

### 1.2 冰冻/减速反馈

| 状态 | 视觉表现 |
|------|----------|
| 减速 (ice layer1) | 蛇身变蓝 + 移动间隔明显变长（per-entity 速度已实现） |
| 完全冻结 (ice layer2) | 蛇身变白 + 完全停止移动 + 2 秒后自动恢复 |

无需额外动画，颜色变化 + 移动节奏变化已足够传达信息。

### 1.3 攻击与击杀反馈 ✅

> **注意**：原设计的「蛇身碾压」已改为「敌人主动攻击蛇身」模型。

| 事件 | 视觉表现 | 实现方式 | 状态 |
|------|----------|----------|------|
| 敌人攻击蛇段 | 敌人冲刺 (lunge_toward) + 红色粒子爆发 + 蛇段红闪 + 轻微屏幕震动 | VFXManager API | ✅ |
| 蛇头吃敌人 | 缩放弹跳 (scale_bounce) + 粒子爆发 | VFXManager API | ✅ |
| 敌人死亡 | 敌人缩小消失 (0.2s) | Tween `scale` 从 1.0 → 0.0 | ✅ |

### 1.4 敌人类型视觉区分 ✅

| 敌人类型 | 颜色 | 形状 | 实现方式 | 状态 |
|----------|------|------|----------|------|
| Wanderer 游荡者 | 粉红 #CC1A4D | 方形 | 75% ColorRect | ✅ |
| Chaser 追踪者 | 红色 #FF2020 | 菱形（45° 旋转） | `rotation = PI/4`，缩小至 60% | ✅ |
| Bog Crawler 毒沼匍匐者 | 暗紫 #6B2D8B | 十字形 | 两个交叉 ColorRect 组合 | ✅ |

敌人携带状态时叠加对应覆盖层颜色（与蛇段状态视觉一致）。

### 1.5 受伤反馈 ✅

| 事件 | 视觉表现 | 实现方式 | 状态 |
|------|----------|----------|------|
| 蛇受到伤害（长度减少） | 蛇全身红闪 1 次 (0.15s) | 所有蛇段 modulate 变红再恢复 | ✅ |
| 蛇长度危险 (≤3) | 蛇身持续红色脉动 | Tween `modulate` 循环，频率随长度降低加快 | ✅ |

### 1.6 反应视觉 ✅

| 反应 | 视觉表现 | 状态 |
|------|----------|------|
| 蒸腾 (steam) | 白色区域闪光 0.5s | ✅ (ReactionVFX) |
| 毒爆 (toxic_explosion) | 黄绿色区域闪光 0.6s | ✅ (ReactionVFX) |
| 冻疫 (frozen_plague) | 冰蓝色区域闪光 | ✅ (ReactionVFX) |

---

## 第二层：手感提升（L2 期间逐步加入）

### 2.1 蛇移动拖尾
- 尾部最后 1 段在移动时留下 1 帧半透明残影
- 实现：移动时在旧位置创建 ColorRect，Tween 0.2s 淡出
- 让移动感更流畅，弥补格子化移动的生硬感

### 2.2 状态获取提示
- 蛇头进入状态格时，头顶 popup 状态类型小图标（纯文字：🔥❄️☠️ 或色块标记）
- 持续 0.5s 上浮消失
- 实现：Label 或 ColorRect + Tween position.y 上移 + alpha 淡出

### 2.3 死亡特效
- 蛇死亡时，从尾到头逐段消散（每段间隔 0.05s）
- 每段缩小 + 淡出
- 实现：反向遍历 body，每段 delay 递增的 Tween

### 2.4 食物视觉增强
- 食物轻微脉动（scale 在 0.9~1.1 间循环）
- 被吃时弹出 +1 数字标签上浮消失

---

## 第三层：打磨级（L3 或更晚）

- GPUParticles2D 粒子系统（火焰粒子、冰晶碎片、毒雾）
- Shader 效果（灼烧扭曲、冰冻结晶、中毒色相偏移）
- 精灵图替换 ColorRect（蛇身分段贴图、敌人立绘、状态格纹理）
- 画面抖动（Screen shake）参数化系统
- 音效集成（与视觉反馈同步触发）

---

## 技术实现约束

1. **所有动画使用 Tween**，不使用 AnimationPlayer（保持代码驱动，便于测试）
2. **颜色配置走 JSON**，`game_config.json` 中为每种状态/敌人定义 `visual` 字段
3. **性能预算**：同屏 Tween 不超过 50 个，ColorRect 不超过 200 个
4. **Z-index 层级**：
   - 0: GridBackground
   - 1: StatusTile
   - 2: Food
   - 3: Enemy
   - 4: Snake
   - 10: VFX overlay (reactions, crush flash)
   - 15: HUD popup (status gain, damage numbers)
5. **蛇段状态视觉不影响碰撞/逻辑**，纯表现层

---

## 信号接口

T26 实现监听的信号（均存在于 EventBus）：

| 信号 | 用途 | 状态 |
|------|------|------|
| `status_applied` | 敌人状态色变更 | ✅ |
| `status_removed` | 敌人状态色恢复 | ✅ |
| `snake_body_attacked` | 攻击闪光 + 屏幕震动 | ✅ |
| `enemy_killed` | 敌人缩小消失动画 | ✅ |
| `length_decrease_requested` | 受伤红闪 | ✅ |
| `reaction_triggered` | 反应区域闪光 | ✅ |

> **注意**：蛇段状态视觉不通过信号驱动，而是在 `SnakeSegment.set_carried_status()` / `apply_status_visual()` 中直接更新。

## VFXManager（集中式 VFX API）

新增 `VFXManager` autoload 单例，提供统一的视觉效果 API：

| 方法 | 用途 |
|------|------|
| `flash_entity(node, color)` | 实体颜色闪烁 |
| `scale_bounce(node, scale, duration)` | 缩放弹跳 |
| `burst_at(pos, color, radius, duration)` | 位置粒子爆发 |
| `lunge_toward(node, target_pos)` | 冲刺动画（敌人攻击用） |
| `screen_shake(intensity, duration)` | 屏幕震动 |
