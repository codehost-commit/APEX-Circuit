class_name MenuCinematic
extends Node
## Alternates a low kerb camera and aerial drone over the real simulated cars.

var circuit: CircuitTrack
var cars: Array[RaycastFormulaCar] = []
var drone: Camera3D
var fade: ColorRect
var active := true
var _cut_timer := 0.0
var _fade_phase := 0.0
var _shot := 0
var _random := RandomNumberGenerator.new()

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	_random.randomize()
	_create_camera_and_fade()
	_cut_timer = _random.randf_range(RaceConfig.preview_camera_cut_min, RaceConfig.preview_camera_cut_max)
	_set_shot(0)

func set_active(value: bool) -> void:
	active = value
	if drone != null:
		drone.current = value
	if fade != null:
		fade.visible = value

func _process(delta: float) -> void:
	if not active or circuit == null or drone == null:
		return
	_cut_timer -= delta
	if _cut_timer <= RaceConfig.menu_fade_seconds and _fade_phase == 0.0:
		_fade_phase = 1.0
	if _fade_phase == 1.0:
		fade.color.a = move_toward(fade.color.a, 1.0, delta / RaceConfig.menu_fade_seconds)
		if fade.color.a >= 0.98:
			_shot = 1 - _shot
			_set_shot(_shot)
			_fade_phase = 2.0
	elif _fade_phase == 2.0:
		fade.color.a = move_toward(fade.color.a, 0.0, delta / RaceConfig.menu_fade_seconds)
		if fade.color.a <= 0.02:
			_fade_phase = 0.0
			_cut_timer = _random.randf_range(RaceConfig.preview_camera_cut_min, RaceConfig.preview_camera_cut_max)
	_update_framing(delta)

func _create_camera_and_fade() -> void:
	drone = Camera3D.new()
	drone.name = "MenuDroneCamera"
	drone.fov = 63.0
	add_child(drone)
	var canvas := CanvasLayer.new()
	canvas.layer = 4
	add_child(canvas)
	fade = ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade)

func _set_shot(shot: int) -> void:
	var focus_car := _focus_car()
	var progress := focus_car.race_progress if focus_car != null else circuit.total_length * 0.25
	var sample := circuit.sample_at_distance(progress)
	if shot == 0:
		drone.global_position = sample.position + sample.normal * (RaceConfig.track_width * 0.5 + 2.0) + Vector3.UP * 1.05 - sample.tangent * 7.0
	else:
		drone.global_position = sample.position - sample.tangent * 38.0 + sample.normal * 22.0 + Vector3.UP * 38.0
	var target: Vector3 = focus_car.global_position + Vector3.UP * 0.8 if focus_car != null else sample.position
	drone.look_at(target, Vector3.UP)

func _update_framing(delta: float) -> void:
	var focus_car := _focus_car()
	if focus_car == null:
		return
	var sample := circuit.sample_at_distance(focus_car.race_progress)
	var target: Vector3 = focus_car.global_position + Vector3.UP * 0.8
	if _shot == 0:
		var desired: Vector3 = sample.position + sample.normal * (RaceConfig.track_width * 0.5 + 2.0) + Vector3.UP * 1.05 - sample.tangent * 7.0
		drone.global_position = drone.global_position.lerp(desired, delta * RaceConfig.menu_low_shot_follow)
	else:
		var desired: Vector3 = sample.position - sample.tangent * 38.0 + sample.normal * 22.0 + Vector3.UP * 38.0
		drone.global_position = drone.global_position.lerp(desired, delta * RaceConfig.menu_aerial_shot_follow)
	drone.look_at(target, Vector3.UP)

func _focus_car() -> RaycastFormulaCar:
	var best: RaycastFormulaCar
	var fastest := -1.0
	for car in cars:
		if car != null and car.speed_mps > fastest:
			best = car
			fastest = car.speed_mps
	return best
