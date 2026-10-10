extends DungeonScene

@export_group("Cena (manual)")
@export var place_player_on_start: bool = true
@export_group("Grids")
@export var start_cell: Vector2i = Vector2i.ZERO
@export var end_cell: Vector2i = Vector2i.ZERO
@export_group("Grafo manual")
@export var manual_rooms: Array[Vector2i] = []
@export var manual_corridors: Array[Vector2i] = []

func _handle_key(keycode: Key) -> void:
	if keycode == KEY_0:
		print(export_metrics())

func _scene_ready() -> void:
	_collect_cells(self)
	_update_cell_faces()
	if place_player_on_start:
		place_player(start_cell)
	set_endpoints(start_cell, end_cell)
	update_minimap_grid(_build_grid(), start_cell, end_cell)

func export_metrics() -> Dictionary:
	if manual_rooms.is_empty():
		push_warning("ManualMap: fill 'manual_rooms'/'manual_corridors' to export metrics.")
		return {}

	var metrics: Dictionary = GraphMetrics.layout_metrics(
		manual_corridors,
		manual_rooms.size(),
		manual_rooms.find(start_cell),
		manual_rooms.find(end_cell)
	)
	metrics["rooms"] = manual_rooms.size()
	metrics["corridors"] = manual_corridors.size()
	return metrics

func _update_cell_faces() -> void:
	for cell in cell_by_pos.values():
		cell.update_faces(cell_by_pos)

func _build_grid() -> Dictionary:
	var grid := {}
	for cell_position in cell_by_pos.keys():
		grid[cell_position] = GridRasterizer.TILE_FLOOR
	return grid

func _collect_cells(node: Node) -> void:
	for child in node.get_children():
		if child is Cell:
			var grid_position := Globals.world_to_grid((child as Node3D).position)
			if cell_by_pos.has(grid_position):
				push_warning("ManualMap: two cells at the same grid position %s." % grid_position)
			cell_by_pos[grid_position] = child
		else:
			_collect_cells(child)
