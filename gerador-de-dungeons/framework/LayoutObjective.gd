class_name LayoutObjective
extends RefCounted

var w_distance: float = 1.0
var w_clustering: float = 1.0
var target_clustering: float = 0.25
var reference_length: float = 0.0

func configure_reference(mst_length: float) -> void:
	reference_length = mst_length

func distance_score(total_length: float) -> float:
	if reference_length <= 0.0 or total_length <= 0.0:
		return 0.0
	return clampf(reference_length / total_length, 0.0, 1.0)

func clustering_score(clustering: float) -> float:
	var target: float = clampf(target_clustering, 0.0, 1.0)
	var maximum_deviation: float = maxf(target, 1.0 - target)
	if maximum_deviation <= 0.0:
		return 1.0
	return clampf(
		1.0 - absf(clustering - target) / maximum_deviation,
		0.0,
		1.0
	)

func evaluate(total_length: float, clustering: float) -> float:
	var weight_sum: float = w_distance + w_clustering
	if weight_sum <= 0.0:
		return 0.0
	return (
		w_distance * distance_score(total_length)
		+ w_clustering * clustering_score(clustering)
	) / weight_sum

func describe(total_length: float, clustering: float) -> Dictionary:
	return {
		"fitness": evaluate(total_length, clustering),
		"distance_score": distance_score(total_length),
		"clustering_score": clustering_score(clustering),
		"clustering": clustering,
		"total_length": total_length,
		"reference_length": reference_length,
	}
