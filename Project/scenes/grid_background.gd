extends Node2D


func _draw() -> void:
	var grid_w: int = Constants.GRID_WIDTH
	var grid_h: int = Constants.GRID_HEIGHT
	var cell: int = Constants.CELL_SIZE
	var total_w: float = grid_w * cell
	var total_h: float = grid_h * cell

	# Dark background fill
	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.1, 0.1, 0.12))

	# Grid lines
	var line_color := Color(0.15, 0.15, 0.18)
	for x in range(grid_w + 1):
		draw_line(Vector2(x * cell, 0), Vector2(x * cell, total_h), line_color, 1.0)
	for y in range(grid_h + 1):
		draw_line(Vector2(0, y * cell), Vector2(total_w, y * cell), line_color, 1.0)
