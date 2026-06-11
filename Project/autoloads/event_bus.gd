extends Node

# === Tick Lifecycle ===
signal tick_pre_process(tick_index: int)           # Tick 开始前
signal tick_input_collected(tick_index: int)        # 输入收集完毕，触发蛇移动
signal tick_post_process(tick_index: int)           # Tick 结算完毕

# === Snake ===
signal snake_moved(data: Dictionary)               # 蛇完成一步移动 { body, direction, head_pos, old_tail_pos }
signal snake_turned(data: Dictionary)               # 蛇改变方向 { old_dir, new_dir }
signal snake_hit_boundary(data: Dictionary)         # 蛇头撞墙 { position, direction }
signal snake_hit_self(data: Dictionary)             # 蛇头撞自身 { position, segment_index }
signal snake_hit_enemy(data: Dictionary)            # 蛇头撞敌人 { enemy, position }
signal snake_food_eaten(data: Dictionary)           # 蛇吃到食物 { food, position, food_type }
signal snake_died(data: Dictionary)                 # 蛇死亡 { cause }

# === Length ===
signal snake_length_increased(data: Dictionary)    # 长度增加 { amount, source, new_length }
signal snake_length_decreased(data: Dictionary)    # 长度减少 { amount, source, new_length }
signal length_decrease_requested(data: Dictionary) # 请求减少长度 { amount, source }
signal length_grow_requested(data: Dictionary)     # 请求增长 { amount }

# === Enemy ===
signal enemy_killed(data: Dictionary)              # 敌人被击杀 { enemy_def, position, method }
signal snake_body_attacked(data: Dictionary)       # 蛇身被攻击 { position, segment, enemy, status_transferred }
signal enemy_spawned(data: Dictionary)             # 敌人生成 { enemy_def, position }
signal enemy_action_decided(data: Dictionary)      # 敌人AI决策 { enemy, action, direction }

# === GridWorld ===
signal entity_moved(data: Dictionary)              # 实体移动 { entity, from, to }
signal entity_placed(data: Dictionary)             # 实体放置 { entity, position }
signal entity_removed(data: Dictionary)            # 实体移除 { entity, position }

# === Status Effects ===
signal status_applied(data: Dictionary)            # 状态施加 { target, type, layer, source }
signal status_removed(data: Dictionary)            # 状态移除 { target, type, source }
signal status_layer_changed(data: Dictionary)      # 叠层变化 { target, type, old_layer, new_layer }
signal status_expired(data: Dictionary)            # 状态过期 { target, type }

# === Ice Effect ===
signal ice_freeze_started(data: Dictionary)      # 冰冻冻结开始 {}
signal ice_freeze_ended(data: Dictionary)        # 冰冻冻结结束 {}

# === Status Tiles ===
signal status_tile_placed(data: Dictionary)        # 状态格放置 { position, type, layer }
signal status_tile_removed(data: Dictionary)       # 状态格移除 { position, type }
signal entity_entered_status_tile(data: Dictionary) # 实体踩入状态格 { entity, tile, position, type }

# === Reactions ===
signal reaction_triggered(data: Dictionary)      # 反应触发 { reaction_id, position, type_a, type_b, layer_a, layer_b, damage }

# === Game Flow ===
signal game_started                                # 游戏开始
signal game_over(data: Dictionary)                 # 游戏结束 { cause, final_length }
signal game_restart_requested                      # 请求重新开始

# === L3 Run Loop ===
signal run_started(data: Dictionary)               # L3 run 开始 { run_id, floor_index }
signal floor_generated(data: Dictionary)           # 楼层生成 { floor_id, rooms, start_room_id, endpoint_room_id }
signal room_entered(data: Dictionary)              # 进入房间 { room_id, room_type, intent_label }
signal room_advance_requested(data: Dictionary)    # 请求进入下一房间 { room_id }
signal room_objective_progressed(data: Dictionary) # 房间目标进度 { room_id, objective_type, current, required }
signal room_completed(data: Dictionary)            # 房间完成 { room_id, room_type }
signal reward_presented(data: Dictionary)          # 奖励展示 { offer_id, options }
signal reward_chosen(data: Dictionary)             # 奖励选择 { offer_id, option_id, reward_type, target_id }
signal floor_completed(data: Dictionary)           # 楼层完成 { floor_id, floor_index }
signal run_victory(data: Dictionary)               # Run 胜利 { run_id, floor_index }

# === No-Body Countdown ===
signal no_body_countdown_tick(data: Dictionary)    # 每tick广播 { remaining_seconds, total_seconds, ratio }
signal no_body_countdown_started(data: Dictionary) # 倒计时开始 { total_seconds }
signal no_body_countdown_cancelled                 # 倒计时取消（恢复了身体段）

# === StatusCarrier ===
signal status_added_to_carrier(data: Dictionary)   # 载体获得状态 { carrier, type, carrier_type }
signal status_removed_from_carrier(data: Dictionary) # 载体移除状态 { carrier, type, carrier_type }

# === EffectWindow ===
signal window_opened(data: Dictionary)             # 窗口开启 { window_id, duration_ticks, owner }
signal window_expired(data: Dictionary)            # 窗口到期 { window_id, owner }
signal window_cancelled(data: Dictionary)          # 窗口取消 { window_id, owner, reason }

# === SnakeParts ===
signal snake_head_equipped(data: Dictionary)       # 蛇头装备 { head_id, level }
signal snake_head_unequipped(data: Dictionary)     # 蛇头卸载 { head_id }
signal snake_tail_equipped(data: Dictionary)       # 蛇尾装备 { tail_id, level }
signal snake_tail_unequipped(data: Dictionary)     # 蛇尾卸载 { tail_id }
signal snake_scale_equipped(data: Dictionary)      # 鳞片装备 { scale_id, level, position }
signal snake_scale_unequipped(data: Dictionary)    # 鳞片卸载 { scale_id, position }
signal resonance_activated(data: Dictionary)       # 共鸣激活 { resonance_id, display_name, is_new_discovery }
signal resonance_deactivated(data: Dictionary)     # 共鸣停用 { resonance_id }

# === Segment Loss Deferred (T30 Lag Tail) ===
signal segment_loss_deferred(data: Dictionary)     # 段丢失被延迟 { amount, source }

# === L4 Growth Cycle ===
signal currency_changed(data: Dictionary)           # 货币变化 { currency, amount, total, source, position? Vector2i 入账事发格（T104b 飞行粒子起点，可缺省） }
signal scale_reward_presented(data: Dictionary)     # 鳞片奖励展示 { room_id, options, offer_id }
signal scale_reward_chosen(data: Dictionary)        # 鳞片奖励选择 { option_id, scale_id, position, level, skipped }（skipped=true 为空池自动决议，FR-014）
signal scale_option_discarded(data: Dictionary)     # 鳞片选项放弃 { offer_id, discarded_ids, shedskin_gained }（FR-018 拆除合成 room_completed 后的显式决议信号）
signal shop_entered(data: Dictionary)               # 进入商店 { room_id, items }
signal shop_purchase(data: Dictionary)              # 商店购买 { item_id, category, cost, currency_remaining }
signal slot_unlocked(data: Dictionary)              # 槽位解锁 { position, total_slots, source }
signal floor_reward_presented(data: Dictionary)     # Boss 结算展示 { reward_id, floor_index, source_room_id, step: "slot_unlock"|"choice", slot_options, options }（两段各发一次，FR-007）
signal floor_reward_chosen(data: Dictionary)        # 楼层奖励决议 { floor_index, category, option_id, skipped }（skipped=true 空选项自动决议，FR-014；发射即解除门控 FR-015）
signal difficulty_adjusted(data: Dictionary)        # 难度调整 { reason, adjustment }
signal room_modifier_applied(data: Dictionary)      # 房间修饰符应用 { room_id, modifier_id }
signal floor_theme_set(data: Dictionary)            # 楼层主题设定 { theme, pressure, floor_index }

# === L5 Meta Growth ===
signal content_unlocked(data: Dictionary)           # 内容解锁 { content_type, content_id, display_name }
signal legacy_stone_created(data: Dictionary)       # 传承石创建 { description, highlight_type, bias_config }
signal legacy_stone_selected(data: Dictionary)      # 传承石选择 { stone_index, stone }（完整 stone dict，spec 003 M3 修订）；发射方 = LegacyStoneSystem.select_legacy_stone（StoneSelectScreen 驱动），选中即消耗（移除+落盘）
signal pickup_dropped(data: Dictionary)             # 拾取物掉落（网格实体已落格）{ pickup_id, instance_id, position（占用偏移后的实际落点）, display_name }；发射方 = PickupSystem（精英击杀掉落，spec 003 M4）
signal pickup_collected(data: Dictionary)           # 拾取物被蛇头拾起（携带效果即时生效）{ pickup_id, instance_id, display_name, carry_effect, rooms_remaining }；监听方 = DangerIndicator（enemy_intent 携带效果）、PickupDisplay
signal pickup_activated(data: Dictionary)           # 拾取物激活（模型缝保留，激活路线 A/B 入 backlog）{ pickup_id, instance_id }
signal pickup_expired(data: Dictionary)             # 拾取物过期/清除 { pickup_id, instance_id, reason: "rooms_exhausted"|"floor_transition" }；监听方 = DangerIndicator、PickupDisplay
signal run_ended(data: Dictionary)                  # Run 结束（spec 003 FR-016 冻结契约）{ outcome: "victory"|"death", run_id, floor_index, stats: {total_turns, total_kills, reaction_kills, near_death_count, survival_low_length_ticks, floors_completed, max_reaction_chain, damage_taken, max_length, duration_ticks} }；唯一发射点 = RunStatsTracker.finalize_run（once-guard），调用方 = RunProgressionSystem victory/death 双出口
