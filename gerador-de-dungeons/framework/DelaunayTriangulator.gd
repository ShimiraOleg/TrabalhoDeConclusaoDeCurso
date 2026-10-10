class_name DelaunayTriangulator
extends RefCounted

static func triangulate_edges(points: Array) -> Array:
	var edge_set: Dictionary = {}
	if points.size() < 3:
		for index in range(points.size() - 1):
			edge_set[GraphMetrics.edge_key(index, index + 1)] = true
		return edge_set.keys()

	for triangle in triangulate(points):
		edge_set[GraphMetrics.edge_key(triangle[0], triangle[1])] = true
		edge_set[GraphMetrics.edge_key(triangle[1], triangle[2])] = true
		edge_set[GraphMetrics.edge_key(triangle[2], triangle[0])] = true
	return edge_set.keys()

static func triangulate(points: Array) -> Array:
	var real_point_count: int = points.size()
	if real_point_count < 3:
		return []

	var work: Array = points.duplicate()
	var bounds: Dictionary = _point_bounds(work)
	var max_dimension: float = maxf(
		bounds["max_x"] - bounds["min_x"],
		bounds["max_y"] - bounds["min_y"]
	)
	var midpoint := Vector2(
		(bounds["min_x"] + bounds["max_x"]) * 0.5,
		(bounds["min_y"] + bounds["max_y"]) * 0.5
	)
	var margin: float = maxf(max_dimension * 20.0, 1000.0)

	work.append(midpoint + Vector2(-margin, -margin))
	work.append(midpoint + Vector2(margin, -margin))
	work.append(midpoint + Vector2(0.0, margin))

	var triangles: Array = [[real_point_count, real_point_count + 1, real_point_count + 2]]
	for point_index in range(real_point_count):
		_insert_point(work, triangles, point_index)

	var filtered: Array = []
	for triangle in triangles:
		if (
			triangle[0] < real_point_count
			and triangle[1] < real_point_count
			and triangle[2] < real_point_count
		):
			filtered.append(triangle)
	return filtered

static func _point_bounds(points: Array) -> Dictionary:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return {"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

static func _insert_point(work: Array, triangles: Array, point_index: int) -> void:
	var point: Vector2 = work[point_index]
	var bad_triangles: Array = []
	for triangle_index in range(triangles.size()):
		var triangle: Array = triangles[triangle_index]
		if _in_circumcircle(
			point,
			work[triangle[0]],
			work[triangle[1]],
			work[triangle[2]]
		):
			bad_triangles.append(triangle_index)

	var edge_count: Dictionary = {}
	for triangle_index in bad_triangles:
		var triangle: Array = triangles[triangle_index]
		_count_edge(edge_count, triangle[0], triangle[1])
		_count_edge(edge_count, triangle[1], triangle[2])
		_count_edge(edge_count, triangle[2], triangle[0])

	bad_triangles.sort()
	bad_triangles.reverse()
	for triangle_index in bad_triangles:
		triangles.remove_at(triangle_index)

	for edge in edge_count.keys():
		if edge_count[edge] == 1:
			var pair: Vector2i = edge as Vector2i
			triangles.append([pair.x, pair.y, point_index])

static func _in_circumcircle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ax: float = a.x - point.x
	var ay: float = a.y - point.y
	var bx: float = b.x - point.x
	var by: float = b.y - point.y
	var cx: float = c.x - point.x
	var cy: float = c.y - point.y

	var a_squared: float = ax * ax + ay * ay
	var b_squared: float = bx * bx + by * by
	var c_squared: float = cx * cx + cy * cy
	var determinant: float = (
		ax * (by * c_squared - b_squared * cy)
		- ay * (bx * c_squared - b_squared * cx)
		+ a_squared * (bx * cy - by * cx)
	)
	var orientation: float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
	return determinant > 0.0 if orientation > 0.0 else determinant < 0.0

static func _count_edge(edge_count: Dictionary, a: int, b: int) -> void:
	var key := GraphMetrics.edge_key(a, b)
	edge_count[key] = edge_count.get(key, 0) + 1
