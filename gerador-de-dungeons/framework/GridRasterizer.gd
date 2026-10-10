class_name GridRasterizer
extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL: int = 2
const DIRECTIONS: Array = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var tile_scale: float = 60.0
var room_radius: int = 1

func rasterize(data: Dictionary) -> Dictionary:
	var grid: Dictionary = {}
	if not data.has("rooms") or not data.has("corridor_edges"):
		return {"grid": grid, "grid_rooms": []}

	var rooms: Array = data["rooms"]
	var grid_rooms: Array[Vector2i] = _room_grid_positions(rooms)
	for room_position in grid_rooms:
		_carve_room(grid, room_position, room_radius)

	for edge in data["corridor_edges"]:
		var start: Vector2i = grid_rooms[edge.x]
		var end: Vector2i = grid_rooms[edge.y]
		_carve_corridor_l_shape(grid, start, end)

	var result := {"grid": grid, "grid_rooms": grid_rooms}
	if not grid_rooms.is_empty():
		result["start_pos"] = grid_rooms[data.get("start_room", 0)]
		result["end_pos"] = grid_rooms[data.get("end_room", 0)]
	return result

func reconstruct_graph(grid: Dictionary, grid_rooms: Array) -> Array:
	var owner: Dictionary = _room_floor_owners(grid, grid_rooms)
	var edge_set: Dictionary = _room_boundary_edges(owner)

	for room_index in range(grid_rooms.size()):
		var queue: Array = []
		var seen: Dictionary = {}
		for position in owner.keys():
			if owner[position] != room_index:
				continue
			for direction in DIRECTIONS:
				var neighbor: Vector2i = position + direction
				if (
					grid.get(neighbor, TILE_EMPTY) == TILE_FLOOR
					and not owner.has(neighbor)
					and not seen.has(neighbor)
				):
					seen[neighbor] = true
					queue.append(neighbor)

		while not queue.is_empty():
			var position: Vector2i = queue.pop_front()
			for direction in DIRECTIONS:
				var neighbor: Vector2i = position + direction
				if grid.get(neighbor, TILE_EMPTY) != TILE_FLOOR:
					continue
				if owner.has(neighbor):
					if owner[neighbor] != room_index:
						edge_set[GraphMetrics.edge_key(room_index, owner[neighbor])] = true
					continue
				if not seen.has(neighbor):
					seen[neighbor] = true
					queue.append(neighbor)

	return edge_set.keys()

func _room_grid_positions(rooms: Array) -> Array[Vector2i]:
	var grid_rooms: Array[Vector2i] = []
	for center in rooms:
		grid_rooms.append(Vector2i(roundi(center.x / tile_scale), roundi(center.y / tile_scale)))
	return grid_rooms

func _room_floor_owners(grid: Dictionary, grid_rooms: Array) -> Dictionary:
	var owner: Dictionary = {}
	for room_index in range(grid_rooms.size()):
		var center: Vector2i = grid_rooms[room_index]
		for x in range(center.x - room_radius, center.x + room_radius + 1):
			for y in range(center.y - room_radius, center.y + room_radius + 1):
				var position := Vector2i(x, y)
				if grid.get(position, TILE_EMPTY) == TILE_FLOOR:
					owner[position] = room_index
	return owner

func _room_boundary_edges(owner: Dictionary) -> Dictionary:
	var edge_set: Dictionary = {}
	for position in owner.keys():
		for direction in DIRECTIONS:
			var neighbor: Vector2i = position + direction
			if owner.has(neighbor) and owner[position] != owner[neighbor]:
				edge_set[GraphMetrics.edge_key(owner[position], owner[neighbor])] = true
	return edge_set

func _carve_room(grid: Dictionary, center: Vector2i, radius: int) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			grid[Vector2i(x, y)] = TILE_FLOOR

func _carve_corridor_l_shape(grid: Dictionary, start: Vector2i, end: Vector2i) -> void:
	var current: Vector2i = start
	while current.x != end.x:
		grid[current] = TILE_FLOOR
		current.x += signi(end.x - current.x)
	while current.y != end.y:
		grid[current] = TILE_FLOOR
		current.y += signi(end.y - current.y)
	grid[end] = TILE_FLOOR
