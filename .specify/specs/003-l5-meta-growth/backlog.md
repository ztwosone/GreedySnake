# Backlog: L5 Meta Growth（范围外收容，2026-06-11）

> 本文件收容 2026-06-11 S3 重验收治理中明确移出 spec 003 v1 范围的内容。
> 任何条目回归 scope 需走 spec 修订 + 用户确认（设计先行红线）。

## 来自 US1 / Designs §12.3（解锁目标——内容尚未设计）

> 红线：解锁目标必须存在于 `game_config.json` 的 `snake_heads` / `snake_tails` 内容池
> （Designs §12.3 附录「v1 内容映射」）。以下目标的内容 JSON 不存在，条件指向虚空。

| 条目 | 设计出处 | 移出理由 |
|------|----------|----------|
| 彩虹蛇 Ungud（蛇头，单局转向 >200 次解锁） | Designs §12.3 | `snake_heads.ungud` 未设计；草稿 `unlock_conditions.turns_200` 随 M2 移除。内容设计完成后回归 §12.3 愿景条件。 |
| 美杜莎 Medusa（蛇头，反应击杀 >15 解锁） | Designs §12.3 | `snake_heads.medusa` 未设计；其条件式样（状态联动发现）已由 v1 bai_she 条件（reaction_kills ≥ 10）承接。 |
| 饕餮 Taotie（蛇头，低长度存活 >60s 解锁） | Designs §12.3 | `snake_heads.taotie` 未设计；`survival_low_length_ticks` 度量 M1 已落地，内容设计完成即可挂回条件。 |
| 冥尾 Styx Tail（蛇尾，「死里逃生」事件后通关解锁） | Designs §12.3 | `snake_tails.styx_tail` 未设计；「死里逃生」事件定义亦未设计（双重缺口）。 |
| 鳞片「见过即解锁」发现门控 | Designs §12.3 | v1 鳞片池仅 9 片，门控收益过低且伤首局体验；存档 `discovered_scales` 字段已预留，v2 随内容池扩大启用。 |

注：草稿 `unlock_conditions.enemies_50`（击杀 50 解锁 salamander）一并移除——salamander 已改为默认解锁（起始内容）。

## 来自 US3 / Designs §9.4（事件拾取）

| 条目 | 设计出处 | 移出理由 |
|------|----------|----------|
| serpent_scale 蛇鳞碎片（携带后下次鳞片奖励 +1 选项） | spec 003 草稿 / `event_pickups.pickups.serpent_scale` | v1 拾取范围 = broken_eye ONLY（US3 为 SHOULD、砍单阶梯首位，先以单一拾取验证管线）。 |
| broken_eye 激活路线 A（带入商人间 → 特殊交易换「完整眼球鳞片」） | Designs §9.4 | 依赖商人间特殊交易机制与完整眼球鳞片内容，v1 均不存在承接；v1 保留 activate API/active 字段作为模型缝。 |
| broken_eye 激活路线 B（带碎片击杀另一只镜像蛇 → 合并「双眼鳞片」） | Designs §9.4 | 依赖镜像蛇精英与双眼鳞片内容，v1 不存在承接。 |
| 毒囊残渣及其余掉落物（净化泉解谜 / 引燃毒爆路线） | Designs §9.4 | v1 仅 broken_eye；净化泉建筑物属事件建筑物系（v2）。 |

## 来自 Designs §9 / §12.5（L5 v2 愿景，登记防蔓延）

- 事件建筑物（§9.3）、痕迹（§9.5）、事件感知 PCG 权重调整（§9.6）——spec 003 Assumptions 已声明 deferred to v2
- 无尽模式元成长变体（§12.5：蜕皮时刻 / 无尽石碑 / 无尽专属蛇头）

以上属 Designs 长期愿景，不进入 spec 003 任务；范围扩张需 spec 修订 + 用户确认。
