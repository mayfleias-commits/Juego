shader_type spatial;
// Humo de chimeneas: bocanadas billboard animadas en la GPU.
// INSTANCE_CUSTOM: xyz = boca de la chimenea, w = fase (0..1) + intensidad*10.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
uniform float rise = 6.0;
uniform float life = 6.0;
uniform vec2 wind = vec2(1.5, 0.4);
uniform vec3 tint : source_color = vec3(0.55, 0.55, 0.58);
varying float v_alpha;

void vertex() {
	vec3 origin = INSTANCE_CUSTOM.xyz;
	float phase = fract(INSTANCE_CUSTOM.w);
	float k = floor(INSTANCE_CUSTOM.w) / 10.0;
	float t = fract(TIME / life + phase);
	vec3 p = origin + vec3(wind.x * t * life * 0.6, rise * t * life * 0.5, wind.y * t * life * 0.6);
	float s = mix(0.6, 3.2, t) * max(k, 0.2);
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	vec3 v = p + (cam_r * VERTEX.x + cam_u * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
	v_alpha = (1.0 - t) * smoothstep(0.0, 0.1, t) * 0.55 * step(0.01, k);
}

void fragment() {
	float d = length(UV - vec2(0.5));
	ALBEDO = tint;
	ALPHA = smoothstep(0.5, 0.05, d) * v_alpha;
}
