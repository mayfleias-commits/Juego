shader_type spatial;
// Superposición de mapa (calor, salud, recursos) sobre el valle.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D data_tex : filter_linear;
uniform int mode = 0; // 0 calor, 1 salud, 2 recursos
uniform float opacity = 0.55;

vec3 heat_ramp(float v) {
	// 0 Congelante .. 1 Confortable
	vec3 a = vec3(0.25, 0.45, 1.0);
	vec3 b = vec3(0.35, 0.85, 1.0);
	vec3 c = vec3(1.0, 0.95, 0.4);
	vec3 d = vec3(1.0, 0.45, 0.15);
	if (v < 0.33) return mix(a, b, v / 0.33);
	if (v < 0.66) return mix(b, c, (v - 0.33) / 0.33);
	return mix(c, d, (v - 0.66) / 0.34);
}

void fragment() {
	vec4 t;
	if (mode == 0) {
		// Calor: suavizado entre casillas.
		t = texture(data_tex, UV);
	} else {
		// Salud y recursos: una casilla, un color (sin que el borde se mezcle con el vacío).
		ivec2 sz = textureSize(data_tex, 0);
		ivec2 px = clamp(ivec2(floor(UV * vec2(sz))), ivec2(0), sz - ivec2(1));
		t = texelFetch(data_tex, px, 0);
	}
	vec3 col;
	if (mode == 0) {
		col = heat_ramp(t.r);
	} else if (mode == 1) {
		col = mix(vec3(0.3, 0.9, 0.4), vec3(0.95, 0.2, 0.2), t.r);
	} else {
		col = mix(vec3(0.2, 0.2, 0.2), vec3(1.0, 0.85, 0.3), t.r);
	}
	ALBEDO = col;
	ALPHA = opacity * t.a;
}
