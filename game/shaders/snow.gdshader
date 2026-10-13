shader_type spatial;
// Copos de nieve animados por completo en la GPU: una sola llamada de dibujo.
// Cada instancia es un quad; su posición sale del índice y del tiempo, envolviendo
// una caja que sigue a la cámara.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform vec3 center = vec3(0.0);
uniform vec3 box = vec3(120.0, 60.0, 120.0);
uniform float fall_speed = 3.0;
uniform vec2 wind = vec2(2.0, 0.6);
uniform float flake_size = 0.18;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

varying float v_alpha;

float h1(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 r = vec3(h1(id * 1.13), h1(id * 2.71 + 3.1), h1(id * 7.31 + 1.7));
	float t = TIME * fall_speed / box.y;
	vec3 p;
	p.y = fract(r.y - t) * box.y;
	p.x = fract(r.x + TIME * wind.x / box.x + sin(TIME * 0.7 + id) * 0.002) * box.x;
	p.z = fract(r.z + TIME * wind.y / box.z) * box.z;
	// Anclado al mundo y envuelto alrededor de la cámara (no "nada" al moverla).
	vec3 world;
	world.x = center.x - box.x * 0.5 + mod(p.x - center.x + box.x * 0.5, box.x);
	world.z = center.z - box.z * 0.5 + mod(p.z - center.z + box.z * 0.5, box.z);
	world.y = p.y;
	// billboard
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	float s = flake_size * (0.6 + r.x * 0.8);
	vec3 v = world + (cam_r * VERTEX.x + cam_u * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
	v_alpha = opacity * smoothstep(0.0, 4.0, p.y) * smoothstep(box.y, box.y - 6.0, p.y);
}

void fragment() {
	float d = length(UV - vec2(0.5));
	float a = smoothstep(0.5, 0.15, d) * v_alpha;
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ALPHA = a;
}
