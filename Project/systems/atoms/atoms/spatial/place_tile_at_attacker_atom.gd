class_name PlaceTileAtAttackerAtom
extends AtomBase
## 在攻击者当前位置放置状态格
## 参数: type (String), layer (int, default 1)
## 从 ctx.params["enemy"] 获取攻击者


func execute(ctx: AtomContext) -> void:
	var type: String = get_param("type", "")
	var layer: int = get_param("layer", 1)
	if type.is_empty():
		return
	var enemy = ctx.params.get("enemy", null)
	if not enemy or not is_instance_valid(enemy):
		return
	if enemy.get("grid_position") == null:
		return
	if ctx.tile_mgr:
		ctx.tile_mgr.place_tile(enemy.grid_position, type, layer)
