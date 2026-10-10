class_name DungeonScene
extends Node3D

@export_group("Cena")
@export var player_path: NodePath = ^"Player"
@export var minimap_path: NodePath
@export var map_ui_path: NodePath
@export var exit_scene: PackedScene

var color_start: Color = Color(0.2, 0.8, 0.4)
var color_end: Color = Color(0.85, 0.3, 0.3)

var player: Node3D
var minimap: Node
var map_ui: Node
var cell_by_pos: Dictionary = {}

var _end_cell: Vector2i = Vector2i.ZERO
var _has_exit: bool = false
var _exit_triggered: bool = false

func _ready() -> void:
	player = _opt(player_path) as Node3D
	minimap = _opt(minimap_path)
	map_ui = _opt(map_ui_path)
	if map_ui:
		map_ui.set("visible", false)
	if minimap and minimap.has_method("set_player") and player:
		minimap.set_player(player, Globals.GRID_SIZE)
	_scene_ready()

func _scene_ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_map()
		else:
			_handle_key(event.keycode)

func _handle_key(_keycode: Key) -> void:
	pass

func _process(_delta: float) -> void:
	if _exit_triggered or not _has_exit or not player or not exit_scene:
		return
	if Globals.world_to_grid(player.global_position) == _end_cell:
		_exit_triggered = true
		get_tree().change_scene_to_packed(exit_scene)

func _toggle_map() -> void:
	if map_ui:
		map_ui.set("visible", not bool(map_ui.get("visible")))

func _opt(path: NodePath) -> Node:
	return get_node_or_null(path) if not path.is_empty() else null

func set_endpoints(start_pos: Vector2i, end_pos: Vector2i) -> void:
	_end_cell = end_pos
	_has_exit = true
	_exit_triggered = false
	_tint_cell(start_pos, color_start)
	_tint_cell(end_pos, color_end)

func place_player(start_pos: Vector2i) -> void:
	if player:
		player.position = Globals.grid_to_world(start_pos)

func update_minimap_grid(grid: Dictionary, start_pos: Vector2i, end_pos: Vector2i) -> void:
	if minimap and minimap.has_method("set_map"):
		minimap.set_map(grid, GridRasterizer.TILE_FLOOR, start_pos, end_pos)

func clear_cells() -> void:
	for cell in cell_by_pos.values():
		if is_instance_valid(cell):
			cell.queue_free()
	cell_by_pos.clear()

func _tint_cell(pos: Vector2i, color: Color) -> void:
	var cell: Node = cell_by_pos.get(pos, null)
	if not cell:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for child in cell.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material
