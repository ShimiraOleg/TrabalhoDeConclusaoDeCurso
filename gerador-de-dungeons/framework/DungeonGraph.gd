class_name DungeonGraph
extends RefCounted

var rooms: Array = []
var edges: Array = []
var adjacency: Dictionary = {}
var dist_matrix: Dictionary = {}

static func build(points: Array, delaunay_edges: Array) -> DungeonGraph:
	var graph := DungeonGraph.new()
	graph.rooms = points
	graph.edges = delaunay_edges
	graph.adjacency = GraphMetrics.adjacency_from_edges(delaunay_edges, points.size())
	graph.dist_matrix = _build_distance_matrix(points, delaunay_edges)
	return graph

static func _build_distance_matrix(points: Array, graph_edges: Array) -> Dictionary:
	var distances: Dictionary = {}
	for index in range(points.size()):
		distances[index] = {}
	for edge in graph_edges:
		var weight: float = (points[edge.x] as Vector2).distance_to(points[edge.y])
		distances[edge.x][edge.y] = weight
		distances[edge.y][edge.x] = weight
	return distances

func node_count() -> int:
	return rooms.size()

func edge_weight(a: int, b: int) -> float:
	return GraphMetrics.edge_weight(dist_matrix, a, b)

func mst_length() -> float:
	return GraphMetrics.mst_length(dist_matrix, adjacency)
