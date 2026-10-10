class_name GraphMetrics
extends RefCounted

static func edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(min(a, b), max(a, b))

static func adjacency_from_edges(edges: Array, node_count: int = -1) -> Dictionary:
	var adjacency: Dictionary = {}
	for index in range(max(node_count, 0)):
		adjacency[index] = []

	for edge in edges:
		var a: int = edge.x
		var b: int = edge.y
		if a == b:
			continue
		if not adjacency.has(a):
			adjacency[a] = []
		if not adjacency.has(b):
			adjacency[b] = []
		if not adjacency[a].has(b):
			adjacency[a].append(b)
		if not adjacency[b].has(a):
			adjacency[b].append(a)
	return adjacency

static func degree(adjacency: Dictionary, node: int) -> int:
	return (adjacency.get(node, []) as Array).size()

static func average_degree(adjacency: Dictionary, node_count: int = -1) -> float:
	var denominator: int = node_count if node_count >= 0 else adjacency.size()
	if denominator <= 0:
		return 0.0

	var total: int = 0
	for node in adjacency.keys():
		total += (adjacency[node] as Array).size()
	return float(total) / float(denominator)

static func local_clustering(adjacency: Dictionary, node: int) -> float:
	var neighbors: Array = adjacency.get(node, [])
	var neighbor_count: int = neighbors.size()
	if neighbor_count < 2:
		return 0.0

	var links: int = 0
	for first_index in range(neighbor_count):
		var neighbors_of_first: Array = adjacency.get(neighbors[first_index], [])
		for second_index in range(first_index + 1, neighbor_count):
			if neighbors_of_first.has(neighbors[second_index]):
				links += 1
	return float(2 * links) / float(neighbor_count * (neighbor_count - 1))

static func average_clustering(adjacency: Dictionary, node_count: int = -1) -> float:
	var denominator: int = node_count if node_count >= 0 else adjacency.size()
	if denominator <= 0:
		return 0.0

	var neighbor_sets: Dictionary = _neighbor_sets(adjacency)
	var total: float = 0.0
	for node in adjacency.keys():
		total += _clustering_from_sets(neighbor_sets, node)
	return total / float(denominator)

static func bfs_distances(adjacency: Dictionary, source: int) -> Dictionary:
	var distances: Dictionary = {source: 0}
	var queue: Array = [source]
	while not queue.is_empty():
		var node: int = queue.pop_front()
		var distance: int = distances[node]
		for neighbor in adjacency.get(node, []):
			if not distances.has(neighbor):
				distances[neighbor] = distance + 1
				queue.append(neighbor)
	return distances

static func path_exists(adjacency: Dictionary, start: int, goal: int) -> bool:
	if start < 0 or goal < 0:
		return false
	if start == goal:
		return true
	return bfs_distances(adjacency, start).has(goal)

static func farthest_node(adjacency: Dictionary, source: int) -> int:
	var distances: Dictionary = bfs_distances(adjacency, source)
	var farthest: int = -1
	var farthest_distance: int = -1
	for node in distances.keys():
		if node == source:
			continue
		if distances[node] > farthest_distance:
			farthest_distance = distances[node]
			farthest = node
	return farthest

static func components(adjacency: Dictionary, node_count: int = -1) -> Array:
	var all_nodes: Array = []
	if node_count >= 0:
		for index in range(node_count):
			all_nodes.append(index)
	else:
		all_nodes = adjacency.keys()

	var seen: Dictionary = {}
	var result: Array = []
	for node in all_nodes:
		if seen.has(node):
			continue
		var reached: Dictionary = bfs_distances(adjacency, node)
		var component: Array = []
		for reached_node in reached.keys():
			seen[reached_node] = true
			component.append(reached_node)
		component.sort()
		result.append(component)
	return result

static func is_graph_connected(adjacency: Dictionary, node_count: int = -1) -> bool:
	return components(adjacency, node_count).size() <= 1

static func edge_weight(distances: Dictionary, a: int, b: int) -> float:
	var row: Dictionary = distances.get(a, {})
	return row.get(b, INF)

static func total_length(edges: Array, distances: Dictionary) -> float:
	var total: float = 0.0
	for edge in edges:
		var weight: float = edge_weight(distances, edge.x, edge.y)
		if weight < INF:
			total += weight
	return total

static func mst_edges(distances: Dictionary, adjacency: Dictionary) -> Array:
	var visited: Dictionary = {}
	var result: Array = []
	for root in adjacency.keys():
		if visited.has(root):
			continue
		_prim_from(distances, adjacency, root, visited, result)
	return result

static func mst_length(distances: Dictionary, adjacency: Dictionary) -> float:
	return total_length(mst_edges(distances, adjacency), distances)

static func _prim_from(
	distances: Dictionary,
	adjacency: Dictionary,
	root: int,
	visited: Dictionary,
	result: Array
) -> void:
	visited[root] = true
	var frontier: Array = []
	for neighbor in adjacency.get(root, []):
		frontier.append(Vector2i(root, neighbor))

	while not frontier.is_empty():
		var pending: Array = []
		for edge in frontier:
			if not visited.has(edge.y):
				pending.append(edge)
		frontier = pending
		if frontier.is_empty():
			return

		var best_index: int = 0
		var best_weight: float = edge_weight(distances, frontier[0].x, frontier[0].y)
		for index in range(1, frontier.size()):
			var weight: float = edge_weight(distances, frontier[index].x, frontier[index].y)
			if weight < best_weight:
				best_weight = weight
				best_index = index

		var chosen: Vector2i = frontier[best_index]
		frontier.remove_at(best_index)
		visited[chosen.y] = true
		result.append(edge_key(chosen.x, chosen.y))
		for neighbor in adjacency.get(chosen.y, []):
			if not visited.has(neighbor):
				frontier.append(Vector2i(chosen.y, neighbor))

static func layout_metrics(
	edges: Array,
	node_count: int,
	start: int = -1,
	goal: int = -1
) -> Dictionary:
	var adjacency: Dictionary = adjacency_from_edges(edges, node_count)
	var connected: bool = false
	if node_count > 0:
		connected = path_exists(adjacency, start, goal)
	return {
		"average_degree": average_degree(adjacency, node_count),
		"average_clustering": average_clustering(adjacency, node_count),
		"start_end_connected": connected,
		"edge_count": edges.size(),
		"node_count": node_count,
		"component_count": components(adjacency, node_count).size() if node_count > 0 else 0,
	}

static func _neighbor_sets(adjacency: Dictionary) -> Dictionary:
	var neighbor_sets: Dictionary = {}
	for node in adjacency.keys():
		var neighbors: Dictionary = {}
		for neighbor in adjacency[node]:
			neighbors[neighbor] = true
		neighbor_sets[node] = neighbors
	return neighbor_sets

static func _clustering_from_sets(neighbor_sets: Dictionary, node: int) -> float:
	if not neighbor_sets.has(node):
		return 0.0

	var neighbors: Array = (neighbor_sets[node] as Dictionary).keys()
	var neighbor_count: int = neighbors.size()
	if neighbor_count < 2:
		return 0.0

	var links: int = 0
	for first_index in range(neighbor_count):
		var first_set: Dictionary = neighbor_sets.get(neighbors[first_index], {})
		for second_index in range(first_index + 1, neighbor_count):
			if first_set.has(neighbors[second_index]):
				links += 1
	return float(2 * links) / float(neighbor_count * (neighbor_count - 1))
