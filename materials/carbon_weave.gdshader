shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 weave_uv = UV * vec2(90.0,60.0);
	vec2 cell=floor(weave_uv);
	float direction=mod(cell.x+cell.y,2.0);
	float strand=mix(fract(weave_uv.x),fract(weave_uv.y),direction);
	float fiber=0.5+0.5*sin(strand*25.1327);
	float light=0.65+0.35*sin(strand*3.14159);
	float distance_fade=clamp(length(fwidth(weave_uv))*0.4,0.0,1.0);
	float value=mix(light*(0.88+fiber*0.12),0.78,distance_fade);
	ALBEDO=vec3(0.027,0.031,0.035)*value;
	METALLIC=0.18;
	ROUGHNESS=0.48;
	SPECULAR=0.32;
	ANISOTROPY=0.45;
}
