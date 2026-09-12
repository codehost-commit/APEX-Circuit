class_name RacingLineProfile
extends RefCounted
## Equal-car physical envelope: curvature, load-sensitive aero grip, then periodic
## braking/engine passes. Speeds are metres/second, distances are metres.

var track: CircuitTrack
var tuning: CarTuning
var spacing := 3.0
var distances := PackedFloat32Array()
var curvatures := PackedFloat32Array()
var target_speeds := PackedFloat32Array()
var nominal_lap_seconds := 0.0
var points := PackedVector3Array()
var offsets := PackedFloat32Array()
var _centres := PackedVector3Array()
var _normals := PackedVector3Array()

func build(track_value: CircuitTrack, tuning_value: CarTuning) -> void:
	track = track_value
	tuning = tuning_value
	var count := maxi(128, RaceConfig.ai_profile_samples)
	spacing = track.total_length / float(count)
	distances.resize(count)
	curvatures.resize(count)
	target_speeds.resize(count)
	_centres.resize(count)
	_normals.resize(count)
	offsets.resize(count)
	offsets.fill(0.0)
	for index in count:
		distances[index] = float(index) * spacing
		var sample := track.sample_at_distance(distances[index])
		_centres[index] = sample.position
		_normals[index] = sample.normal
	_solve_line()
	for index in count:
		var first := points[posmod(index - 1, count)]
		var middle := points[index]
		var last := points[(index + 1) % count]
		var a := middle - first
		var b := last - middle
		curvatures[index] = 2.0 * absf(a.cross(b).y) / maxf(a.length() * b.length() * (last - first).length(), 0.001)
	for index in count:
		var curvature := maxf(curvatures[index], maxf(curvatures[posmod(index - 1, count)], curvatures[(index + 1) % count]))
		target_speeds[index] = _corner_speed(curvature)
	# Iterate around the seam until BOTH longitudinal constraints converge.
	for iteration in 12:
		for index in range(count - 1, -1, -1):
			var following := (index + 1) % count
			var speed := target_speeds[following]
			var brake := longitudinal_capacity(following, speed, true)
			target_speeds[index] = minf(target_speeds[index], sqrt(speed * speed + 2.0 * brake * spacing))
		for index in count:
			var previous := posmod(index - 1, count)
			var speed := target_speeds[previous]
			var acceleration := longitudinal_capacity(previous, speed, false)
			target_speeds[index] = minf(target_speeds[index], sqrt(speed * speed + 2.0 * acceleration * spacing))
	nominal_lap_seconds = 0.0
	for speed in target_speeds:
		nominal_lap_seconds += spacing / maxf(speed, 1.0)

func _solve_line() -> void:
	# The prototype's bounded minimum-curvature coordinate solve, in SI units.
	var count := offsets.size()
	var limit := track.road_half_width - 1.9
	for iteration in 100:
		for index in count:
			var zero := _objective(index, 0.0)
			var low := _objective(index, -1.0)
			var high := _objective(index, 1.0)
			var quadratic := (low + high - 2.0 * zero) * 0.5
			if quadratic > 0.000001:
				offsets[index] = clampf(lerpf(offsets[index], -(high - low) / (4.0 * quadratic), 0.85), -limit, limit)
	for iteration in 80:
		for index in count:
			var next := (index + 1) % count
			var difference := offsets[next] - offsets[index]
			var excess := maxf(0.0, absf(difference) - spacing * 0.15) * 0.5
			offsets[index] += signf(difference) * excess
			offsets[next] -= signf(difference) * excess
	points.resize(count)
	for index in count:
		points[index] = _centres[index] + _normals[index] * offsets[index]

func _objective(changed: int, value: float) -> float:
	var saved := offsets[changed]
	offsets[changed] = value
	var result := 0.0
	var count := offsets.size()
	for offset in range(-1, 2):
		var middle := posmod(changed + offset, count)
		var first := posmod(middle - 1, count)
		var last := (middle + 1) % count
		var p0 := _centres[first] + _normals[first] * offsets[first]
		var p1 := _centres[middle] + _normals[middle] * offsets[middle]
		var p2 := _centres[last] + _normals[last] * offsets[last]
		result += (p0 - 2.0 * p1 + p2).length_squared()
	offsets[changed] = saved
	return result

func sample_at_distance(progress: float) -> Dictionary:
	var position := fposmod(progress, track.total_length) / spacing
	var index := int(position) % points.size()
	var blend := position - floorf(position)
	var before := points[posmod(index - 1, points.size())]
	var first := points[index]
	var second := points[(index + 1) % points.size()]
	var after := points[(index + 2) % points.size()]
	var point := first.cubic_interpolate(second, before, after, blend)
	var tangent := (second - first).normalized()
	return {"position": point, "tangent": tangent, "normal": tangent.cross(Vector3.UP),
		"offset": lerpf(offsets[index], offsets[(index + 1) % offsets.size()], blend)}

func lateral_capacity(speed: float) -> float:
	var load_ratio := 1.0 + 0.5 * tuning.air_density * tuning.lift_cl_area * speed * speed / (tuning.mass_kg * RaceConfig.gravity)
	var tyre_accel := tuning.tyre_mu * RaceConfig.gravity * pow(load_ratio, tuning.load_sensitivity)
	# Prototype steering rack targets 29 m/s². Keep a controllable reserve at the edge.
	return minf(tyre_accel, 29.0) * RaceConfig.ai_lateral_margin

func longitudinal_capacity(index: int, speed: float, braking: bool) -> float:
	var available := lateral_capacity(speed) / RaceConfig.ai_lateral_margin
	var lateral := speed * speed * curvatures[index]
	var remaining := sqrt(maxf(1.0, available * available - lateral * lateral))
	if braking:
		return clampf(remaining * RaceConfig.ai_plan_brake_margin, 5.0, RaceConfig.ai_braking_accel)
	return minf(remaining * RaceConfig.ai_plan_accel_margin, RaceConfig.ai_accel)

func _corner_speed(curvature: float) -> float:
	if curvature < 0.0001:
		return RaceConfig.ai_top_speed
	var speed := 35.0
	for iteration in 8:
		speed = sqrt(lateral_capacity(speed) / curvature)
	return clampf(speed * RaceConfig.ai_profile_safety, RaceConfig.ai_min_corner_speed, RaceConfig.ai_top_speed)

func target_speed_at(progress: float) -> float:
	if target_speeds.is_empty():
		return RaceConfig.ai_min_corner_speed
	var position := fposmod(progress, track.total_length) / spacing
	var first := int(position) % target_speeds.size()
	return lerpf(target_speeds[first], target_speeds[(first + 1) % target_speeds.size()], position - floorf(position))

func upcoming_min_speed(progress: float, lookahead: float) -> float:
	var slowest := RaceConfig.ai_top_speed
	for offset in maxi(1, int(lookahead / spacing)) + 1:
		slowest = minf(slowest, target_speed_at(progress + float(offset) * spacing))
	return slowest

func braking_target(progress: float, speed: float) -> float:
	# A slower corner 200 m away should influence braking when reachable,
	# not impose its apex velocity immediately (the previous implementation did).
	var target := target_speed_at(progress)
	for distance: float in [10.0, 25.0, 50.0, 90.0, 150.0, 240.0]:
		var ahead := target_speed_at(progress + distance)
		target = minf(target, sqrt(ahead * ahead + 2.0 * RaceConfig.ai_braking_accel * distance))
	return target
