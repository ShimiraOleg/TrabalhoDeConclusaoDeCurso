extends Node3D

@onready var timerprocessor := $Timer
@onready var forward := $RayForward
@onready var back := $RayBack
@onready var right := $RayRight
@onready var left := $RayLeft

func collision_check(direction) -> bool:
	return direction != null and direction.is_colliding()

func get_direction(direction):
	if not direction is RayCast3D:
		return
	return direction.get_collider().global_transform.origin - global_transform.origin

func _tween_to(property: String, target) -> void:
	var tween := create_tween()
	tween.tween_property(self, property, target, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(timerprocessor.start)

func tween_translation(change) -> void:
	$AnimationPlayer.play("Step")
	_tween_to("position", position + change)

func tween_rotation(change) -> void:
	_tween_to("rotation", rotation + Vector3(0, change, 0))

func _on_Timer_timeout() -> void:
	var turn_direction := (
		int(Input.is_action_pressed("turn_left"))
		- int(Input.is_action_pressed("turn_right"))
	)
	var movement_ray = _movement_ray()

	if movement_ray == null and turn_direction:
		timerprocessor.stop()
		tween_rotation(PI / 2 * turn_direction)
		return

	if collision_check(movement_ray):
		timerprocessor.stop()
		tween_translation(get_direction(movement_ray))

func _movement_ray():
	if Input.is_action_pressed("forward"):
		return forward
	if Input.is_action_pressed("back"):
		return back
	if Input.is_action_pressed("strafe_left"):
		return left
	if Input.is_action_pressed("strafe_right"):
		return right
	return null
