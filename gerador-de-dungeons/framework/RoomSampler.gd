class_name RoomSampler
extends RefCounted

const ATTEMPTS_PER_ROOM: int = 60
const RELAX_FACTOR: float = 0.9
const MAX_RELAX_ROUNDS: int = 8

static func sample(
	room_count: int,
	bounds: Rect2,
	min_separation: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var points: Array = []
	var separation: float = min_separation
	var relax_rounds: int = 0

	while points.size() < room_count:
		var attempts: int = 0
		var max_attempts: int = (room_count - points.size()) * ATTEMPTS_PER_ROOM
		while points.size() < room_count and attempts < max_attempts:
			attempts += 1
			var point := Vector2(
				rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
				rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
			)
			if _far_enough(points, point, separation):
				points.append(point)

		if points.size() >= room_count:
			break
		if relax_rounds >= MAX_RELAX_ROUNDS:
			push_warning(
				"RoomSampler: placed %d/%d rooms even after relaxing separation to %.1f."
				% [points.size(), room_count, separation]
			)
			break
		relax_rounds += 1
		separation *= RELAX_FACTOR

	return {
		"points": points,
		"used_separation": separation,
		"relax_rounds": relax_rounds,
	}

static func _far_enough(points: Array, point: Vector2, separation: float) -> bool:
	for other_point in points:
		if (other_point as Vector2).distance_to(point) < separation:
			return false
	return true
