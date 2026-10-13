shader_type spatial;
// Brillo simulado con un sprite aditivo (sin postprocesado).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.55, 0.2);
uniform float intensity = 1.0;
uniform float pulse = 0.0;

void vertex() {
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 v = center + (cam_r * VERTEX.x + cam_u * VERTEX.y) * sx;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.2);
	float p = 1.0 + sin(TIME * 2.3) * 0.08 * pulse;
	ALBEDO = color * a * intensity * p;
}
