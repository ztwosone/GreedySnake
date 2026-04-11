extends "res://Test/virtual_player/brains/player_brain.gd"
## 脚本化回放大脑
## 按预定义的 tick→方向 序列确定性回放


var _commands: Array[Dictionary] = []
var _index: int = 0


func setup(commands: Array[Dictionary]) -> void:
	_commands = commands
	_index = 0


func decide(snapshot: Dictionary) -> Dictionary:
	if _index >= _commands.size():
		return {"direction": Vector2i.ZERO}

	var current_tick: int = snapshot.get("current_tick", -1)
	var cmd: Dictionary = _commands[_index]
	var cmd_tick: int = cmd.get("tick", -1)

	if current_tick >= cmd_tick:
		_index += 1
		return {"direction": cmd.get("direction", Vector2i.ZERO)}

	return {"direction": Vector2i.ZERO}
