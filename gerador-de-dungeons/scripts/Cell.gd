class_name Cell
extends Node3D

@onready var top_face := $TopFace
@onready var north_face := $NorthFace
@onready var east_face := $EastFace
@onready var south_face := $SouthFace
@onready var west_face := $WestFace
@onready var bottom_face := $BottomFace

func update_faces(occupied: Dictionary) -> void:
	var grid_position := Globals.world_to_grid(position)
	var faces_by_direction := {
		east_face: Vector2i.RIGHT,
		west_face: Vector2i.LEFT,
		south_face: Vector2i.DOWN,
		north_face: Vector2i.UP,
	}
	for face in faces_by_direction:
		if not is_instance_valid(face):
			continue
		if occupied.has(grid_position + faces_by_direction[face]):
			face.queue_free()
