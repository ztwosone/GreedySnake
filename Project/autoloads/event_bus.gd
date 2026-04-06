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

# === Segment Loss Deferred (T30 Lag Tail) ===
signal segment_loss_deferred(data: Dictionary)     # 段丢失被延迟 { amount, source }
