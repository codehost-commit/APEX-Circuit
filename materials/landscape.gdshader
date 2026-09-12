shader_type spatial;
uniform sampler2D grass_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
varying vec3 slope_normal;
void vertex(){
	world=(MODEL_MATRIX * vec4(VERTEX,1)).xyz;
	slope_normal=normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment(){
	vec3 grass=texture(grass_map,world.xz/14.0).rgb*vec3(0.60,0.86,0.42);
	vec3 rock=texture(rock_map,world.xz/20.0).rgb*vec3(0.71,0.73,0.70);
	float exposed=smoothstep(0.14,0.48,1.0-slope_normal.y);
	float altitude=smoothstep(140.0,265.0,world.y);
	ALBEDO=mix(grass,rock,max(exposed,altitude*0.75));
	ROUGHNESS=0.98;
}
