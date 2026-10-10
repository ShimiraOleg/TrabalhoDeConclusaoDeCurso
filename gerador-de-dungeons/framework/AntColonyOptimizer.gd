class_name AntColonyOptimizer
extends RefCounted

var max_iterations: int = 10
var ant_count: int = 5
var alpha: float = 1.0
var beta: float = 2.0
var rho: float = 0.1
var tau_0: float = 0.1
var tau_min: float = 0.01
var tau_max: float = 5.0
var loop_factor: float = 0.2
var objective: LayoutObjective = LayoutObjective.new()
var nodes: Array = []
var adjacency: Dictionary = {}
var dist_matrix: Dictionary = {}
var pheromone: Dictionary = {}
var best_fitness: float = -INF
var best_layout_edges: Array = []
var best_layout_length: float = INF
var best_layout_root: int = -1
var best_coverage: int = 0
var best_clustering: float = 0.0
var best_distance_score: float = 0.0
var best_clustering_score: float = 0.0

var _rng: RandomNumberGenerator

func configure(rng: RandomNumberGenerator) -> void:
	_rng = rng

func load_graph(graph: DungeonGraph) -> void:
	nodes = graph.rooms
	adjacency = graph.adjacency
	dist_matrix = graph.dist_matrix
	objective.configure_reference(graph.mst_length())

func run() -> void:
	if nodes.size() < 2:
		push_error("AntColonyOptimizer: needs at least 2 vertices.")
		return

	_initialize_pheromones()
	_reset_best_solution()

	for _iteration in range(max_iterations):
		for _ant in range(ant_count):
			_run_single_ant()
		_global_pheromone_update()

func get_corridor_edges() -> Array:
	return best_layout_edges.duplicate()

func _reset_best_solution() -> void:
	best_fitness = -INF
	best_layout_edges.clear()
	best_layout_length = INF
	best_layout_root = -1
	best_coverage = 0
	best_clustering = 0.0
	best_distance_score = 0.0
	best_clustering_score = 0.0

func _run_single_ant() -> void:
	var start_idx: int = _rng.randi() % nodes.size()
	var visited: Dictionary = {start_idx: true}
	var tree_edges: Array = []
	var in_layout: Dictionary = {}
	var layout_length: float = 0.0
	var frontier: Array = []

	for j in adjacency.get(start_idx, []):
		frontier.append(Vector2i(start_idx, j))

	while not frontier.is_empty():
		frontier = _unvisited_frontier(frontier, visited)
		if frontier.is_empty():
			break

		var chosen: Vector2i = _select_frontier_edge(frontier)
		var i: int = chosen.x
		var j: int = chosen.y

		_local_pheromone_update(i, j)
		var key := GraphMetrics.edge_key(i, j)
		tree_edges.append(key)
		in_layout[key] = true
		layout_length += dist_matrix[i][j]
		visited[j] = true
		for neighbor in adjacency.get(j, []):
			if not visited.has(neighbor):
				frontier.append(Vector2i(j, neighbor))

	var coverage: int = visited.size()
	var layout_edges: Array = tree_edges.duplicate()
	var candidates: Array = _collect_loop_candidates(in_layout)
	var budget: int = int(ceil(loop_factor * float(tree_edges.size())))

	if budget > 0 and not candidates.is_empty():
		for edge in _select_loop_edges(candidates, budget):
			layout_edges.append(edge)
			layout_length += dist_matrix[edge.x][edge.y]
			_local_pheromone_update(edge.x, edge.y)

	var report: Dictionary = _evaluate_layout(layout_edges, layout_length, coverage)
	_update_best_solution(layout_edges, layout_length, coverage, report, start_idx)

func _unvisited_frontier(frontier: Array, visited: Dictionary) -> Array:
	var clean_frontier: Array = []
	for edge in frontier:
		if not visited.has(edge.y):
			clean_frontier.append(edge)
	return clean_frontier

func _collect_loop_candidates(in_layout: Dictionary) -> Array:
	var candidates: Array = []
	for a in adjacency.keys():
		for b in adjacency[a]:
			if a < b:
				var key := GraphMetrics.edge_key(a, b)
				if not in_layout.has(key):
					candidates.append(key)
	return candidates

func _update_best_solution(
	layout_edges: Array,
	layout_length: float,
	coverage: int,
	report: Dictionary,
	root: int
) -> void:
	var fitness: float = report["fitness"]
	var better: bool = coverage > best_coverage
	if coverage == best_coverage:
		better = fitness > best_fitness
	if not better:
		return

	best_coverage = coverage
	best_fitness = fitness
	best_layout_edges = layout_edges.duplicate()
	best_layout_length = layout_length
	best_layout_root = root
	best_clustering = report["clustering"]
	best_distance_score = report["distance_score"]
	best_clustering_score = report["clustering_score"]

func _evaluate_layout(edges: Array, total_length: float, coverage: int) -> Dictionary:
	if edges.is_empty() or coverage < 2:
		return {
			"fitness": 0.0,
			"distance_score": 0.0,
			"clustering_score": 0.0,
			"clustering": 0.0,
		}
	var adj: Dictionary = GraphMetrics.adjacency_from_edges(edges)
	var clustering: float = GraphMetrics.average_clustering(adj)
	return objective.describe(total_length, clustering)

func _initialize_pheromones() -> void:
	pheromone.clear()
	for a in adjacency.keys():
		for b in adjacency[a]:
			if a < b:
				pheromone[GraphMetrics.edge_key(a, b)] = tau_0

func _tau(i: int, j: int) -> float:
	return pheromone.get(GraphMetrics.edge_key(i, j), tau_0)

func _set_tau(i: int, j: int, value: float) -> void:
	pheromone[GraphMetrics.edge_key(i, j)] = clampf(value, tau_min, tau_max)

func _edge_value(i: int, j: int) -> float:
	var eta: float = 1.0 / dist_matrix[i][j]
	return pow(_tau(i, j), alpha) * pow(eta, beta)

func _select_frontier_edge(frontier: Array) -> Vector2i:
	var best_by_dest: Dictionary = {}
	var value_by_dest: Dictionary = {}
	for edge in frontier:
		var value: float = _edge_value(edge.x, edge.y)
		if not best_by_dest.has(edge.y) or value > value_by_dest[edge.y]:
			best_by_dest[edge.y] = edge
			value_by_dest[edge.y] = value

	var options: Array = best_by_dest.values()
	var denominator: float = 0.0
	for dest in value_by_dest.keys():
		denominator += value_by_dest[dest]

	if denominator <= 0.0:
		return options[_rng.randi() % options.size()]

	var random_point: float = _rng.randf() * denominator
	var current_sum: float = 0.0
	for edge in options:
		current_sum += value_by_dest[edge.y]
		if current_sum >= random_point:
			return edge
	return options.back()

func _select_loop_edges(candidates: Array, budget: int) -> Array:
	var pool: Array = candidates.duplicate()
	var selected: Array = []
	var count: int = mini(budget, pool.size())
	for _selection in range(count):
		var weights: Array = []
		var denominator: float = 0.0
		for edge in pool:
			var value: float = _edge_value(edge.x, edge.y)
			weights.append(value)
			denominator += value

		var pick: int = 0
		if denominator <= 0.0:
			pick = _rng.randi() % pool.size()
		else:
			var random_point: float = _rng.randf() * denominator
			var current_sum: float = 0.0
			for index in range(pool.size()):
				current_sum += weights[index]
				if current_sum >= random_point:
					pick = index
					break
		selected.append(pool[pick])
		pool.remove_at(pick)
	return selected

func _local_pheromone_update(i: int, j: int) -> void:
	_set_tau(i, j, (1.0 - rho) * _tau(i, j) + rho * tau_0)

func _global_pheromone_update() -> void:
	if best_layout_edges.is_empty():
		return
	if best_fitness <= 0.0 or best_fitness == -INF:
		return

	var delta_tau: float = best_fitness
	for edge in best_layout_edges:
		_set_tau(edge.x, edge.y, (1.0 - rho) * _tau(edge.x, edge.y) + rho * delta_tau)
