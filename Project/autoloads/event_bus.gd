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
signal enemy_spawned(data: Dictionary)             # 敌人生成 { enemy_def, position }

# === GridWorld ===
signal entity_moved(data: Dictionary)              # 实体移动 { entity, from, to }
signal entity_placed(data: Dictionary)             # 实体放置 { entity, position }
signal entity_removed(data: Dictionary)            # 实体移除 { entity, position }

# === Game Flow ===
signal game_started                                # 游戏开始
signal game_over(data: Dictionary)                 # 游戏结束 { cause, final_length }
signal game_restart_requested                      # 请求重新开始
