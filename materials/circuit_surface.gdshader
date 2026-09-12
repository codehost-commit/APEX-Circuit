shader_type spatial;
render_mode cull_disabled;

uniform int surface_kind = 0;
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_metres = 4.0;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float micro = noise(p * 95.0);
	float patches = noise(p * 0.19);
	vec2 map_uv = p / texture_metres;
	vec3 photographed = texture(surface_albedo, map_uv).rgb;
	vec3 normal_detail = texture(surface_normal, map_uv).xyz * 2.0 - 1.0;
	if (surface_kind != 1) {
		// World-aligned ground mapping; no UV seam or tangent dependence.
		vec3 world_normal = normalize(vec3(normal_detail.x * 0.32, normal_detail.z, normal_detail.y * 0.32));
		NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	}
	if (surface_kind == 0) {
		float grain_visibility = 1.0 - clamp(length(fwidth(p)) * 8.0, 0.0, 1.0);
		float rubber = 1.0 - smoothstep(1.0, 4.7, abs(UV.x + sin(UV.y * 0.009) * 2.3));
		SPECULAR = 0.18;
		vec3 asphalt = mix(vec3(0.055, 0.063, 0.071), vec3(0.075, 0.082, 0.09), patches);
		ALBEDO = photographed * (0.78 + patches * 0.15) * (1.0 - rubber * 0.18);
		ROUGHNESS = clamp(texture(surface_roughness, map_uv).r, 0.82, 0.98) - rubber * 0.04;
	} else if (surface_kind == 1) {
		float stripe = step(0.5, fract(UV.y / 17.36));
		float groove = smoothstep(0.36, 0.45, abs(fract(UV.y * 4.0) - 0.5));
		vec3 paint = mix(vec3(0.64, 0.025, 0.044), vec3(0.84, 0.825, 0.76), stripe);
		ALBEDO = paint * (0.91 + 0.09 * patches) * (1.0 - groove * 0.09) + (micro - 0.5) * 0.025;
		ROUGHNESS = 0.82;
		SPECULAR = 0.20;
	} else if (surface_kind == 2) {
		float mow = smoothstep(0.43, 0.57, sin((p.x + p.y * 0.13) * 0.22) * 0.5 + 0.5);
		vec3 grass = mix(vec3(0.035, 0.082, 0.017), vec3(0.068, 0.128, 0.032), patches);
		float luminance = dot(photographed, vec3(0.299,0.587,0.114));
		ALBEDO = mix(vec3(0.095,0.19,0.034),vec3(0.17,0.29,0.07),patches) * (0.55 + luminance * 2.2) * (0.9 + mow * 0.10);
		ROUGHNESS = 0.99;
	} else {
		float rake = sin(p.x * 17.0 + p.y * 7.0) * 0.035;
		ALBEDO = photographed * (0.92 + patches * 0.12) + rake * 0.12;
		ROUGHNESS = 1.0;
	}
}
