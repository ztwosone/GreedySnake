# Data Model: L4 Growth Cycle

## ShedskinCurrency

- `floor_index: int`
- `amount: int`
- `total_earned: int`
- `total_spent: int`
- `sources: Dictionary` — {source_name: count}

Lifecycle: Created at floor start with amount=0. Incremented on kills, discards, exploration. Decremented on shop purchases. Reset (new instance) on floor transition.

## ScaleRewardOffer

- `offer_id: String`
- `source_room_id: String`
- `pool_id: String`
- `options: Array[ScaleOption]` — exactly 3
- `chosen_index: int` — -1 if not chosen
- `discarded_shedskin: int` — 4 total if discarded 2 non-chosen

## ScaleOption

- `option_id: String`
- `scale_id: String` — e.g. "flame_scale"
- `display_name: String`
- `slot_position: String` — "front", "middle", "back"
- `level: int` — 1-3
- `tags: Array[String]` — e.g. ["fire"]
- `placeholder_color: String`
- `description: String`

## ShopInventory

- `shop_id: String`
- `source_room_id: String`
- `items: Array[ShopItem]` — max 5
- `active: bool`

## ShopItem

- `item_id: String`
- `category: String` — "scale", "slot", "head_upgrade", "tail_upgrade"
- `target_id: String` — scale_id, "slot_front", "slot_middle", "slot_back", head_id, tail_id
- `price: int` — in shedskin
- `level: int` — for scale/upgrade items
- `purchased: bool`
- `affordable: bool` — computed
- `display_name: String`
- `placeholder_color: String`

## SlotExpansion

- `slots_front: int` — initial 1, max 2
- `slots_middle: int` — initial 1, max 3
- `slots_back: int` — initial 1, max 2
- `unlock_history: Array[Dictionary]` — {position, source, floor_index}
- `total_slots: int` — computed

## FloorReward

- `reward_id: String`
- `floor_index: int`
- `source_room_id: String`
- `options: Array[FloorRewardOption]` — exactly 3, one per category
- `chosen_index: int`
- `categories_used: Array[String]` — ["expansion", "reinforcement", "correction"]

## FloorRewardOption

- `option_id: String`
- `category: String` — "expansion", "reinforcement", "correction"
- `reward_type: String` — what it grants (scale, upgrade, reorder, swap)
- `target_id: String`
- `display_name: String`
- `description: String`
- `placeholder_color: String`

## FloorTheme

- `theme_id: String`
- `environment: String` — "cave", "marsh", "ruins", "machine", "void"
- `pressure: String` — "hunting", "wasteland", "maze", "speedrun", "siege"
- `enemy_pools: Dictionary` — weighted enemy type selections
- `terrain_templates: Array[String]`
- `modifier_chances: Dictionary` — {modifier_id: probability}
- `placeholder_color: String`
- `display_name: String`

## RoomModifier

- `modifier_id: String` — e.g. "darkness", "speed_strips", "shield_enemies"
- `display_name: String`
- `description: String`
- `enabled: bool`
- `apply_chains: Array` — atom chains on room enter
- `remove_chains: Array` — atom chains on room exit
- `visual_config: Dictionary` — placeholder visual parameters
- `exclusive_with: Array[String]` — incompatible modifier IDs

## DifficultyState

- `current_difficulty: float` — 0.0 to 1.0
- `floor_index: int`
- `enemy_count_modifier: int` — delta from baseline
- `enemy_armor_chance: float` — 0.0 to 1.0
- `food_density_modifier: int`
- `last_adjustment: String`
- `performance_metrics: Dictionary`
  - `avg_clear_speed: float` — ticks per room
  - `avg_damage_taken: float` — hits per room
  - `status_usage_rate: float` — status actions per room
  - `rooms_since_last_adjust: int`

## Config Extensions (game_config.json new sections)

```json
{
  "growth": {
    "shedskin": {
      "kill_normal": 1,
      "kill_elite": 3,
      "scale_discard": 2,
      "exploration_bonus_max": 2
    },
    "scale_reward": {
      "offer_count": 3,
      "pools": {
        "l1_basic": { "scale_ids": [...], "level_range": [1, 2] },
        "l2_advanced": { "scale_ids": [...], "level_range": [2, 3] }
      }
    },
    "slot_expansion": {
      "initial": { "front": 1, "middle": 1, "back": 1 },
      "max": { "front": 2, "middle": 3, "back": 2 }
    }
  },
  "shop": {
    "item_categories": {
      "scale": { "price_l1": 2, "price_l2": 3, "price_l3": 4 },
      "slot": { "price": 5 },
      "head_upgrade": { "price": 4 },
      "tail_upgrade": { "price": 4 }
    },
    "max_items_per_shop": 5
  },
  "floor_themes": {
    "cave_hunting": { "environment": "cave", "pressure": "hunting", ... },
    ...
  },
  "room_modifiers": {
    "darkness": { "enabled": true, "apply_chains": [...], ... },
    ...
  },
  "difficulty": {
    "baseline_enemy_count": 3,
    "overperform_threshold": 0.7,
    "underperform_threshold": 0.3,
    "adjustment_delta": 1,
    "min_enemy_count": 1,
    "max_enemy_count": 8
  }
}
```