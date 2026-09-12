shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D noise_map : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.8, 0.83, 0.87, 0.4);
varying vec4 particle_color;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,length(MODEL_MATRIX[2].xyz),0),vec4(0,0,0,1));
	particle_color = COLOR;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float cloud = texture(noise_map, UV * 1.8 + particle_color.rg * 0.31).r;
	float falloff = 1.0 - smoothstep(0.15, 1.0, length(p));
	ALBEDO = tint.rgb * mix(0.70, 1.20, particle_color.r);
	ROUGHNESS = 1.0;
	ALPHA = tint.a * particle_color.a * falloff * smoothstep(0.15, 0.75, cloud);
}
