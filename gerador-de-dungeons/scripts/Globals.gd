extends Node

const GRID_SIZE: float = 2.0

func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * GRID_SIZE, 0.0, float(cell.y) * GRID_SIZE)

func world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / GRID_SIZE), roundi(pos.z / GRID_SIZE))
