class_name MinimapView
extends Control

const COLOR_BG := Color(0.06, 0.07, 0.10, 0.88)
const COLOR_FLOOR := Color(0.62, 0.66, 0.78, 1.0)
const COLOR_START := Color(0.30, 0.85, 0.50, 1.0)
const COLOR_END := Color(0.92, 0.35, 0.35, 1.0)
const COLOR_PLAYER := Color(1.0, 0.85, 0.20, 1.0)

var _cells: Array[Vector2i] = []
var _start := Vector2i.ZERO
var _end := Vector2i.ZERO
var _min := Vector2i.ZERO
var _max := Vector2i.ZERO
var _has_data := false
var _player: Node3D
var _grid_size: float = 2.0
var _player_cell := Vector2i.ZERO
var _has_player_cell := false

func set_map(
	grid: Dictionary,
	floor_value: int,
	start_pos: Vector2i,
	end_pos: Vector2i
) -> void:
	_cells.clear()
	for cell_position in grid.keys():
		if grid[cell_position] == floor_value:
			_cells.append(cell_position)
	_start = start_pos
	_end = end_pos
	_has_data = not _cells.is_empty()
	_recompute_bounds()
	queue_redraw()

func set_player(player: Node3D, grid_size: float) -> void:
	_player = player
	_grid_size = grid_size

func _recompute_bounds() -> void:
	if _cells.is_empty():
		return
	_min = _cells[0]
	_max = _cells[0]
	for cell in _cells:
		_min.x = min(_min.x, cell.x)
		_min.y = min(_min.y, cell.y)
		_max.x = max(_max.x, cell.x)
		_max.y = max(_max.y, cell.y)

func _process(_delta: float) -> void:
	if not visible or _player == null or not _has_data:
		return

	var player_cell := Vector2i(
		int(round(_player.global_position.x / _grid_size)),
		int(round(_player.global_position.z / _grid_size))
	)
	if not _has_player_cell or player_cell != _player_cell:
		_player_cell = player_cell
		_has_player_cell = true
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	if not _has_data:
		return

	var padding := minf(size.x, size.y) * 0.04
	var columns := _max.x - _min.x + 1	
	var rows := _max.y - _min.y + 1
	var available := size - Vector2(padding, padding) * 2.0
	var cell_px: float = max(1.0, min(available.x / float(columns), available.y / float(rows)))
	var grid_px := Vector2(float(columns), float(rows)) * cell_px
	var origin := (size - grid_px) * 0.5

	for cell in _cells:
		_fill_cell(cell, cell_px, origin, COLOR_FLOOR)
	_fill_cell(_start, cell_px, origin, COLOR_START)
	_fill_cell(_end, cell_px, origin, COLOR_END)
	if _has_player_cell:
		_fill_cell(_player_cell, cell_px, origin, COLOR_PLAYER)

func _fill_cell(cell: Vector2i, cell_px: float, origin: Vector2, color: Color) -> void:
	var draw_position := origin + Vector2(float(cell.x - _min.x), float(cell.y - _min.y)) * cell_px
	draw_rect(
		Rect2(draw_position + Vector2(0.5, 0.5), Vector2(cell_px - 1.0, cell_px - 1.0)),
		color,
		true
	)
