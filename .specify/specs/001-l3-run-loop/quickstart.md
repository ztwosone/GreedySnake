# Quickstart: L3 Run Loop

## Start a deterministic L3 smoke run

1. Run the Godot project from `Project/scenes/main.tscn`.
2. Start a new game.
3. Enter the first generated room.
4. Clear the combat objective.
5. Pick one reward from no more than three placeholder options.
6. Advance through the floor path.
7. Complete the endpoint objective.
8. Restart and verify no old room/reward/run state remains.

## Verification commands

```powershell
$env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File "F:/GreedySnake/Tools/run_tests_strict.ps1"
```

## Expected v1 evidence

- Room intent is visible through placeholder label/color.
- Room completion emits an event and unlocks the next step.
- Reward selection updates existing Build state.
- Victory and death both return to existing game over/restart flow.
