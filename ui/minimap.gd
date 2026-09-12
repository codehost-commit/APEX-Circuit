class_name TrackMinimap
extends Control

var circuit: CircuitTrack
var cars: Array[RaycastFormulaCar] = []
var bounds := Rect2(-170.0, -155.0, 340.0, 300.0)

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	_recalculate_bounds()
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _recalculate_bounds() -> void:
	if circuit == null:
		return
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for point in circuit.centerline:
		min_x = minf(min_x, point.x)
		min_z = minf(min_z, point.z)
		max_x = maxf(max_x, point.x)
		max_z = maxf(max_z, point.z)
	bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z).grow(18.0)

func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	if circuit == null:
		return
	for index in circuit.centerline.size():
		var first := _map(circuit.centerline[index])
		var second := _map(circuit.centerline[(index + 1) % circuit.centerline.size()])
		draw_line(first, second, Color("#bfc8d1"), 4.0, true)
	for car in cars:
		if not is_instance_valid(car):
			continue
		var dot := _map(car.global_position)
		var color := Color("#ffffff") if car.player_controlled else car.livery_color
		draw_circle(dot, 4.4 if car.player_controlled else 3.0, color)

func _map(world_position: Vector3) -> Vector2:
	var relative := Vector2(world_position.x - bounds.position.x, world_position.z - bounds.position.y)
	var scale := minf((size.x - 18.0) / maxf(bounds.size.x, 1.0), (size.y - 18.0) / maxf(bounds.size.y, 1.0))
	var drawing_size := bounds.size * scale
	var origin := (size - drawing_size) * 0.5
	return origin + relative * scale

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.82)
	style.border_color = Color("#6387a7")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
