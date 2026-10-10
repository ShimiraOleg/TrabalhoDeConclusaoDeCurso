class_name DungeonView
extends Control

const COLOR_BG_GRID := Color(1, 1, 1, 0.04)
const COLOR_DELAUNAY_FADED := Color(0.35, 0.45, 0.6, 0.18)
const COLOR_CORRIDOR := Color(0.95, 0.78, 0.25, 1.0)
const COLOR_CORRIDOR_GLOW := Color(0.95, 0.78, 0.25, 0.25)
const COLOR_ROOM_FILL := Color(0.18, 0.22, 0.32, 1.0)
const COLOR_ROOM_BORDER := Color(0.85, 0.88, 0.95, 1.0)
const COLOR_ROOM_START := Color(0.30, 0.85, 0.50, 1.0)
const COLOR_ROOM_END := Color(0.92, 0.35, 0.35, 1.0)
const COLOR_LABEL := Color(0.85, 0.88, 0.95, 0.9)
const ROOM_RADIUS := 14.0
const CORRIDOR_WIDTH := 5.0
const CORRIDOR_GLOW_WIDTH := 14.0
const DELAUNAY_WIDTH := 1.5
const MARGIN := 24.0

var data: Dictionary = {}
var _font: Font
var _fit_scale := 1.0
var _fit_offset := Vector2.ZERO

func _ready() -> void:
	_font = ThemeDB.fallback_font
	resized.connect(queue_redraw)

func set_data(new_data: Dictionary) -> void:
	data = new_data
	queue_redraw()
	
func _update_fit(rooms: Array) -> void:
	var bounds := Rect2(rooms[0], Vector2.ZERO)
	for room_position in rooms:
		bounds = bounds.expand(room_position)
	bounds = bounds.grow(ROOM_RADIUS)  # evita cortar os círculos das bordas

	var available := size - Vector2(MARGIN, MARGIN) * 2.0
	_fit_scale = minf(
		available.x / maxf(bounds.size.x, 1.0),
		available.y / maxf(bounds.size.y, 1.0)
	)
	_fit_offset = (size - bounds.size * _fit_scale) * 0.5 - bounds.position * _fit_scale

func _draw() -> void:
	if data.is_empty():
		_draw_placeholder()
		return
	_draw_background_grid()
	_draw_final_state()

func _draw_placeholder() -> void:
	var message := "Pressione \"Gerar\" para iniciar."
	var area := _drawing_area()
	draw_string(
		_font,
		area / 2.0 - Vector2(120, 0),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		COLOR_LABEL
	)

func _draw_background_grid() -> void:
	var area := _drawing_area()
	var step := 40.0
	var x := 0.0
	while x < area.x:
		draw_line(Vector2(x, 0), Vector2(x, area.y), COLOR_BG_GRID, 1.0)
		x += step
	var y := 0.0
	while y < area.y:
		draw_line(Vector2(0, y), Vector2(area.x, y), COLOR_BG_GRID, 1.0)
		y += step

func _drawing_area() -> Vector2:
	var parent := get_parent()
	if parent is Control:
		return (parent as Control).size
	return get_viewport_rect().size

func _draw_final_state() -> void:
	var rooms: Array = data["rooms"]
	var delaunay_edges: Array = data["delaunay_edges"]
	var corridor_edges: Array = data["corridor_edges"]
	var corridor_set: Dictionary = {}
	
	_update_fit(rooms)
	draw_set_transform(_fit_offset, 0.0, Vector2(_fit_scale, _fit_scale))

	for edge in corridor_edges:
		corridor_set[edge] = true

	for edge in delaunay_edges:
		if not corridor_set.has(edge):
			var first: Vector2 = rooms[edge.x]
			var second: Vector2 = rooms[edge.y]
			draw_line(first, second, COLOR_DELAUNAY_FADED, DELAUNAY_WIDTH, true)

	for edge in corridor_edges:
		var first: Vector2 = rooms[edge.x]
		var second: Vector2 = rooms[edge.y]
		draw_line(first, second, COLOR_CORRIDOR_GLOW, CORRIDOR_GLOW_WIDTH, true)
		draw_line(first, second, COLOR_CORRIDOR, CORRIDOR_WIDTH, true)
		
	_draw_rooms(rooms)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_room_labels(rooms)

func _draw_rooms(rooms: Array) -> void:
	var start_index: int = data.get("start_room", -1)
	var end_index: int = data.get("end_room", -1)

	for index in range(rooms.size()):
		var room_position: Vector2 = rooms[index]
		var fill := COLOR_ROOM_FILL
		if index == start_index:
			fill = COLOR_ROOM_START
		elif index == end_index:
			fill = COLOR_ROOM_END

		draw_circle(room_position + Vector2(0, 2), ROOM_RADIUS, Color(0, 0, 0, 0.35))
		draw_circle(room_position, ROOM_RADIUS, fill)
		draw_arc(room_position, ROOM_RADIUS, 0, TAU, 32, COLOR_ROOM_BORDER, 2.0, true)

func _draw_room_labels(rooms: Array) -> void:
	var font_size := maxi(8, int(round(12.0 * _fit_scale)))
	for index in range(rooms.size()):
		var screen_position: Vector2 = rooms[index] * _fit_scale + _fit_offset
		var label := str(index + 1)
		var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			_font,
			screen_position - text_size / 2.0 + Vector2(0, font_size),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			COLOR_ROOM_BORDER
		)
