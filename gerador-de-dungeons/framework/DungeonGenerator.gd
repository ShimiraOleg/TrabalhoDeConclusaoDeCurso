class_name DungeonGenerator
extends RefCounted

var room_count: int = 12
var bounds: Rect2 = Rect2(Vector2(60, 60), Vector2(900, 540))
var min_separation: float = 90.0
var use_fixed_seed: bool = true
var dungeon_seed: int = 0
var max_iterations: int = 10
var ant_count: int = 5
var alpha: float = 1.0
var beta: float = 2.0
var rho: float = 0.1
var tau_0: float = 0.1
var tau_min: float = 0.01
var tau_max: float = 5.0
var loop_factor: float = 0.2
var w_distance: float = 1.0
var w_clustering: float = 1.0
var target_clustering: float = 0.25
var graph: DungeonGraph
var aco: AntColonyOptimizer
var objective: LayoutObjective
var result: Dictionary = {}

var _seeds: Dictionary = {}

func generate() -> Dictionary:
	_derive_seeds()
	var rooms_rng := _rng_for("rooms")
	var aco_rng := _rng_for("aco")
	var endpoints_rng := _rng_for("endpoints")

	var sampled: Dictionary = RoomSampler.sample(
		room_count,
		bounds,
		min_separation,
		rooms_rng
	)
	var points: Array = sampled["points"]
	var delaunay_edges: Array = DelaunayTriangulator.triangulate_edges(points)
	graph = DungeonGraph.build(points, delaunay_edges)

	_configure_objective()
	_configure_optimizer(aco_rng)

	var corridor_edges: Array = aco.get_corridor_edges()
	var repaired_edges: int = _repair_connectivity(corridor_edges)
	var layout_length: float = GraphMetrics.total_length(corridor_edges, graph.dist_matrix)
	var endpoints: Dictionary = _pick_endpoints(corridor_edges, endpoints_rng)
	var layout: Dictionary = GraphMetrics.layout_metrics(
		corridor_edges,
		graph.node_count(),
		endpoints["start"],
		endpoints["end"]
	)

	result = _build_result(
		sampled,
		corridor_edges,
		repaired_edges,
		layout_length,
		endpoints,
		layout
	)
	return result

func _configure_objective() -> void:
	objective = LayoutObjective.new()
	objective.w_distance = w_distance
	objective.w_clustering = w_clustering
	objective.target_clustering = target_clustering

func _configure_optimizer(rng: RandomNumberGenerator) -> void:
	aco = AntColonyOptimizer.new()
	aco.max_iterations = max_iterations
	aco.ant_count = ant_count
	aco.alpha = alpha
	aco.beta = beta
	aco.rho = rho
	aco.tau_0 = tau_0
	aco.tau_min = tau_min
	aco.tau_max = tau_max
	aco.loop_factor = loop_factor
	aco.objective = objective
	aco.configure(rng)
	aco.load_graph(graph)
	aco.run()

func _build_result(
	sampled: Dictionary,
	corridor_edges: Array,
	repaired_edges: int,
	layout_length: float,
	endpoints: Dictionary,
	layout: Dictionary
) -> Dictionary:
	return {
		"rooms": graph.rooms.duplicate(),
		"delaunay_edges": graph.edges.duplicate(),
		"corridor_edges": corridor_edges,
		"layout_root": aco.best_layout_root,
		"best_length": layout_length,
		"aco_length": aco.best_layout_length,
		"best_fitness": aco.best_fitness,
		"distance_score": aco.best_distance_score,
		"clustering_score": aco.best_clustering_score,
		"reference_length": objective.reference_length,
		"average_degree": layout["average_degree"],
		"average_clustering": layout["average_clustering"],
		"start_end_connected": layout["start_end_connected"],
		"component_count": layout["component_count"],
		"repaired_edges": repaired_edges,
		"start_room": endpoints["start"],
		"end_room": endpoints["end"],
		"start_end_hops": endpoints["hops"],
		"actual_room_count": graph.node_count(),
		"used_separation": sampled["used_separation"],
		"separation_relax_rounds": sampled["relax_rounds"],
		"seeds": _seeds.duplicate(),
	}

func _derive_seeds() -> void:
	var base: int = dungeon_seed
	if not use_fixed_seed:
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		base = picker.randi()
	_seeds = {"base": base}

func _rng_for(stream: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var stream_seed: int = hash("%s:%d" % [stream, int(_seeds["base"])])
	rng.seed = stream_seed
	_seeds[stream] = stream_seed
	return rng

func _repair_connectivity(layout_edges: Array) -> int:
	var node_count: int = graph.node_count()
	if node_count <= 1:
		return 0

	var repaired: int = 0
	while true:
		var adjacency: Dictionary = GraphMetrics.adjacency_from_edges(layout_edges, node_count)
		var components: Array = GraphMetrics.components(adjacency, node_count)
		if components.size() <= 1:
			break

		var component_of: Dictionary = _component_lookup(components)
		var best_edge := _shortest_cross_component_graph_edge(component_of)
		var best_weight: float = INF
		if best_edge.x >= 0:
			best_weight = graph.edge_weight(best_edge.x, best_edge.y)

		if best_edge.x < 0:
			best_edge = _shortest_cross_component_room_edge(components[0], components[1])
			best_weight = (graph.rooms[best_edge.x] as Vector2).distance_to(graph.rooms[best_edge.y])
			graph.dist_matrix[best_edge.x][best_edge.y] = best_weight
			graph.dist_matrix[best_edge.y][best_edge.x] = best_weight

		layout_edges.append(GraphMetrics.edge_key(best_edge.x, best_edge.y))
		repaired += 1
	return repaired

func _component_lookup(components: Array) -> Dictionary:
	var component_of: Dictionary = {}
	for component_index in range(components.size()):
		for node in components[component_index]:
			component_of[node] = component_index
	return component_of

func _shortest_cross_component_graph_edge(component_of: Dictionary) -> Vector2i:
	var best_edge := Vector2i(-1, -1)
	var best_weight: float = INF
	for edge in graph.edges:
		if component_of[edge.x] != component_of[edge.y]:
			var weight: float = graph.edge_weight(edge.x, edge.y)
			if weight < best_weight:
				best_weight = weight
				best_edge = edge
	return best_edge

func _shortest_cross_component_room_edge(
	first_component: Array,
	second_component: Array
) -> Vector2i:
	var best_edge := Vector2i(-1, -1)
	var best_weight: float = INF
	for first_node in first_component:
		for second_node in second_component:
			var weight: float = (graph.rooms[first_node] as Vector2).distance_to(graph.rooms[second_node])
			if weight < best_weight:
				best_weight = weight
				best_edge = Vector2i(first_node, second_node)
	return best_edge

func _pick_endpoints(corridor_edges: Array, rng: RandomNumberGenerator) -> Dictionary:
	var node_count: int = graph.node_count()
	if node_count == 0:
		return {"start": -1, "end": -1, "hops": -1}
	if node_count == 1:
		return {"start": 0, "end": 0, "hops": 0}

	var adjacency: Dictionary = GraphMetrics.adjacency_from_edges(corridor_edges, node_count)
	var start_room: int = rng.randi() % node_count
	var distances: Dictionary = GraphMetrics.bfs_distances(adjacency, start_room)
	var endpoint: Dictionary = _farthest_reachable_endpoint(distances, start_room)

	if endpoint["room"] >= 0:
		return {
			"start": start_room,
			"end": endpoint["room"],
			"hops": endpoint["hops"],
		}

	var farthest_room: int = _farthest_spatial_room(start_room)
	return {"start": start_room, "end": farthest_room, "hops": -1}

func _farthest_reachable_endpoint(distances: Dictionary, start_room: int) -> Dictionary:
	var end_room: int = -1
	var best_hops: int = -1
	for node in distances.keys():
		if node == start_room:
			continue
		if distances[node] > best_hops:
			best_hops = distances[node]
			end_room = node
	return {"room": end_room, "hops": best_hops}

func _farthest_spatial_room(start_room: int) -> int:
	var end_room: int = -1
	var max_distance: float = -INF
	for index in range(graph.node_count()):
		if index == start_room:
			continue
		var distance: float = (graph.rooms[start_room] as Vector2).distance_to(graph.rooms[index])
		if distance > max_distance:
			max_distance = distance
			end_room = index
	return end_room

func apply_params(params: Dictionary) -> void:
	if params.has("room_count"):
		room_count = int(params["room_count"])
	if params.has("min_separation"):
		min_separation = float(params["min_separation"])
	if params.has("use_fixed_seed"):
		use_fixed_seed = bool(params["use_fixed_seed"])
	if params.has("seed"):
		dungeon_seed = int(params["seed"])
	if params.has("max_iterations"):
		max_iterations = int(params["max_iterations"])
	if params.has("ant_count"):
		ant_count = int(params["ant_count"])
	if params.has("alpha"):
		alpha = float(params["alpha"])
	if params.has("beta"):
		beta = float(params["beta"])
	if params.has("rho"):
		rho = float(params["rho"])
	if params.has("tau_0"):
		tau_0 = float(params["tau_0"])
	if params.has("tau_min"):
		tau_min = float(params["tau_min"])
	if params.has("tau_max"):
		tau_max = float(params["tau_max"])
	if params.has("loop_factor"):
		loop_factor = float(params["loop_factor"])
	if params.has("w_distance"):
		w_distance = float(params["w_distance"])
	if params.has("w_clustering"):
		w_clustering = float(params["w_clustering"])
	if params.has("target_clustering"):
		target_clustering = float(params["target_clustering"])
