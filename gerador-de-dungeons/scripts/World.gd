extends DungeonScene

@export_group("Cena (procedural)")
@export var cell_scene: PackedScene
@export var metrics_label_path: NodePath
@export var regenerate_button_path: NodePath
@export var dungeon_view_path: NodePath
@export_group("Geração")
@export var room_count: int = 12
@export var min_separation: float = 90.0
@export var use_fixed_seed: bool = false
@export var dungeon_seed: int = 0
@export var tile_scale: float = 30.0
@export var room_radius: int = 1
@export var auto_generate_on_ready: bool = true
@export_group("ACO")
@export var max_iterations: int = 10
@export var ant_count: int = 5
@export var alpha: float = 1.0
@export var beta: float = 2.0
@export var rho: float = 0.1
@export var tau_0: float = 0.1
@export var tau_min: float = 0.01
@export var tau_max: float = 5.0
@export var loop_factor: float = 0.2
@export_group("Função objetiva")
@export var w_distance: float = 1.0
@export var w_clustering: float = 1.0
@export_range(0.0, 1.0) var target_clustering: float = 0.25
@export_group("Aleatorização")
@export var randomize_parameters: bool = false
@export_subgroup("MinMax aleatorio")
@export var room_count_range: Vector2i = Vector2i(8, 16)
@export var min_separation_range: Vector2 = Vector2(70.0, 110.0)
@export var max_iterations_range: Vector2i = Vector2i(8, 16)
@export var ant_count_range: Vector2i = Vector2i(4, 10)
@export var alpha_range: Vector2 = Vector2(0.5, 2.0)
@export var beta_range: Vector2 = Vector2(1.0, 4.0)
@export var rho_range: Vector2 = Vector2(0.05, 0.30)
@export var tau_0_range: Vector2 = Vector2(0.05, 0.20)
@export var loop_factor_range: Vector2 = Vector2(0.0, 0.4)
@export var w_distance_range: Vector2 = Vector2(0.5, 1.5)
@export var w_clustering_range: Vector2 = Vector2(0.5, 1.5)
@export var target_clustering_range: Vector2 = Vector2(0.10, 0.40)

var metrics_label: Label
var dungeon_view: Node
var last_params: Dictionary = {}
var last_raster_metrics: Dictionary = {}

var _rng := RandomNumberGenerator.new()

func _scene_ready() -> void:
	metrics_label = _opt(metrics_label_path) as Label
	dungeon_view = _opt(dungeon_view_path)
	var regenerate_button := _opt(regenerate_button_path)
	if regenerate_button is Button:
		(regenerate_button as Button).pressed.connect(regenerate)
	if auto_generate_on_ready:
		build_world()

func _handle_key(keycode: Key) -> void:
	if keycode == KEY_R:
		regenerate()
	if keycode == KEY_F12:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://figura_delaunay_seed_%d.png" % dungeon_seed)

func regenerate() -> void:
	build_world()

func build_world() -> void:
	clear_cells()
	if not cell_scene:
		push_error("World: set 'cell_scene' (Cell.tscn) in the Inspector.")
		return

	var result := _run_generator()
	var rasterizer := _make_rasterizer()
	var raster := rasterizer.rasterize(result)
	var floor_cells := _floor_cells(raster)
	if floor_cells.is_empty():
		push_warning("World: no floor cells generated.")
		return

	_spawn_cells(floor_cells)
	place_player(raster.get("start_pos", Vector2i.ZERO))
	set_endpoints(
		raster.get("start_pos", Vector2i.ZERO),
		raster.get("end_pos", Vector2i.ZERO)
	)

	var raster_edges: Array = rasterizer.reconstruct_graph(
		raster.get("grid", {}),
		raster.get("grid_rooms", [])
	)
	last_raster_metrics = GraphMetrics.layout_metrics(
		raster_edges,
		int(result.get("actual_room_count", 0)),
		int(result.get("start_room", -1)),
		int(result.get("end_room", -1))
	)

	update_minimap_grid(
		raster.get("grid", {}),
		raster.get("start_pos", Vector2i.ZERO),
		raster.get("end_pos", Vector2i.ZERO)
	)
	if dungeon_view and dungeon_view.has_method("set_data"):
		dungeon_view.set_data(result)
	_update_metrics(result)

func _run_generator() -> Dictionary:
	var params := _sample_params()
	last_params = params
	var generator := DungeonGenerator.new()
	generator.apply_params(params)
	var configured_room_count: int = int(params["room_count"])
	var configured_separation: float = float(params["min_separation"])
	var side: float = maxf(
		400.0,
		ceil(sqrt(float(configured_room_count))) * configured_separation * 2.0
	)
	generator.bounds = Rect2(
		Vector2(configured_separation, configured_separation),
		Vector2(side, side)
	)
	return generator.generate()

func _sample_params() -> Dictionary:
	if use_fixed_seed:
		_rng.seed = dungeon_seed
	else:
		_rng.randomize()

	var should_randomize := randomize_parameters
	var params := {
		"room_count": _ri(room_count_range) if should_randomize else room_count,
		"min_separation": _rf(min_separation_range) if should_randomize else min_separation,
		"max_iterations": _ri(max_iterations_range) if should_randomize else max_iterations,
		"ant_count": _ri(ant_count_range) if should_randomize else ant_count,
		"alpha": _rf(alpha_range) if should_randomize else alpha,
		"beta": _rf(beta_range) if should_randomize else beta,
		"rho": _rf(rho_range) if should_randomize else rho,
		"tau_0": _rf(tau_0_range) if should_randomize else tau_0,
		"tau_min": tau_min,
		"tau_max": tau_max,
		"loop_factor": _rf(loop_factor_range) if should_randomize else loop_factor,
		"w_distance": _rf(w_distance_range) if should_randomize else w_distance,
		"w_clustering": _rf(w_clustering_range) if should_randomize else w_clustering,
		"target_clustering": _rf(target_clustering_range) if should_randomize else target_clustering,
	}
	params["use_fixed_seed"] = true
	params["seed"] = _rng.randi()
	return params

func _ri(r: Vector2i) -> int:
	return _rng.randi_range(mini(r.x, r.y), maxi(r.x, r.y))

func _rf(r: Vector2) -> float:
	return _rng.randf_range(minf(r.x, r.y), maxf(r.x, r.y))

func _make_rasterizer() -> GridRasterizer:
	var rasterizer := GridRasterizer.new()
	rasterizer.tile_scale = tile_scale
	rasterizer.room_radius = room_radius
	return rasterizer

func _floor_cells(raster: Dictionary) -> Array:
	var floor_cells: Array[Vector2i] = []
	var grid: Dictionary = raster.get("grid", {})
	for tile_position in grid.keys():
		if grid[tile_position] == GridRasterizer.TILE_FLOOR:
			floor_cells.append(tile_position)
	return floor_cells

func _spawn_cells(floor_cells: Array) -> void:
	for tile in floor_cells:
		var cell := cell_scene.instantiate()
		add_child(cell)
		(cell as Node3D).position = Globals.grid_to_world(tile)
		cell_by_pos[tile] = cell
	for cell in cell_by_pos.values():
		cell.update_faces(cell_by_pos)

func _update_metrics(result: Dictionary) -> void:
	if not metrics_label:
		return

	var rooms: Array = result.get("rooms", [])
	var corridors: Array = result.get("corridor_edges", [])
	metrics_label.text = (
		"Salas: %d\n"
		+ "Corredores: %d (reparados: %d)\n"
		+ "Grau médio (grafo): %.2f | (raster): %.2f\n"
		+ "Coef. agrupamento (grafo): %.3f | (raster): %.3f\n"
		+ "Início <-> Fim: %s (%d corredores)\n"
		+ "Fitness: %.3f (dist %.3f | agrup %.3f)"
	) % [
		rooms.size(),
		corridors.size(),
		int(result.get("repaired_edges", 0)),
		result.get("average_degree", 0.0),
		last_raster_metrics.get("average_degree", 0.0),
		result.get("average_clustering", 0.0),
		last_raster_metrics.get("average_clustering", 0.0),
		"Sim" if result.get("start_end_connected", false) else "Não",
		int(result.get("start_end_hops", -1)),
		result.get("best_fitness", 0.0),
		result.get("distance_score", 0.0),
		result.get("clustering_score", 0.0),
	]

	var params := last_params
	if not params.is_empty():
		metrics_label.text += (
			"\n— parâmetros —\n"
			+ "Salas alvo: %d | Sep: %.0f\n"
			+ "iter: %d | formigas: %d\n"
			+ "α=%.2f β=%.2f ρ=%.2f τ0=%.2f\n"
			+ "loop=%.2f\n"
			+ "w_dist=%.2f w_clust=%.2f alvo_agrup=%.2f\n"
			+ "Seed: %d"
		) % [
			int(params.get("room_count", 0)), float(params.get("min_separation", 0.0)),
			int(params.get("max_iterations", 0)), int(params.get("ant_count", 0)),
			float(params.get("alpha", 0.0)), float(params.get("beta", 0.0)),
			float(params.get("rho", 0.0)), float(params.get("tau_0", 0.0)),
			float(params.get("loop_factor", 0.0)),
			float(params.get("w_distance", 0.0)), float(params.get("w_clustering", 0.0)),
			float(params.get("target_clustering", 0.0)),
			int(params.get("seed", 0)),
		]
