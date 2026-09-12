class_name MenuCinematic
extends Node
## A camera occupies a real trackside position for an entire shot.

var circuit: CircuitTrack
var cars: Array[RaycastFormulaCar] = []
var drone: Camera3D
var fade: ColorRect
var active := true
var _elapsed := 0.0
var _cut_timer := 0.0
var _fade_phase := 0
var _shot := 0
var _anchor := Vector3.ZERO
var _target := Vector3.ZERO
var _normal := Vector3.RIGHT
var _focus: RaycastFormulaCar

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	drone = Camera3D.new()
	drone.name = "TracksideBroadcastCamera"
	drone.far = 18000.0
	add_child(drone)
	var canvas := CanvasLayer.new()
	canvas.layer = 4
	add_child(canvas)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade)
	_set_shot(0)

func set_active(value: bool) -> void:
	active = value
	drone.current = value
	fade.visible = value
	if value:
		_set_shot(_shot)

func _process(delta: float) -> void:
	if not active or circuit == null:
		return
	_elapsed += delta
	_cut_timer -= delta
	if _cut_timer <= 0.65 and _fade_phase == 0:
		_fade_phase = 1
	if _fade_phase == 1:
		fade.color.a = move_toward(fade.color.a, 1.0, delta / 0.65)
		if fade.color.a >= 0.99:
			_set_shot((_shot + 1) % 3)
			_fade_phase = 2
	elif _fade_phase == 2:
		fade.color.a = move_toward(fade.color.a, 0.0, delta / 0.65)
		if fade.color.a <= 0.01:
			_fade_phase = 0
	var drift := _normal * sin(_elapsed * 0.12) * (3.0 if _shot == 1 else 0.28)
	if _shot != 1:
		# Handheld vibration follows real nearby car speed and distance.
		var shake := 0.0
		var nearest := INF
		for car in cars:
			var distance := car.global_position.distance_to(_anchor)
			shake = maxf(shake, clampf(1.0 - distance / 32.0, 0.0, 1.0) * minf(car.speed_mps / 80.0, 1.0) * 0.055)
			if distance < nearest:
				nearest = distance
				_focus = car
		drift += Vector3(sin(_elapsed * 79.0), sin(_elapsed * 103.0), 0.0) * shake
	drone.global_position = _anchor + drift + Vector3.UP * sin(_elapsed * 0.25) * 0.15
	var target := _target
	if _focus != null and is_instance_valid(_focus) and _shot != 1:
		var follow := _focus.global_position + Vector3.UP * 0.7
		if follow.distance_to(_target) < 150.0:
			target = _target.lerp(follow, 0.75)
	var desired := drone.global_transform.looking_at(target, Vector3.UP).basis
	drone.global_basis = drone.global_basis.slerp(desired, 1.0 - exp(-delta * 1.7))

func _set_shot(value: int) -> void:
	_shot = value
	_elapsed = 0.0
	_cut_timer = randf_range(RaceConfig.preview_camera_cut_min, RaceConfig.preview_camera_cut_max)
	_focus = null
	for car in cars:
		if is_instance_valid(car) and car.speed_mps > 8.0:
			_focus = car
			break
	var progress: float = circuit.total_length * float([0.12, 0.57, 0.78][value])
	if _focus != null and value != 1:
		progress = _focus.race_progress + 75.0
	var sample := circuit.sample_at_distance(progress)
	_normal = sample.normal
	_target = sample.position + sample.tangent * 22.0 + Vector3.UP
	if value == 1:
		_anchor = sample.position + sample.normal * 110.0 - sample.tangent * 100.0 + Vector3.UP * 145.0
		drone.fov = 55.0
	elif value == 0:
		# Outside of the pit wall at the start straight, looking across the road.
		_anchor = sample.position - sample.normal * (RaceConfig.track_width * 0.5 + RaceConfig.kerb_width + 3.0) + Vector3.UP * 1.65
		drone.fov = 53.0
	else:
		_anchor = sample.position - sample.normal * (RaceConfig.track_width * 0.5 + RaceConfig.kerb_width + 9.0) + Vector3.UP * 7.0
		drone.fov = 48.0
	drone.global_position = _anchor
	drone.look_at(_target, Vector3.UP)
