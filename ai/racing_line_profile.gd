class_name RacingLineProfile
extends RefCounted
## Curvature-based target speed plan with braking and acceleration passes.

var track: CircuitTrack
var tuning: CarTuning
var spacing := 4.0
var distances := PackedFloat32Array()
var curvatures := PackedFloat32Array()
var target_speeds := PackedFloat32Array()

func build(track_value: CircuitTrack, tuning_value: CarTuning) -> void:
	track = track_value
	tuning = tuning_value
	spacing = track.total_length / float(RaceConfig.ai_profile_samples)
	distances.clear()
	curvatures.clear()
	target_speeds.clear()
	for index in RaceConfig.ai_profile_samples:
		var distance := float(index) * spacing
		distances.append(distance)
		curvatures.append(track.curvature_at(distance))
		target_speeds.append(_corner_speed(float(curvatures[index])))
	_backward_brake_pass()
	_forward_accel_pass()

func _corner_speed(curvature: float) -> float:
	if curvature < RaceConfig.ai_straight_curvature:
		return RaceConfig.ai_top_speed
	var speed := RaceConfig.ai_initial_corner_speed
	for iteration in RaceConfig.ai_corner_iterations:
		var downforce_load := 0.5 * tuning.air_density * tuning.lift_cl_area * speed * speed
		var lateral_accel := tuning.tyre_mu * RaceConfig.gravity * (1.0 + downforce_load / (tuning.mass_kg * RaceConfig.gravity)) * RaceConfig.ai_lateral_margin
		speed = sqrt(lateral_accel / maxf(curvature, RaceConfig.ai_straight_curvature))
	return clampf(speed, RaceConfig.ai_min_corner_speed, RaceConfig.ai_top_speed)

func _backward_brake_pass() -> void:
	for pass_index in RaceConfig.ai_profile_relaxation_passes:
		for index in range(target_speeds.size() - 1, -1, -1):
			var next := (index + 1) % target_speeds.size()
			var cap := sqrt(target_speeds[next] * target_speeds[next] + 2.0 * RaceConfig.ai_braking_accel * spacing)
			target_speeds[index] = minf(target_speeds[index], cap)

func _forward_accel_pass() -> void:
	for pass_index in RaceConfig.ai_profile_relaxation_passes:
		for index in target_speeds.size():
			var previous := posmod(index - 1, target_speeds.size())
			var cap := sqrt(target_speeds[previous] * target_speeds[previous] + 2.0 * RaceConfig.ai_accel * spacing)
			target_speeds[index] = minf(target_speeds[index], cap)

func target_speed_at(progress: float) -> float:
	if target_speeds.is_empty():
		return RaceConfig.ai_min_corner_speed
	var position := fposmod(progress, track.total_length) / spacing
	var first := int(position) % target_speeds.size()
	var second := (first + 1) % target_speeds.size()
	return lerpf(target_speeds[first], target_speeds[second], position - floorf(position))

func upcoming_min_speed(progress: float, lookahead: float) -> float:
	var count := maxi(1, int(lookahead / spacing))
	var slowest := RaceConfig.ai_top_speed
	for offset in count + 1:
		slowest = minf(slowest, target_speed_at(progress + float(offset) * spacing))
	return slowest
