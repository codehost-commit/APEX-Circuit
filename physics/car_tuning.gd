class_name CarTuning
extends Resource
## SI-unit handling transferred from the Python prototype; seven forward gears.

@export_category("Mass and geometry")
@export var mass_kg := 798.0
@export var center_of_mass := Vector3(0.0, 0.34, 0.0)
@export var yaw_inertia := 1160.0
@export var wheelbase := 3.45
@export var cg_to_front := 1.62
@export var front_track := 1.90
@export var rear_track := 1.90
@export var wheel_radius := 0.34
@export var suspension_rest_length := 0.27

@export_category("Suspension")
@export var spring_rate := 142000.0
@export var damper_bump := 5800.0
@export var damper_rebound := 6900.0
@export var anti_roll_stiffness := 13000.0

@export_category("Tyres")
@export var tyre_mu := 2.55
@export var load_sensitivity := 0.86
@export var longitudinal_peak_slip := 0.115
@export var lateral_peak_angle := 0.20
@export var post_peak_falloff := 0.22
@export var wheel_inertia := 1.5
@export var rolling_resistance := 0.014
@export var offroad_drag_force := 980.0
@export var front_cornering_stiffness := 128000.0
@export var rear_cornering_stiffness := 142000.0

@export_category("Powertrain")
@export var idle_rpm := 5000.0
@export var rev_limit_rpm := 20000.0
@export var upshift_rpm := 18000.0
@export var shift_duration := 0.055
@export var peak_power_watts := 735000.0
@export var peak_torque_nm := 560.0
@export var max_drive_force := 14500.0
@export var max_speed_mps := 105.0
@export var reverse_speed_mps := 12.0
@export var final_drive := 3.70
# Physical gearing: 76 / 119 / 162 / 209 / 259 / 317 / 378 km/h at 18,000 rpm.
@export var gear_ratios := PackedFloat32Array([8.24, 5.25, 3.85, 2.99, 2.41, 1.97, 1.65])
@export var auto_shift := true

@export_category("Brakes and steering")
@export var max_brake_force := 22000.0
@export var max_brake_torque := 7480.0
@export var handbrake_force := 9500.0
@export var brake_front_bias := 0.59
@export var max_steer_low_speed := 0.488692
@export var max_steer_high_speed := 0.023562
@export var steering_target_accel := 29.0
@export var steering_response := 2.5
@export var steering_input_rise := 4.6
@export var steering_input_fall := 7.0

@export_category("Aerodynamics")
@export var drag_cd_area := 0.914286
@export var lift_cl_area := 3.591837
@export var front_aero_balance := 0.44
@export var air_density := 1.225
@export var drs_drag_multiplier := 0.76
@export var drs_rear_downforce_multiplier := 0.68

@export_category("Assists")
@export var traction_control := false
@export var abs_enabled := false
@export var stability_assist := 0.0

func torque_at_rpm(value: float) -> float:
	var rise := smoothstep(idle_rpm, 13000.0, value)
	var torque := peak_torque_nm * lerpf(0.78, 1.0, rise)
	return minf(torque, peak_power_watts / maxf(value * TAU / 60.0, 1.0))
