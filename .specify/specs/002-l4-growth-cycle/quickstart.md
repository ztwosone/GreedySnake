# Quickstart: L4 Growth Cycle

## Run the L4 test suite

```powershell
# Standard
& "F:/GodotMCP/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe" --headless --path "F:/GreedySnake/Project" Test/test_runner.tscn

# Strict (with output scan)
$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File "F:/GreedySnake/Tools/run_tests_strict.ps1"
```

## Development: adding a new scale reward pool

1. Add pool definition to `game_config.json` under `growth.scale_reward.pools`
2. Add test in `test_l4_scale_rewards.gd` that calls `ScaleRewardSystem.present_offer("pool_id")`
3. Verify `offer.options.size() == 3`
4. Verify each option has `scale_id`, `slot_position`, `level`, `display_name`

## Development: adding a new room modifier

1. Add modifier definition to `game_config.json` under `room_modifiers`
2. Define `apply_chains` (atom chains on room enter) and `remove_chains` (on room exit)
3. Set `enabled: true`
4. Add test verifying modifier applies effect and is removable via `RoomModifierSystem`

## Development: adding a new shop item category

1. Add category to `game_config.json` under `shop.item_categories`
2. Implement `_can_purchase_<category>()` and `_execute_purchase_<category>()` in `ShopSystem`
3. Add test verifying purchase flow

## Expected L4 v1 evidence

- After combat room completion, scale reward panel appears with 3 options.
- Shedskin counter increases on kills (−1 per normal, +3 per elite).
- Shop room displays 3-5 items with prices; player can purchase if affordable.
- Boss defeat triggers floor reward with 3 categories.
- New floor has different theme and room layout from previous.
- Difficulty adjusts enemy count based on player performance.
- At least 2 room modifiers are visible and functional.