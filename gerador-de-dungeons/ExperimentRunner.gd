extends SceneTree

## Headless experiment pipeline for the evaluation chapter.
## Run with:
##   godot --headless --script res://ExperimentRunner.gd
## Output: user://experiments.csv (one row per config x seed), containing
## both graph metrics and raster metrics computed with the same
## GraphMetrics definitions.

const SEEDS: int = 30
const OUTPUT_PATH: String = "user://experiments.csv"

const HEADER: String = (
	"config,seed,rooms,corridors,repaired_edges,"
	+ "avg_degree,avg_clustering,connected,component_count,hops,"
	+ "fitness,distance_score,clustering_score,length,reference_length,"
	+ "raster_edges,raster_avg_degree,raster_avg_clustering,raster_connected,"
	+ "used_separation,ms"
)

func _init() -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ExperimentRunner: could not open %s." % OUTPUT_PATH)
		quit(1)
		return

	file.store_line(HEADER)
	var configs := _configs()
	for config in configs:
		print("Running config '%s' (%d seeds)..." % [config["id"], SEEDS])
		for seed in range(1, SEEDS + 1):
			file.store_line(_run_one(config, seed))
	file.close()
	print("Done. Results at %s (%d configs x %d seeds)." % [
		OUTPUT_PATH,
		configs.size(),
		SEEDS,
	])
	quit()

func _run_one(config: Dictionary, run_seed: int) -> String:
	var generator := DungeonGenerator.new()
	generator.apply_params(config)
	generator.use_fixed_seed = true
	generator.dungeon_seed = run_seed

	var start_time := Time.get_ticks_msec()
	var result := generator.generate()
	var elapsed: int = Time.get_ticks_msec() - start_time

	var rasterizer := GridRasterizer.new()
	rasterizer.tile_scale = float(config.get("tile_scale", 30.0))
	rasterizer.room_radius = int(config.get("room_radius", 1))
	var raster := rasterizer.rasterize(result)
	var raster_edges: Array = rasterizer.reconstruct_graph(
		raster.get("grid", {}),
		raster.get("grid_rooms", [])
	)
	var raster_metrics: Dictionary = GraphMetrics.layout_metrics(
		raster_edges,
		int(result["actual_room_count"]),
		int(result["start_room"]),
		int(result["end_room"])
	)

	return "%s,%d,%d,%d,%d,%.4f,%.4f,%s,%d,%d,%.6f,%.4f,%.4f,%.2f,%.2f,%d,%.4f,%.4f,%s,%.1f,%d" % [
		config["id"],
		run_seed,
		int(result["actual_room_count"]),
		(result["corridor_edges"] as Array).size(),
		int(result["repaired_edges"]),
		float(result["average_degree"]),
		float(result["average_clustering"]),
		str(result["start_end_connected"]),
		int(result["component_count"]),
		int(result["start_end_hops"]),
		float(result["best_fitness"]),
		float(result["distance_score"]),
		float(result["clustering_score"]),
		float(result["best_length"]),
		float(result["reference_length"]),
		raster_edges.size(),
		float(raster_metrics["average_degree"]),
		float(raster_metrics["average_clustering"]),
		str(raster_metrics["start_end_connected"]),
		float(result["used_separation"]),
		elapsed,
	]

func _configs() -> Array:
	var base := {
		"room_count": 12, "min_separation": 90.0,
		"max_iterations": 10, "ant_count": 5,
		"alpha": 1.0, "beta": 2.0, "rho": 0.1, "tau_0": 0.1,
		"loop_factor": 0.2,
		"w_distance": 1.0, "w_clustering": 1.0, "target_clustering": 0.25,
	}
	var configurations: Array = []
	configurations.append(_variant(base, "baseline", {}))

	configurations.append(_variant(base, "alpha_0.5", {"alpha": 0.5}))
	configurations.append(_variant(base, "alpha_2.0", {"alpha": 2.0}))
	configurations.append(_variant(base, "beta_1.0", {"beta": 1.0}))
	configurations.append(_variant(base, "beta_4.0", {"beta": 4.0}))
	configurations.append(_variant(base, "rho_0.05", {"rho": 0.05}))
	configurations.append(_variant(base, "rho_0.30", {"rho": 0.30}))

	configurations.append(_variant(base, "loop_0.0", {"loop_factor": 0.0}))
	configurations.append(_variant(base, "loop_0.4", {"loop_factor": 0.4}))
	configurations.append(_variant(base, "target_0.10", {"target_clustering": 0.10}))
	configurations.append(_variant(base, "target_0.40", {"target_clustering": 0.40}))

	configurations.append(_variant(base, "rooms_8", {"room_count": 8}))
	configurations.append(_variant(base, "rooms_16", {"room_count": 16}))
	configurations.append(_variant(base, "rooms_24", {"room_count": 24}))
	return configurations

func _variant(base: Dictionary, id: String, overrides: Dictionary) -> Dictionary:
	var config := base.duplicate()
	for key in overrides.keys():
		config[key] = overrides[key]
	config["id"] = id
	return config
