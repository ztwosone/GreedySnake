# Data Model: L3 Run Loop

## RunState

- `run_id: String`
- `floor_index: int`
- `current_room_id: String`
- `completed_room_ids: Array[String]`
- `available_room_ids: Array[String]`
- `pending_reward: Dictionary`
- `outcome: String` (`running`, `victory`, `death`)

## FloorMap

- `floor_id: String`
- `seed: int`
- `rooms: Array[Dictionary]`
- `start_room_id: String`
- `endpoint_room_id: String`

## RoomNode

- `room_id: String`
- `room_type: String` (`combat`, `reward`, `rest`, `endpoint`)
- `intent_label: String`
- `objective: Dictionary`
- `exit_room_ids: Array[String]`
- `placeholder_color: String`
- `enabled: bool`
- `auto_complete_on_enter: bool`

## RoomObjective

- `objective_type: String` (`clear_enemies`, `claim_reward`, `reach_endpoint`)
- `required_count: int`
- `current_count: int`
- `complete: bool`

## RewardOffer

- `offer_id: String`
- `source_room_id: String`
- `source_room_type: String`
- `options: Array[Dictionary]`
- `chosen_option_id: String`
- `complete: bool`

## RewardOption

- `option_id: String`
- `display_name: String`
- `reward_type: String` (`head`, `tail`, `scale`, `upgrade`)
- `target_id: String`
- `target_slot: String`
- `level_delta: int`
- `placeholder_color: String`
